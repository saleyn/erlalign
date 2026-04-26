-module(erlalign).
-moduledoc """
Erlang code formatter that applies column alignment on top of erlfmt output

ErlAlign mirrors ExAlign's functionality for Erlang source code, enabling
readable column-aligned formatting similar to Go's gofmt
""".

-export([
  format/2,
  format/1,
  align_variable_assignments/1,
  align_case_arrows/1,
  align_comments/1,
  load_global_config/0,
  main/1,
  handle_eol_at_eof/2,
  trim_eol_whitespace/2,
  set_default_trim_eol_ws/1
]).

-define(GLOBAL_CONFIG_PATH, "~/.config/erlalign/.formatter.exs").
-define(DEFAULT_LINE_LENGTH, 98).
-define(SUPPORTED_OPTS, [line_length, eol_at_eof, keep_separators, doc, remove_doc_separators, trim_eol_ws]).

-doc """
Main CLI entry point. Parses arguments and runs the formatter
Calls erlang:halt/1 with appropriate exit code
""".
main(Args) ->
  case run(Args) of
    ok            -> erlang:halt(0);
    {error, Code} -> erlang:halt(Code)
  end.

-doc """
Parse arguments and run the formatter. Returns `ok` on success or
`{error, exit_code}` on failure. Safe to call from tests
""".
run(Args) ->
  case parse_args(Args) of
    ok ->
      % Help was printed, exit successfully
      ok;
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

-doc """
Format Erlang source contents with column alignment
Opts may include:
- `line_length` (integer, default 98): Maximum line length for alignment
- `eol_at_eof` (`:add`, `:remove`, or `nil`, default `nil`):
Controls end-of-file newline handling
With `:add`, a trailing newline is added if not present
With `:remove`, any trailing newline is removed
With `nil`, the end-of-file newline is left unchanged
- `keep_separators` (boolean, default `false`):
- `trim_eol_ws` (boolean, default `true`):
When `true`, trim trailing whitespace from end of lines
""".
format(Contents) ->
  format(Contents, []).

format(Contents, Opts) ->
  MergedOpts  = lists:append(load_global_config(), validate_options(Opts)),
  Aligned1    = align_variable_assignments(Contents),
  Aligned2    = align_case_arrows(Aligned1),
  Aligned3    = align_comments(Aligned2),
  TrimmedOpts = set_default_trim_eol_ws(MergedOpts),
  Trimmed     = trim_eol_whitespace(Aligned3, TrimmedOpts),
  handle_eol_at_eof(Trimmed, TrimmedOpts).

-doc "Align consecutive variable assignments: Var = value".
align_variable_assignments(Code) ->
  Lines   = binary:split(Code, <<"\n">>, [global]),
  Groups  = group_by_indentation(Lines),
  Aligned = lists:flatmap(fun(Group) ->
    case {has_assignments(Group), length(Group) >= 2} of
      {true, true} -> align_group(Group, fun find_eq_pos/1);
      _            -> Group
    end
  end, Groups),
  binary:list_to_bin(lists:join(<<"\n">>, Aligned)).

-doc "Align case/if arrows: Pattern -> Body".
align_case_arrows(Code)          ->
  Lines    = binary:split(Code, <<"\n">>, [global]),
  AllLines = Lines,  % Keep original for lookahead
  Groups   = group_by_indentation(Lines),
  Aligned  = lists:flatmap(fun(Group) ->
    case {has_arrows(Group), length(Group) >= 2} of
      {true, true} ->
        %% Split group if it has multi-line clause boundaries and specs
        SubGroups = split_on_multiline_clauses(Group, AllLines),
        lists:flatmap(fun(SubGroup) ->
          %% Don't align groups with only 2 lines if first is spec
          case length(SubGroup) of
            2 ->
              Line1 = lists:nth(1, SubGroup),
              Trim1 = string:trim(Line1),
              case Trim1 of
                <<"-spec", _/binary>> -> SubGroup;  % Don't align spec+impl pairs
                _                     -> align_group(SubGroup, fun find_arrow_pos/1)
              end;
            N when N >= 3 -> align_group(SubGroup, fun find_arrow_pos/1);
            _             -> SubGroup
          end
        end, SubGroups);
      _ -> Group
    end
  end, Groups),
  binary:list_to_bin(lists:join(<<"\n">>, Aligned)).

