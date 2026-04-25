%%%-------------------------------------------------------------------
%%% @doc
%%% Erlang code formatter that applies column alignment on top of erlfmt output.
%%%
%%% ErlAlign mirrors ExAlign's functionality for Erlang source code, enabling
%%% readable column-aligned formatting similar to Go's `gofmt`.
%%%
%%% @end
%%%-------------------------------------------------------------------

-module(erlalign).

-export([
  format/2,
  format/1,
  align_variable_assignments/1,
  align_case_arrows/1,
  load_global_config/0,
  main/1,
  handle_eol_at_eof/2
]).

-define(GLOBAL_CONFIG_PATH, "~/.config/erlalign/.formatter.exs").
-define(DEFAULT_LINE_LENGTH, 98).
-define(SUPPORTED_OPTS, [line_length, eol_at_eof, keep_separators]).

%%--------------------------------------------------------------------
%% @doc
%% Main CLI entry point. Parses arguments and runs the formatter.
%% Calls erlang:halt/1 with appropriate exit code.
%% @end
%%--------------------------------------------------------------------
main(Args) ->
  case run(Args) of
    ok            -> erlang:halt(0);
    {error, Code} -> erlang:halt(Code)
  end.

%%--------------------------------------------------------------------
%% @doc
%% Parse arguments and run the formatter. Returns `ok' on success or
%% `{error, exit_code}' on failure. Safe to call from tests.
%% @end
%%--------------------------------------------------------------------
run(Args) ->
  case parse_args(Args) of
    {ok, Opts, Paths} ->
      case Paths of
        [] ->
          print_help(),
          {error, 1};
        _ ->
          format_opts(Opts, Paths)
      end;
    {error, _} = Error ->
      Error
  end.

%%--------------------------------------------------------------------
%% @doc
%% Format Erlang source contents with column alignment.
%% Opts may include:
%%  - `line_length' (integer, default 98): Maximum line length for alignment
%%  - `eol_at_eof' (`:add', `:remove', or `nil', default `nil'):
%%    Controls end-of-file newline handling.
%%    With `:add', a trailing newline is added if not present.
%%    With `:remove', any trailing newline is removed.
%%    With `nil', the end-of-file newline is left unchanged.
%%  - `keep_separators' (boolean, default `false'):
%%    When `true', preserves separator lines like `%%----'
%% @end
%%--------------------------------------------------------------------
format(Contents) ->
  format(Contents, []).

format(Contents, Opts) ->
  MergedOpts = lists:append(load_global_config(), validate_options(Opts)),
  Aligned1 = align_variable_assignments(Contents),
  Aligned2 = align_case_arrows(Aligned1),
  handle_eol_at_eof(Aligned2, MergedOpts).

%%--------------------------------------------------------------------
%% @doc
%% Align consecutive variable assignments: Var = value
%% @end
%%--------------------------------------------------------------------
align_variable_assignments(Code) ->
  Lines = binary:split(Code, <<"\n">>, [global]),
  Groups = group_by_indentation(Lines),
  Aligned = lists:flatmap(fun(Group) ->
    case {has_assignments(Group), length(Group) >= 2} of
      {true, true} -> align_group(Group, fun find_eq_pos/1);
      _ -> Group
    end
  end, Groups),
  binary:list_to_bin(lists:join(<<"\n">>, Aligned)).

%%--------------------------------------------------------------------
%% @doc
%% Align case/if arrows: Pattern -> Body
%% @end
%%--------------------------------------------------------------------
align_case_arrows(Code) ->
  Lines = binary:split(Code, <<"\n">>, [global]),
  Groups = group_by_indentation(Lines),
  Aligned = lists:flatmap(fun(Group) ->
    case {has_arrows(Group), length(Group) >= 2} of
      {true, true} -> align_group(Group, fun find_arrow_pos/1);
      _ -> Group
    end
  end, Groups),
  binary:list_to_bin(lists:join(<<"\n">>, Aligned)).

%%--------------------------------------------------------------------
%% @doc
%% Load global configuration from ~/.config/erlalign/.formatter.exs
%% @end
%%--------------------------------------------------------------------
load_global_config() ->
  Path = expand_tilde(?GLOBAL_CONFIG_PATH),
  case file:read_file(Path) of
    {ok, Content} ->
      case consult_string(Content) of
        {ok, Config} when is_list(Config) ->
          validate_options(Config);
        {error, _} ->
          io:format(standard_error, "erlalign: could not parse ~s~n", [Path]),
          [];
        _ ->
          io:format(standard_error, "erlalign: ~s must be a keyword list~n", [Path]),
          []
      end;
    {error, enoent} ->
      [];
    {error, Reason} ->
      io:format(standard_error, "erlalign: could not load ~s: ~w~n", [Path, Reason]),
      []
  end.

