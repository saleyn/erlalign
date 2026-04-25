%%%-------------------------------------------------------------------
%%% @doc
%%% rebar3 provider for ErlAlign documentation converter.
%%%
%%% Converts EDoc @doc blocks to OTP-27 -doc attributes in Erlang source files.
%%%
%%% Usage:
%%%   rebar3 erlalign_docs [options] [files]
%%%
%%% Options:
%%%   --line-length N         Line wrap width (default: 80)
%%%   --keep-separators       Preserve %%---- separator lines
%%%   --check                 Check mode - fail if files would change
%%%   --dry-run               Show changes without modifying files
%%%   -s, --silent            Suppress output
%%%   -h, --help              Show help message
%%%
%%% Examples:
%%%   rebar3 erlalign_docs                      # Convert all Erlang files
%%%   rebar3 erlalign_docs --line-length 100    # Custom line length
%%%   rebar3 erlalign_docs --keep-separators    # Keep separator lines
%%%   rebar3 erlalign_docs --dry-run src/
%%%
%%% @end
%%%-------------------------------------------------------------------

-module(rebar3_erlalign_docs_prv).

-behaviour(provider).

-export([init/1, do/1, format_error/1, provider/0]).

-define(PROVIDER, erlalign_docs).
-define(DEPS, [compile]).

%%%===================================================================
%%% Provider API
%%%===================================================================

-spec provider() -> {atom(), list()}.
provider() ->
  {erlalign_docs, [default, undefined]}.

-spec init(rebar_state:t()) -> {ok, rebar_state:t()}.
init(State) ->
  Provider = providers:create([
    {name,        ?PROVIDER},
    {module,      ?MODULE},
    {bare,        true},
    {deps,        ?DEPS},
    {desc,        "Convert EDoc @doc to OTP-27 -doc attributes"},
    {short_desc,  "Convert documentation"},
    {example,     "rebar3 erlalign_docs"},
    {opts,        [
      {line_length,      $l, "line-length",      {integer, 80}, "Line wrap width (default: 80)"},
      {keep_separators,  $k, "keep-separators",  undefined,     "Preserve %%---- separator lines"},
      {check,            $c, "check",            undefined,     "Check mode - fail if files would change"},
      {dry_run,          $d, "dry-run",          undefined,     "Show changes without modifying files"},
      {silent,           $s, "silent",           undefined,     "Suppress output"}
    ]}
  ]),
  {ok, rebar_state:add_provider(State, Provider)}.

-spec do(rebar_state:t()) -> {ok, rebar_state:t()} | {error, string()}.
do(State) ->
  {ParsedOpts, Args} = rebar_state:command_parsed_args(State),
  
  % Parse options
  LineLength = proplists:get_value(line_length, ParsedOpts, 80),
  KeepSeparators = proplists:is_defined(keep_separators, ParsedOpts),
  Check = proplists:is_defined(check, ParsedOpts),
  DryRun = proplists:is_defined(dry_run, ParsedOpts),
  Silent = proplists:is_defined(silent, ParsedOpts),
  
  % Determine files to convert
  Files = case Args of
    [] ->
      % Convert all Erlang files in src/
      filelib:wildcard(filename:join([rebar_state:base_dir(State), "src", "**", "*.erl"]));
    _ ->
      % Convert specified files/directories
      lists:flatmap(fun collect_files/1, Args)
  end,
  
  case Files of
    [] ->
      Silent orelse rebar_api:warn("No Erlang files found to convert", []),
      {ok, State};
    _ ->
      Silent orelse rebar_api:info("Converting documentation in ~w file(s)...", [length(Files)]),
      Silent orelse rebar_api:info("  line_length: ~w, keep_separators: ~w", [LineLength, KeepSeparators]),
      
      ConvertOpts = [
        {line_length, LineLength},
        {keep_separators, KeepSeparators}
      ],
      Result = convert_files(Files, ConvertOpts, Check, DryRun, Silent),
      
      case Result of
        ok -> {ok, State};
        {error, Code} -> {error, Code}
      end
  end.

-spec format_error(any()) -> iolist().
format_error(Reason) ->
  io_lib:format("~w", [Reason]).

%%%===================================================================
%%% Internal functions
%%%===================================================================

collect_files(Path) ->
  case filelib:is_dir(Path) of
    true ->
      filelib:wildcard(filename:join([Path, "**", "*.erl"]));
    false ->
      case filelib:is_file(Path) of
        true -> [Path];
        false -> []
      end
  end.

convert_files(Files, Opts, Check, DryRun, Silent) ->
  {Status, Changed} = lists:foldl(fun(File, {StatusAcc, ChangedAcc}) ->
    case convert_file(File, Opts, Check, DryRun, Silent) of
      ok -> {StatusAcc, ChangedAcc};
      changed -> {changed, ChangedAcc + 1};
      error -> {error, ChangedAcc}
    end
  end, {ok, 0}, Files),
  
  case Status of
    ok -> 
      Silent orelse rebar_api:info("  No changes needed.", []),
      ok;
    changed ->
      case Check of
        true ->
          rebar_api:error("~w file(s) would be converted (use --dry-run to see changes)", [Changed]),
          {error, "conversion required"};
        false ->
          Silent orelse rebar_api:info("  Converted ~w file(s).", [Changed]),
          ok
      end;
    error ->
      {error, "conversion failed"}
  end.

convert_file(Path, Opts, Check, DryRun, Silent) ->
  case file:read_file(Path) of
    {ok, Original} ->
      try erlalign_docs:format_code(Original, Opts) of
        Formatted ->
          if
            Formatted == Original -> 
              ok;
            DryRun -> 
              Silent orelse io:format("--- ~s~n~s~n", [Path, Formatted]),
              changed;
            Check ->
              changed;
            true ->
              file:write_file(Path, Formatted),
              Silent orelse rebar_api:info("  converted: ~s", [Path]),
              changed
          end
      catch
        Error ->
          rebar_api:error("Error converting ~s~n  ~p~n", [Path, Error]),
          error
      end;
    {error, Reason} ->
      rebar_api:error("Error reading ~s: ~w", [Path, Reason]),
      error
  end.
