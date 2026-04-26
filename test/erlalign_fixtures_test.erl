%%%-------------------------------------------------------------------
%%% @doc
%%% EUnit fixture-based tests for erlalign:format/2
%%%
%%% Tests cover column alignment, code formatting, and related features.
%%% Each test uses binary sigil syntax with fixture content embedded.
%%%
%%% @end
%%%-------------------------------------------------------------------

-module(erlalign_fixtures_test).

-include_lib("eunit/include/eunit.hrl").

-define(OPTS, [{line_length, 98}]).

%%%===================================================================
%%% Fixture Tests
%%%===================================================================

binary_operations_test() ->
    Original = ~"""
    -module(binary_operations).

    parse_message(<<Type:8, Length:16, Payload:Length/binary>>) ->
      {Type, Payload}.

    build_packet(Type, Data) ->
      Length = byte_size(Data),
      <<Type:8, Length:16, Data/binary>>.

    extract_fields(<<A:4, B:4, Rest/binary>>) ->
      {A, B, Rest}.
    """,
    Expected = ~"""
    -module(binary_operations).

    parse_message(<<Type:8, Length:16, Payload:Length/binary>>) ->
      {Type, Payload}.

    build_packet(Type, Data) ->
      Length = byte_size(Data),
      <<Type:8, Length:16, Data/binary>>.

    extract_fields(<<A:4, B:4, Rest/binary>>) ->
      {A, B, Rest}.
    """,
    Result = erlalign:format(Original, ?OPTS),
    ?assertEqual(Expected, Result).

case_patterns_test() ->
    Original = ~"""
    -module(case_patterns).

    classify(Value) ->
      case Value of
        {ok, X} -> X;
        {error, _} = Err -> Err;
        _ -> unknown
      end.

    single_line_clauses(Value) ->
      case Value of
        {ok, X} ->
          X; % Comment one
        {error, _} = Err ->
          Err; % Comment two
        _ ->
          % Comment three
          unknown
      end.

    multi_line_clauses(Event) ->
      case Event of
        % Comment one
        {user, created, User} ->
          send_welcome_email(User),
          log_event(created);
        % Comment two
        {user, updated, User} ->
          notify_watchers(User),
          log_event(updated);
        % Comment three
        {user, deleted, User} ->
          revoke_sessions(User),
          archive_data(User)
      end.
    """,
    Expected = ~"""
    -module(case_patterns).

    classify(Value) ->
      case Value of
        {ok, X}          -> X;
        {error, _} = Err -> Err;
        _                -> unknown
      end.

    single_line_clauses(Value) ->
      case Value of
        {ok, X} ->
          X; % Comment one
        {error, _} = Err ->
          Err; % Comment two
        _ ->
          % Comment three
          unknown
      end.

    multi_line_clauses(Event) ->
      case Event of
        % Comment one
        {user, created, User} ->
          send_welcome_email(User),
          log_event(created);
        % Comment two
        {user, updated, User} ->
          notify_watchers(User),
          log_event(updated);
        % Comment three
        {user, deleted, User} ->
          revoke_sessions(User),
          archive_data(User)
      end.
    """,
    Result = erlalign:format(Original, ?OPTS),
    ?assertEqual(Expected, Result).

comments_alignment_test() ->
    Original = ~"""
    -module(comments_alignment).

    % Short comments
    tuple() ->
      {
        foo = 1, % first
        bar = 2, % second  
        longer_name = 3, % third with longer variable name
      }.

    user() ->
      % Or in a record
      User = #user{
        name = <<"Alice">>, % the user name
        age = 30, % their age
        email = <<"alice@example.com">>, % contact info
        active = true % whether they are active
      }.
    """,
    Expected = ~"""
    -module(comments_alignment).

    % Short comments
    tuple() ->
      {
        foo         = 1, % first
        bar         = 2, % second
        longer_name = 3, % third with longer variable name
      }.

    user() ->
      % Or in a record
      User = #user{
        name   = <<"Alice">>,             % the user name
        age    = 30,                      % their age
        email  = <<"alice@example.com">>, % contact info
        active = true                     % whether they are active
      }.
    """,
    Result = erlalign:format(Original, ?OPTS),
    ?assertEqual(Expected, Result).

