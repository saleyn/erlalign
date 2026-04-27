
-module(rebar3_erlalign_prv).
-moduledoc """
rebar3 provider for ErlAlign column-aligning formatter.

Provides the 'format' rebar3 command to format Erlang source code
with column alignment on top of erlfmt output.

Usage:
rebar3 format [options] [files]

Options:
--line-length N         Maximum line length (default: 98)
--check                 Check formatting without modifying files
--dry-run               Show what would be formatted
-o, --output FILE Write output to FILE instead of source (single file only)
-s, --silent            Suppress output
-h, --help              Show help message

If no files or directories are specified, all .erl files in `src/` and
`app/*/src/` will be formatted.

Examples:
rebar3 format                           # Format all Erlang files
rebar3 format --line-length 120         # Format with longer lines
rebar3 format --check src/              # Check src/ directory
rebar3 format --dry-run src/mymodule.erl
rebar3 format -o /tmp/output.erl src/mymodule.erl  # Save to different file
""".
-behaviour(provider).

-export([init/1, do/1, format_error/1, provider/0]).

-define(PROVIDER, format).
-define(DEPS, [compile]).

%%%===================================================================
%%% Provider API
%%%===================================================================

-spec provider() -> {atom(), list()}.
provider() ->
  {format, [default, undefined]}.

-spec init(rebar_state:t()) -> {ok, rebar_state:t()}.
init(State) ->
  Provider = providers:create([
    {name,        ?PROVIDER},
    {module,      ?MODULE},
    {bare,        true},
    {deps,        ?DEPS},
    {desc,        "Format Erlang code with column alignment"},
    {short_desc,  "Format Erlang code"},
    {example,     "rebar3 erlalign"},
    {opts,        [
      {line_length,   $l, "line-length", {integer, 98}, "Line length for alignment (default: 98)"},
      {check,         $c, "check",       undefined,     "Check mode - fail if files would change"},
      {dry_run,       $d, "dry-run",     undefined,     "Show changes without modifying files"},
      {silent,        $s, "silent",      undefined,     "Suppress output"}
    ]}
  ]),
  {ok, rebar_state:add_provider(State, Provider)}.

-spec do(rebar_state:t()) -> {ok, rebar_state:t()} | {error, string()}.
do(State) ->
  {ParsedOpts, Args} = rebar_state:command_parsed_args(State),

  % Parse options
  LineLength         = proplists:get_value(line_length, ParsedOpts, 98),
  Check              = proplists:is_defined(check, ParsedOpts),
  DryRun             = proplists:is_defined(dry_run, ParsedOpts),
  Silent             = proplists:is_defined(silent, ParsedOpts),

  % Determine files to format
  Files =
    case Args of
      [] ->
        % Format all Erlang files in src/ and app/*/src/
        filelib:wildcard(filename:join(["src", "**", "*.erl"]))
        ++
        filelib:wildcard(filename:join(["app", "*", "src", "**", "*.erl"]));
      _ ->
        % Format specified files/directories
        lists:flatmap(fun collect_files/1, Args)
    end,

  case Files of
    [] ->
      Silent orelse rebar_api:warn("No Erlang files found to format", []),
      {ok, State};
    _ ->
      Silent orelse rebar_api:info("Formatting ~w file(s) with line length ~w...", [length(Files), LineLength]),

      FormatOpts = [{line_length, LineLength}],
      Result     = format_files(Files, FormatOpts, Check, DryRun, Silent),

      case Result of
        ok            -> {ok, State};
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
      filelib:wildcard(filename:join([Path, "**", "*.erl"])) ++
      filelib:wildcard(filename:join([Path, "**", "*.hrl"]));
    false ->
      case filelib:is_file(Path) of
        true  -> [Path];
        false -> []
      end
  end.

format_files(Files, Opts, Check, DryRun, Silent) ->
  {Status, Changed} = lists:foldl(fun(File, {StatusAcc, ChangedAcc}) ->
    case format_file(File, Opts, Check, DryRun, Silent) of
      ok      -> {StatusAcc, ChangedAcc};
      changed -> {changed, ChangedAcc + 1};
      error   -> {error, ChangedAcc}
    end
  end, {ok, 0}, Files),

  case Status of
    ok ->
      Silent orelse rebar_api:info("  No changes needed.", []),
      ok;
    changed ->
      case Check of
        true ->
          rebar_api:error("~w file(s) would be reformatted (use --dry-run to see changes)", [Changed]),
          {error, "formatting required"};
        false ->
          Silent orelse rebar_api:info("  Reformatted ~w file(s).", [Changed]),
          ok
      end;
    error ->
      {error, "formatting failed"}
  end.

format_file(Path, Opts, Check, DryRun, Silent) ->
  case file:read_file(Path) of
    {ok, Original} ->
      try erlalign:format(Original, Opts) of
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
              Silent orelse rebar_api:info("  formatted: ~s", [Path]),
              changed
          end
      catch
        _Error ->
          rebar_api:error("Error formatting ~s", [Path]),
          error
      end;
    {error, Reason} ->
      rebar_api:error("Error reading ~s: ~w", [Path, Reason]),
      error
  end.