%%--------------------------------------------------------------------
%% @doc
%% Expand tilde (~) in a file path to the user's home directory.
%% @end
%%--------------------------------------------------------------------
expand_tilde("~" ++ Rest) ->
  Home = case os:getenv("HOME") of
    false -> "/root";
    Value -> Value
  end,
  Home ++ Rest;
expand_tilde(Path) ->
  Path.

%%--------------------------------------------------------------------
%% Helper Functions
%%--------------------------------------------------------------------

parse_args(Args) ->
  case parse_args_impl(Args, #{}, []) of
    {Opts, Paths} when is_map(Opts) andalso is_list(Paths) ->
      {ok, maps:to_list(Opts), Paths};
    Error ->
      Error
  end.

parse_args_impl([], Opts, Paths) ->
  {Opts, lists:reverse(Paths)};
parse_args_impl(["-h" | _], _, _) ->
  print_help(),
  ok;
parse_args_impl(["--help" | _], _, _) ->
  print_help(),
  ok;
parse_args_impl(["-s" | Rest], Opts, Paths) ->
  parse_args_impl(Rest, Opts#{silent => true}, Paths);
parse_args_impl(["--silent" | Rest], Opts, Paths) ->
  parse_args_impl(Rest, Opts#{silent => true}, Paths);
parse_args_impl(["--check" | Rest], Opts, Paths) ->
  parse_args_impl(Rest, Opts#{check => true}, Paths);
parse_args_impl(["--dry-run" | Rest], Opts, Paths) ->
  parse_args_impl(Rest, Opts#{dry_run => true}, Paths);
parse_args_impl(["--line-length", N | Rest], Opts, Paths) ->
  LineLength = list_to_integer(binary_to_list(N)),
  parse_args_impl(Rest, Opts#{line_length => LineLength}, Paths);
parse_args_impl([Path | Rest], Opts, Paths) ->
  parse_args_impl(Rest, Opts, [binary:list_to_bin(Path) | Paths]).

print_help() ->
  io:format(
    "Usage: erlalign [options] <file~s~s~n~n"
    "Options:~n"
    "  --line-length N       Maximum line length (default: 98)~n"
    "  --check               Check formatting without writing files~n"
    "  --dry-run             Print would-be changes without writing~n"
    "  -s, --silent          Suppress stdout output~n"
    "  -h, --help            Print this help~n~n"
    "Global configuration: ~s/.config/erlalign/.formatter.exs~n",
    ["|", "dir> [<file|dir> ...]", "~"]
  ).

format_opts(Opts, Paths) ->
  FormatOpts = case proplists:get_value(line_length, Opts) of
    undefined -> [];
    N -> [{line_length, N}]
  end,
  Silent = proplists:get_value(silent, Opts, false),
  Mode = case {proplists:get_value(check, Opts, false),
        proplists:get_value(dry_run, Opts, false)} of
    {true, _} -> check;
    {_, true} -> dry_run;
    _ -> write
  end,

  Files = lists:flatmap(fun collect_files/1, Paths),

  case process_files(Files, FormatOpts, Mode, Silent) of
    {ok, _} -> ok;
    {changed, _} -> {error, 1};
    {error, _} -> {error, 1}
  end.

collect_files(Path) ->
  case filelib:is_dir(Path) of
    true ->
      filelib:wildcard(filename:join([Path, "**", "*.erl"])) ++
      filelib:wildcard(filename:join([Path, "**", "*.hrl"]));
    false ->
      case filelib:is_file(Path) of
        true ->
          case lists:suffix(".erl", binary_to_list(Path)) orelse
               lists:suffix(".hrl", binary_to_list(Path)) of
            true -> [Path];
            false -> []
          end;
        false ->
          io:format(standard_error, "Path not found: ~s~n", [Path]),
          []
      end
  end.

process_files(Files, FormatOpts, Mode, Silent) ->
  lists:foldl(fun(File, {Status, Count}) ->
    case process_file(File, FormatOpts, Mode, Silent) of
      ok -> {Status, Count};
      changed -> {changed, Count + 1};
      error -> {error, Count}
    end
  end, {ok, 0}, Files).

process_file(Path, FormatOpts, Mode, Silent) ->
  case file:read_file(Path) of
    {ok, Original} ->
      Formatted = format(Original, FormatOpts),
      case Formatted == Original of
        true -> ok;
        false ->
          case Mode of
            check ->
              Silent orelse io:format(standard_error, "would reformat: ~s~n", [Path]),
              changed;
            dry_run ->
              Silent orelse io:format("--- ~s~n", [Path]),
              Silent orelse io:format("~s~n", [Formatted]),
              changed;
            write ->
              file:write_file(Path, Formatted),
              Silent orelse io:format("reformatted: ~s~n", [Path]),
              ok
          end
      end;
    {error, Reason} ->
      io:format(standard_error, "Error reading file ~s: ~w~n", [Path, Reason]),
      error
  end.

validate_options(Opts) ->
  validate_options(Opts, ".formatter.exs").

validate_options(Opts, Source) ->
  {Valid, Invalid} = proplists:split(Opts, ?SUPPORTED_OPTS),
  case Invalid of
    [] -> Valid;
    _ ->
      InvalidKeys = [atom_to_list(K) || {K, _} <- Invalid],
      io:format(standard_error, "erlalign: ~s contains unsupported option(s) ~w~n",
        [Source, InvalidKeys]),
      Valid
  end.

group_by_indentation(Lines) ->
  {Groups, Current} = lists:foldl(fun(Line, {AccGroups, CurrentGroup}) ->
    LineIndent = indentation(Line),
    CurrentIndent = case CurrentGroup of
      [] -> -1;
      [FirstLine | _] -> indentation(FirstLine)
    end,

    case LineIndent =:= CurrentIndent orelse CurrentGroup =:= [] of
      true -> {AccGroups, CurrentGroup ++ [Line]};
      false -> {AccGroups ++ [CurrentGroup], [Line]}
    end
  end, {[], []}, Lines),

  case Current of
    [] -> Groups;
    _ -> Groups ++ [Current]
  end.

has_assignments(Group) ->
  lists:any(fun(Line) ->
    case re:run(Line, <<"\\s*\\w+\\s*=\\s*">>) of
      {match, _} -> true;
      nomatch -> false
    end
  end, Group).

has_arrows(Group) ->
  lists:any(fun(Line) ->
    binary:match(Line, <<"->">>) =/= nomatch
  end, Group).

find_eq_pos(Line) ->
  case binary:match(Line, <<"=">>) of
    {Pos, _} -> Pos;
    nomatch -> -1
  end.

find_arrow_pos(Line) ->
  case binary:match(Line, <<"->">>) of
    {Pos, _} -> Pos;
    nomatch -> -1
  end.

align_group(Lines, GetPosFun) ->
  Positions = lists:map(GetPosFun, Lines),

  ValidPositions = lists:filter(fun(P) -> P >= 0 end, Positions),

  case ValidPositions of
    [] -> Lines;
    _ ->
      MaxPos = lists:max(ValidPositions),
      lists:map(fun({Line, Pos}) ->
        case Pos >= 0 andalso Pos < MaxPos of
          true ->
            Pad = binary:copy(<<" ">>, MaxPos - Pos),
            inject_padding(Line, Pos, Pad);
          false ->
            Line
        end
      end, lists:zip(Lines, Positions))
  end.

inject_padding(Line, Pos, Pad) ->
  <<Prefix:Pos/binary, Suffix/binary>> = Line,
  <<Prefix/binary, Pad/binary, Suffix/binary>>.

indentation(Line) ->
  case re:run(Line, <<"^\\s*">>) of
    {match, Matches} -> 
      case Matches of
        [{0, Len} | _] -> Len;
        _ -> 0
      end;
    nomatch -> 0
  end.

handle_eol_at_eof(Result, Opts) ->
  case proplists:get_value(eol_at_eof, Opts, nil) of
    add ->
      %% Add trailing newline if not present
      case byte_size(Result) > 0 andalso binary:at(Result, byte_size(Result) - 1) == $\n of
        true -> Result;
        false -> <<Result/binary, "\n">>
      end;
    remove ->
      %% Remove all trailing newlines and whitespace
      string:trim(Result, trailing, "\n \t");
    nil ->
      %% Leave unchanged
      Result;
    _ ->
      %% Default: leave unchanged
      Result
  end.

%% Parse string as Erlang terms (simplified)
consult_string(Content) ->
  case erl_scan:string(binary_to_list(Content)) of
    {ok, Tokens, _} ->
      case erl_parse:parse_term(Tokens) of
        {ok, Term} -> {ok, Term};
        {error, Error} -> {error, Error}
      end;
    {error, Error, _} ->
      {error, Error}
  end.