comments_wrapping_test() ->
    Original = ~"""
    -module(comments_wrapping).

    % This comment is relatively short
    X = 1,

    % This is a much longer comment that explains in detail what the next line of code does and provides context about why it's important to set this variable to this particular value
    Y = 2,

    % Short
    Z = 3,

    % Another long comment that wraps across multiple visual lines because it contains a lot of text and important information about the implementation details of the code that follows
    W = 4.
    """,
    Expected = ~"""
    -module(comments_wrapping).

    % This comment is relatively short
    X = 1,

    % This is a much longer comment that explains in detail what the next line of code does and provides context about why it's important to set this variable to this particular value
    Y = 2,

    % Short
    Z = 3,

    % Another long comment that wraps across multiple visual lines because it contains a lot of text and important information about the implementation details of the code that follows
    W = 4.
    """,
    Result = erlalign:format(Original, ?OPTS),
    ?assertEqual(Expected, Result).

edoc_case1_test() ->
    Original = ~"""
    -module(t).

    %%--------------------------------------------------------------------
    %% @doc
    %% Internal function to actually format code (assumes OTP >= 27).
    %%--------------------------------------------------------------------
    format_code_internal(Content, Opts) ->
      %% First, convert @doc blocks to -doc attributes
      Converted = convert_doc_blocks(Content, Opts),
      ok.
    """,
    Expected = ~"""
    -module(t).

    %%--------------------------------------------------------------------
    %% @doc
    %% Internal function to actually format code (assumes OTP >= 27).
    %%--------------------------------------------------------------------
    format_code_internal(Content, Opts) ->
      %% First, convert @doc blocks to -doc attributes
      Converted = convert_doc_blocks(Content, Opts),
      ok.
    """,
    Result = erlalign:format(Original, ?OPTS),
    ?assertEqual(Expected, Result).

function_calls_test() ->
    Original = ~"""
    -module(function_calls).

    call_api() ->
      api:request(http, <<"GET">>, Url1, [{timeout, 5000}]),
      api:request(socket, <<"POST">>, Url2, [{body, Data}]),
      api:request(memory, <<"DELETE">>, Url3, []).

    call_another_api() ->
      mod1:request(http, <<"GET">>, Url1, [{timeout, 5000}]),
      module2:request(socket, <<"POST">>, Url2, [{body, Data}]),
      other:request(memory, <<"DELETE">>, Url3, []).
    """,
    Expected = ~"""
    -module(function_calls).

    call_api() ->
      api:request(http, <<"GET">>, Url1, [{timeout, 5000}]),
      api:request(socket, <<"POST">>, Url2, [{body, Data}]),
      api:request(memory, <<"DELETE">>, Url3, []).

    call_another_api() ->
      mod1:request(http, <<"GET">>, Url1, [{timeout, 5000}]),
      module2:request(socket, <<"POST">>, Url2, [{body, Data}]),
      other:request(memory, <<"DELETE">>, Url3, []).
    """,
    Result = erlalign:format(Original, ?OPTS),
    ?assertEqual(Expected, Result).

function_matching_test() ->
    Original = ~"""
    -module(function_matching).

    % Function clauses with pattern matching
    test(one) -> one;
    test(hundred) -> hundred;
    test(twenty) -> twenty;  % special case
    test(X) -> X.

    % Another function with guards
    process(X) when is_integer(X) -> integer;
    process(X) when is_atom(X) -> atom;  % named values
    process(_) -> other.
    """,
    Expected = ~"""
    -module(function_matching).

    % Function clauses with pattern matching
    test(one)                     -> one;
    test(hundred)                 -> hundred;
    test(twenty)                  -> twenty;  % special case
    test(X)                       -> X.

    % Another function with guards
    process(X) when is_integer(X) -> integer;
    process(X) when is_atom(X)    -> atom;  % named values
    process(_)                    -> other.
    """,
    Result = erlalign:format(Original, ?OPTS),
    ?assertEqual(Expected, Result).