-doc """
Split a group on multi-line clause boundaries and spec declarations
A multi-line clause is identified by an arrow that ends the line (no content
after ->)
A spec declaration starts with -spec and should not be aligned with
implementations
""".
split_on_multiline_clauses(Group, _AllLines) ->
  {Result, SubGroup, _} = lists:foldl(fun(Line, {Acc, Current, FuncCounts}) ->
    TrimmedLine = string:trim(Line),
    %% Check if this is a spec declaration
    IsSpec      = case TrimmedLine of
      <<"-spec", _/binary>> -> true;
      _                     -> false
    end,
    %% Check if line has arrow and if it's incomplete (ends with ->)
    HasArrow      = binary:match(TrimmedLine, <<"                ->">>) =/= nomatch,
    EndsWithArrow = case binary:match(TrimmedLine, <<"           ->">>, [])  of
      {Pos, _} ->
        %% Check if everything after -> is just whitespace/comment
        Rest              = binary:part(TrimmedLine, Pos + 2, byte_size(TrimmedLine) - Pos - 2),
        string:trim(Rest) =:= <<"">>;
      nomatch -> false
    end,

    %% Extract function name
    CurrentFuncName              = extract_function_name(TrimmedLine),

    %% Get previous line info if available
    {PrevFuncName, PrevHasArrow} = case Current of
      [] -> {undefined, false};
      [PrevLine | _] ->
        {extract_function_name(string:trim(PrevLine)),
         binary:match(string:trim(PrevLine), <<"->">>) =/= nomatch}
    end,

    %% Check if the PREVIOUS function appeared multiple times (multi-clause)
    PrevFuncCount = case PrevFuncName of
      undefined -> 0;
      _         -> maps:get(PrevFuncName, FuncCounts, 0)
    end,

    %% Only split on function name change if:
    %% 1. We have arrows on both lines
    %% 2. Previous line had a different function name
    %% 3. Previous function appeared MULTIPLE times (multi-clause function)
    FunctionNameChanged = HasArrow andalso
                          PrevHasArrow andalso
                          CurrentFuncName =/= undefined andalso
                          PrevFuncName    =/= undefined andalso
                          CurrentFuncName =/= PrevFuncName andalso
                          PrevFuncCount >= 2,  %% Only split if multi-clause

    %% Update function counts for current function
    NewFuncCounts = case {HasArrow, CurrentFuncName} of
      {true, Name} when Name =/= undefined ->
        maps:put(Name, maps:get(Name, FuncCounts, 0) + 1, FuncCounts);
      _ -> FuncCounts
    end,

    case {IsSpec, HasArrow, EndsWithArrow, FunctionNameChanged} of
      {true, _, _, _} ->
        %% Spec line - always close current group and start new one
        case Current of
          [] -> {Acc, [Line], NewFuncCounts};
          _  -> {Acc ++ [lists:reverse(Current)], [Line], #{}}
        end;
      {false, true, true, _} ->
        %% Multi-line clause - close current group and start new one
        case Current of
          [] -> {Acc, [Line], NewFuncCounts};
          _  -> {Acc ++ [lists:reverse(Current)], [Line], #{}}
        end;
      {false, _, _, true} ->
        %% Function name changed - close current group and start new one
        case Current of
          [] -> {Acc, [Line], NewFuncCounts};
          _  -> {Acc ++ [lists:reverse(Current)], [Line], #{}}
        end;
      _ ->
        %% Regular line - add to current group
        {Acc, [Line | Current], NewFuncCounts}
    end
  end, {[], [], #{}}, Group),

  case SubGroup of
    [] -> Result;
    _  -> Result ++ [lists:reverse(SubGroup)]
  end.

-doc """
Extract the function name from a clause line
Returns the function name atom or undefined if not a clause
""".
extract_function_name(Line) ->
  %% Match pattern: func_name(...) or -module(...) or similar
  case re:run(Line, <<"^([a-zA-Z_][a-zA-Z0-9_]*)\\s*\\(">>, [{capture, [1], binary}]) of
    {match, [FuncName]} -> FuncName;
    nomatch             -> undefined
  end.

align_comments(Code) ->
  Lines   = binary:split(Code, <<"\n">>, [global]),
  Groups  = group_by_indentation(Lines),
  Aligned = lists:flatmap(fun(Group) ->
    case {has_comments(Group), length(Group) >= 2} of
      {true, true} -> align_comment_group(Group);
      _            -> Group
    end
  end, Groups),
  binary:list_to_bin(lists:join(<<"\n">>, Aligned)).

-doc "Load global configuration from ~/.config/erlalign/.formatter.exs".
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

-doc "Expand tilde (~) in a file path to the user's home directory".
expand_tilde("~" ++ Rest) ->
  Home = case os:getenv("HOME") of
    false -> "/root";
    Value -> Value
  end,
  Home ++ Rest;
expand_tilde(Path) ->
  Path.

%% Helper Functions

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
parse_args_impl(["--doc" | Rest], Opts, Paths) ->
  parse_args_impl(Rest, Opts#{doc => true}, Paths);
parse_args_impl(["--keep-separators" | Rest], Opts, Paths) ->
  parse_args_impl(Rest, Opts#{keep_separators => true}, Paths);
parse_args_impl(["--line-length", N | Rest], Opts, Paths) ->
  LineLength                              = list_to_integer(binary_to_list(N)),
  parse_args_impl(Rest, Opts#{line_length => LineLength}, Paths);
parse_args_impl(["--eol-at-eof", Value | Rest], Opts, Paths) ->
  EolMode = case binary:list_to_bin(Value) of
    <<"add">>    -> add;
    <<"remove">> -> remove;
    <<"off">>    -> nil;
    _            -> nil
  end,
  parse_args_impl(Rest, Opts#{eol_at_eof => EolMode}, Paths);
parse_args_impl(["-o", OutputFile | Rest], Opts, Paths) ->
  Output = case is_binary(OutputFile) of
    true  -> OutputFile;
    false -> binary:list_to_bin(OutputFile)
  end,
  parse_args_impl(Rest, Opts#{output => Output}, Paths);
parse_args_impl(["--output", OutputFile | Rest], Opts, Paths) ->
  Output = case is_binary(OutputFile) of
    true  -> OutputFile;
    false -> binary:list_to_bin(OutputFile)
  end,
  parse_args_impl(Rest, Opts#{output => Output}, Paths);
parse_args_impl(["--trim-eol-ws" | Rest], Opts, Paths) ->
  parse_args_impl(Rest, Opts#{trim_eol_ws => true}, Paths);
parse_args_impl(["--no-trim-eol-ws" | Rest], Opts, Paths) ->
  parse_args_impl(Rest, Opts#{trim_eol_ws => false}, Paths);
parse_args_impl([Path | Rest], Opts, Paths) ->
  parse_args_impl(Rest, Opts, [binary:list_to_bin(Path) | Paths]).

print_help() ->
  io:format(
    "Usage: ~s [options] <file~s~s~n~n"
    "Options:~n"
    "  --line-length N       Maximum line length (default: 98)~n"
    "  --eol-at-eof VALUE    End-of-file newline handling: add, remove, or off (default: off)~n"
    "  --trim-eol-ws         Trim trailing whitespace from end of lines (default)~n"
    "  --no-trim-eol-ws      Do not trim trailing whitespace from end of lines~n"
    "  --doc                 Convert @doc to -doc attributes (OTP 27+)~n"
    "  -o, --output FILE     Write output to FILE instead of source (single file only)~n"
    "  --check               Check formatting without writing files~n"
    "  --dry-run             Print would-be changes without writing~n"
    "  -s, --silent          Suppress stdout output~n"
    "  -h, --help            Print this help~n~n"
    "Global configuration: ~s/.config/erlalign/.formatter.exs~n",
    [filename:basename(escript:script_name()), "|", "dir> [<file|dir> ...]", "~"]
  ).

format_opts(Opts, Paths) ->
  %% Build FormatOpts list with all supported formatting options
  FormatOpts = build_format_opts(Opts),
  Silent     = proplists:get_value(silent, Opts, false),
  UseDoc     = proplists:get_value(doc, Opts, false),
  OutputFile = proplists:get_value(output, Opts, undefined),
  Mode       = case {proplists:get_value(check, Opts, false),
        proplists:get_value(dry_run, Opts, false)} of
    {true, _} -> check;
    {_, true} -> dry_run;
    _         -> write
  end,

  Files = lists:flatmap(fun collect_files/1, Paths),

  %% Validate output option: only allowed with single file
  case {OutputFile, length(Files)} of
    {undefined, _} ->
      case process_files(Files, FormatOpts, Mode, Silent, UseDoc, OutputFile) of
        {ok, _}      -> ok;
        {changed, _} -> {error, 1};
        {error, _}   -> {error, 1}
      end;
    {_, 1} ->
      case process_files(Files, FormatOpts, Mode, Silent, UseDoc, OutputFile) of
        {ok, _}      -> ok;
        {changed, _} -> {error, 1};
        {error, _}   -> {error, 1}
      end;
    {_, _} ->
      io:format(standard_error, "Error: --output/-o can only be used with a single file~n", []),
      {error, 1}
  end.

%% Build format options list from parsed command-line arguments
build_format_opts(Opts) ->
  lists:filtermap(fun({Key, Value}) ->
    case Key of
      line_length     -> {true, {line_length, Value}};
      eol_at_eof      -> {true, {eol_at_eof, Value}};
      keep_separators -> {true, {keep_separators, Value}};
      trim_eol_ws     -> {true, {trim_eol_ws, Value}};
      _               -> false
    end
  end, Opts).

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
            true  -> [Path];
            false -> []
          end;
        false ->
          io:format(standard_error, "Path not found: ~s~n", [Path]),
          []
      end
  end.

process_files(Files, FormatOpts, Mode, Silent, UseDoc, OutputFile) ->
  lists:foldl(fun(File, {Status, Count}) ->
    case process_file(File, FormatOpts, Mode, Silent, UseDoc, OutputFile) of
      ok      -> {Status, Count};
      changed -> {changed, Count + 1};
      error   -> {error, Count}
    end
  end, {ok, 0}, Files).

process_file(Path, FormatOpts, Mode, Silent, UseDoc, OutputFile) ->
  case file:read_file(Path) of
    {ok, Original} ->
      Formatted = case UseDoc of
        true  -> erlalign_docs:format_code(Original, FormatOpts);
        false -> format(Original, FormatOpts)
      end,
      case Formatted == Original of
        true  -> ok;
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
              WritePath = case OutputFile of
                undefined -> Path;
                _         -> OutputFile
              end,
              case file:write_file(WritePath, Formatted) of
                ok ->
                  Silent orelse io:format("reformatted: ~s~n", [WritePath]),
                  ok;
                {error, WriteErr} ->
                  io:format(standard_error, "Error writing to ~s: ~w~n", [WritePath, WriteErr]),
                  error
              end
          end
      end;
    {error, Reason} ->
      io:format(standard_error, "Error reading file ~s: ~w~n", [Path, Reason]),
      error
  end.

-doc """
Set default value for trim_eol_ws option if not already set
Default is true (trim trailing whitespace)
""".
set_default_trim_eol_ws(Opts) ->
  case lists:keyfind(trim_eol_ws, 1, Opts) of
    false            -> [{trim_eol_ws, true} | Opts];
    {trim_eol_ws, _} -> Opts
  end.

-doc "Trim trailing whitespace from all lines if trim_eol_ws option is true".
trim_eol_whitespace(Code, Opts) ->
  case proplists:get_value(trim_eol_ws, Opts, true) of
    true ->
      Lines        = binary:split(Code, <<"\n">>, [global]),
      TrimmedLines = [string:trim(Line, trailing) || Line <- Lines],
      binary:list_to_bin(lists:join(<<"\n">>, TrimmedLines));
    false ->
      Code
  end.

validate_options(Opts) ->
  validate_options(Opts, ".formatter.exs").

validate_options(Opts, Source) ->
  {Valid, Invalid} = proplists:split(Opts, ?SUPPORTED_OPTS),
  FlatValid        = lists:append(Valid),
  case Invalid of
    [] -> FlatValid;
    _  ->
      InvalidKeys = [atom_to_list(K) || {K, _} <- Invalid],
      io:format(standard_error, "erlalign: ~s contains unsupported option(s) ~w~n",
        [Source, InvalidKeys]),
      FlatValid
  end.

group_by_indentation(Lines) ->
  {Groups, Current} = lists:foldl(fun(Line, {AccGroups, CurrentGroup}) ->
    LineIndent    = indentation(Line),
    CurrentIndent = case CurrentGroup of
      []              -> -1;
      [FirstLine | _] -> indentation(FirstLine)
    end,

    case LineIndent =:= CurrentIndent orelse CurrentGroup =:= [] of
      true  -> {AccGroups, CurrentGroup ++ [Line]};
      false -> {AccGroups ++ [CurrentGroup], [Line]}
    end
  end, {[], []}, Lines),

  case Current of
    [] -> Groups;
    _  -> Groups ++ [Current]
  end.

has_assignments(Group) ->
  lists:any(fun(Line) ->
    case binary:match(Line, <<"=">>) of
      {_, _}  -> true;
      nomatch -> false
    end
  end, Group).

has_arrows(Group) ->
  HasArrowLine = lists:any(fun(Line) ->
    binary:match(Line, <<"->">>) =/= nomatch
  end, Group),

  HasSpecLine = lists:any(fun(Line) ->
    Trimmed = string:trim(Line),
    case Trimmed of
      <<"-spec", _/binary>> -> true;
      _                     -> false
    end
  end, Group),

  %% Only return true if we have arrows but NOT specs
  %% (specs with their implementations should not be aligned together)
  HasArrowLine andalso not HasSpecLine.

find_eq_pos(Line) ->
  % Find = but skip if it's part of >=, =/=, /=, etc.
  find_eq_pos_skip_operators(Line, 0).

find_eq_pos_skip_operators(Line, StartPos) ->
  case binary:match(Line, <<"=">>, [{scope, {StartPos, byte_size(Line) - StartPos}}]) of
    nomatch -> -1;
    {Pos, _} ->
      % Check if the character before is >, /, or !
      case Pos > 0 of
        true ->
          PrevChar = binary:at(Line, Pos - 1),
          case PrevChar of
            $> -> find_eq_pos_skip_operators(Line, Pos + 1);
            $/ -> find_eq_pos_skip_operators(Line, Pos + 1);
            $! -> find_eq_pos_skip_operators(Line, Pos + 1);
            _  -> Pos
          end;
        false ->
          Pos
      end
  end.

find_arrow_pos(Line) ->
  case binary:match(Line, <<"->">>) of
    {Pos, _} -> Pos;
    nomatch  -> -1
  end.

align_group(Lines, GetPosFun) ->
  Positions = lists:map(GetPosFun, Lines),

  ValidPositions = lists:filter(fun(P) -> P >= 0 end, Positions),

  case ValidPositions of
    [] -> Lines;
    _  ->
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
        _              -> 0
      end;
    nomatch -> 0
  end.

has_comments(Group) ->
  %% Only align comments in structured contexts (maps, records, tuples)
  %% Check if the GROUP (not individual lines) is within a structure
  GroupStr     = binary:list_to_bin(lists:join(<<"\n">>, Group)),
  HasStructure = binary:match(GroupStr, <<"=>">>) =/= nomatch orelse
                 binary:match(GroupStr, <<"#">>) =/= nomatch orelse
                 binary:match(GroupStr, <<"{">>) =/= nomatch orelse
                 binary:match(GroupStr, <<"}">>) =/= nomatch orelse
                 binary:match(GroupStr, <<"[">>) =/= nomatch orelse
                 binary:match(GroupStr, <<"]">>) =/= nomatch,

  %% Additionally check each line for structure indicators
  HasCommentsInStructure = lists:any(fun(Line) ->
    case binary:match(Line, <<"%">>) of
      nomatch -> false;
      {_,_}   ->
        %% Has comment AND line contains comma (typical in records/tuples/maps)
        binary:match(Line, <<",">>) =/= nomatch
    end
  end, Group),

  %% Align comments only if group is in a structure OR lines have commas
  (HasStructure orelse HasCommentsInStructure) andalso
  lists:any(fun(Line) -> binary:match(Line, <<"%">>) =/= nomatch end, Group).

find_comment_pos(Line) ->
  case binary:match(Line, <<"%">>) of
    {Pos, _} ->
      %% Only align if there's code before the comment (not a standalone comment)
      BeforeComment = binary:part(Line, 0, Pos),
      case string:trim(BeforeComment) of
        <<>> -> -1;      %% Standalone comment, skip alignment
        _    -> Pos      %% Real code with comment, include in alignment
      end;
    nomatch -> -1
  end.

align_comment_group(Lines) ->
  %% Find max position before comment marker (only for lines with code+comment)
  Positions      = lists:map(fun find_comment_pos/1, Lines),
  ValidPositions = lists:filter(fun(P) -> P >= 0 end, Positions),

  case ValidPositions of
    [] -> Lines;
    _  ->
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

handle_eol_at_eof(Result, Opts) ->
  case proplists:get_value(eol_at_eof, Opts, nil) of
    add ->
      %% Add trailing newline if not present
      case byte_size(Result) > 0 andalso binary:at(Result, byte_size(Result) - 1) == $\n of
        true  -> Result;
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
        {ok, Term}     -> {ok, Term};
        {error, Error} -> {error, Error}
      end;
    {error, Error, _} ->
      {error, Error}
  end.