guard_clauses_test() ->
    Original = ~"""
    -module(guard_clauses).

    is_adult(Age) when Age >= 18 -> true;
    is_adult(Age) when Age < 18 -> false.

    check_type(X) when is_integer(X) -> int;
    check_type(X) when is_atom(X) -> atom;
    check_type(X) when is_binary(X) -> string.
    """,
    Expected = ~"""
    -module(guard_clauses).

    is_adult(Age) when Age >= 18     -> true;
    is_adult(Age) when Age < 18      -> false.

    check_type(X) when is_integer(X) -> int;
    check_type(X) when is_atom(X)    -> atom;
    check_type(X) when is_binary(X)  -> string.
    """,
    Result = erlalign:format(Original, ?OPTS),
    ?assertEqual(Expected, Result).

list_operations_test() ->
    Original = ~"""
    -module(list_operations).

    head([H | T]) -> H;
    head([]) -> undefined.

    tail([_ | T]) -> T;
    tail([]) -> [].

    combine(List1, List2) -> List1 ++ List2.
    """,
    Expected = ~"""
    -module(list_operations).

    head([H | T])         -> H;
    head([])              -> undefined.

    tail([_ | T])         -> T;
    tail([])              -> [].

    combine(List1, List2) -> List1 ++ List2.
    """,
    Result = erlalign:format(Original, ?OPTS),
    ?assertEqual(Expected, Result).

map_updates_test() ->
    Original = ~"""
    -module(map_updates).

    update_record(Map) ->
      Map#{name => <<"Bob">>, age => 25, active => true}.

    large_map(Map) ->
      Map#{
        name => <<"Bob">>, % One
        age => 25, % Two
        active => true, % Three
        passive => false,
        nickname => <<"Bobby">> % Five
      }.

    merge_maps(M1, M2) ->
      M1#{x => 1, y => 2} = M2#{a => 10, b => 20}.
    """,
    Expected = ~"""
    -module(map_updates).

    update_record(Map) ->
      Map#{name => <<"Bob">>, age => 25, active => true}.

    large_map(Map) ->
      Map#{
        name     => <<"Bob">>,  % One
        age      => 25,         % Two
        active   => true,       % Three
        passive  => false,
        nickname => <<"Bobby">> % Five
      }.

    merge_maps(M1, M2) ->
      M1#{x => 1, y => 2} = M2#{a => 10, b => 20}.
    """,
    Result = erlalign:format(Original, ?OPTS),
    ?assertEqual(Expected, Result).

module_attrs_test() ->
    Original = ~"""
    -module(module_attrs).

    -author(<<"Alice Developer">>).
    -vsn("1.0.0").
    -created({2024, 4, 15}).
    -last_modified({2024, 4, 24}).

    -export([main/0, helper/1]).
    -export_type([result/0]).

    -include("common.hrl").
    -include_lib("stdlib/include/assert.hrl").

    -define(TIMEOUT, 5000).
    -define(MAX_RETRIES, 3).
    -define(BUFFER_SIZE, 8192).

    main() -> ok.
    helper(X) -> X.
    """,
    Expected = ~"""
    -module(module_attrs).

    -author(<<"Alice Developer">>).
    -vsn("1.0.0").
    -created({2024, 4, 15}).
    -last_modified({2024, 4, 24}).

    -export([main/0, helper/1]).
    -export_type([result/0]).

    -include("common.hrl").
    -include_lib("stdlib/include/assert.hrl").

    -define(TIMEOUT, 5000).
    -define(MAX_RETRIES, 3).
    -define(BUFFER_SIZE, 8192).

    main()    -> ok.
    helper(X) -> X.
    """,
    Result = erlalign:format(Original, ?OPTS),
    ?assertEqual(Expected, Result).

nested_structures_test() ->
    Original = ~"""
    -module(nested_structures).

    parse_nested() ->
      Data = #{
        user => #{
          name => <<"Alice">>,
          contact => #{
            email => <<"alice@example.com">>,
            phone => <<"555-1234">>
          }
        },
        status => active
      }.

    process({ok, {Type, Value, Status}}) ->
      {Type, Value, Status};
    process({error, Reason}) ->
      {error, Reason}.
    """,
    Expected = ~"""
    -module(nested_structures).

    parse_nested() ->
      Data = #{
        user => #{
          name    => <<"Alice">>,
          contact => #{
            email => <<"alice@example.com">>,
            phone => <<"555-1234">>
          }
        },
        status => active
      }.

    process({ok, {Type, Value, Status}}) ->
      {Type, Value, Status};
    process({error, Reason}) ->
      {error, Reason}.
    """,
    Result = erlalign:format(Original, ?OPTS),
    ?assertEqual(Expected, Result).

operator_alignment_test() ->
    Original = ~"""
    -module(operator_alignment).

    calculate() ->
      A = 10 + 5,
      BB = 20 * 3,
      CCC = 100 / 2,
      DDDD = 7 mod 3,
      XX = 1.5 + 2.5,
      Y = 0.1 * 10.
    """,
    Expected = ~"""
    -module(operator_alignment).

    calculate() ->
      A    = 10 + 5,
      BB   = 20 * 3,
      CCC  = 100 / 2,
      DDDD = 7 mod 3,
      XX   = 1.5 + 2.5,
      Y    = 0.1 * 10.
    """,
    Result = erlalign:format(Original, ?OPTS),
    ?assertEqual(Expected, Result).

record_fields_test() ->
    Original = ~"""
    -module(record_fields).

    create_user() ->
      #user{
        name = <<"Alice">>,
        age = 30,
        email = <<"alice@example.com">>,
        status = active
      }.
    """,
    Expected = ~"""
    -module(record_fields).

    create_user() ->
      #user{
        name   = <<"Alice">>,
        age    = 30,
        email  = <<"alice@example.com">>,
        status = active
      }.
    """,
    Result = erlalign:format(Original, ?OPTS),
    ?assertEqual(Expected, Result).

tuple_patterns_test() ->
    Original = ~"""
    -module(tuple_patterns).

    match_tuple({A, B}) -> A + B;
    match_tuple({X, Y, Z}) -> X * Y * Z;
    match_tuple({ok, Value, Status}) -> {Value, Status}.

    deconstruct() ->
      {X, Y} = {1, 2},
      {A, B, C} = {10, 20, 30}.
    """,
    Expected = ~"""
    -module(tuple_patterns).

    match_tuple({A, B})              -> A + B;
    match_tuple({X, Y, Z})           -> X * Y * Z;
    match_tuple({ok, Value, Status}) -> {Value, Status}.

    deconstruct()                    ->
      {X, Y}    = {1, 2},
      {A, B, C} = {10, 20, 30}.
    """,
    Result = erlalign:format(Original, ?OPTS),
    ?assertEqual(Expected, Result).

type_specs_test() ->
    Original = ~"""
    -module(type_specs).

    -export([add/2, multiply/2, process/1]).

    -type number_type() :: integer() | float().
    -type status() :: ok | error | pending.

    -spec add(number_type(), number_type()) -> number_type().
    add(X, Y) -> X + Y.

    -spec multiply(number_type(), number_type()) -> number_type().
    multiply(X, Y) -> X * Y.

    -spec process(any()) -> status().
    process(_) -> ok.
    """,
    Expected = ~"""
    -module(type_specs).

    -export([add/2, multiply/2, process/1]).

    -type number_type() :: integer() | float().
    -type status() :: ok | error | pending.

    -spec add(number_type(), number_type()) -> number_type().
    add(X, Y) -> X + Y.

    -spec multiply(number_type(), number_type()) -> number_type().
    multiply(X, Y) -> X * Y.

    -spec process(any()) -> status().
    process(_) -> ok.
    """,
    Result = erlalign:format(Original, ?OPTS),
    ?assertEqual(Expected, Result).

variable_alignment_test() ->
    Original = ~"""
    -module(variable_alignment).

    test() ->
      X = 1,
      Foo = <<"bar">>,
      SomethingLong = 42,
      ok.
    """,
    Expected = ~"""
    -module(variable_alignment).

    test() ->
      X             = 1,
      Foo           = <<"bar">>,
      SomethingLong = 42,
      ok.
    """,
    Result = erlalign:format(Original, ?OPTS),
    ?assertEqual(Expected, Result).
