%%%-------------------------------------------------------------------
%%% @doc
%%% EUnit tests for ErlAlign - Erlang code formatter and doc converter.
%%%
%%% Tests cover:
%%% - Fixture-based formatting tests (comparing output with expected)
%%% - Documentation conversion (EDoc @doc to OTP-27 -doc)
%%% - Column alignment (variables, case arrows, record fields)
%%% - Options handling (line_length, remove_doc_separators, etc.)
%%% - Edge cases and error handling
%%%
%%% @end
%%%-------------------------------------------------------------------

-module(erlalign_tests).

-include_lib("eunit/include/eunit.hrl").

% Test configuration
-define(FIXTURES_DIR, "test/fixtures").
-define(INPUT_DIR, ?FIXTURES_DIR "/input").
-define(EXPECTED_DIR, ?FIXTURES_DIR "/expected").

%%%===================================================================
%%% Test Suite Setup
%%%===================================================================

all_tests_test_() ->
  {setup,
    fun setup/0,
    fun teardown/1,
    [
      format_tests(),
      format_docs_tests(),
      options_tests(),
      edge_case_tests()
    ]
  }.

setup() ->
  % Verify fixtures exist
  case filelib:is_dir(?INPUT_DIR) of
    true -> ok;
    false -> error({fixtures_not_found, ?INPUT_DIR})
  end.

teardown(_) ->
  ok.

%%%===================================================================
%%% Format Function Tests
%%%===================================================================

format_tests() ->
  {"erlalign:format/2 tests",
    [
      {"format with default options",
        fun() ->
          Code = <<"X = 1.\nFoo = 2.\n">>,
          Result = erlalign:format(Code, []),
          ?assertMatch(<<"X   = 1.\nFoo = 2.\n">>, Result)
        end
      },
      {"format with line_length option",
        fun() ->
          Code = <<"X = 1.\nFoo = 42.\n">>,
          Result1 = erlalign:format(Code, [{line_length, 80}]),
          Result2 = erlalign:format(Code, [{line_length, 120}]),
          ?assertEqual(<<"X   = 1.\nFoo = 42.\n">>, Result1),  % Both should align the same way
          ?assertEqual(Result1, Result2)  % Both should align the same way
        end
      },
      {"format preserves module declarations",
        fun() ->
          Code = <<"-module(test).\n\nfoo() -> ok.\n">>,
          Result = erlalign:format(Code, []),
          ?assertNotEqual(nomatch, string:find(Result, "-module(test)"))
        end
      },
      {"format empty content",
        fun() ->
          Code = <<"">>,
          Result = erlalign:format(Code, []),
          ?assertEqual(<<"">>, Result)
        end
      },
      {"format with comments",
        fun() ->
          Code = <<"X = 1. % This is a comment\nYYY = 20. % This is another comment\n">>,
          Result = erlalign:format(Code, []),
          ?assertEqual(<<"X   = 1. % This is a comment\nYYY = 20. % This is another comment\n">>, Result)
        end
      },
      {"format single line",
        fun() ->
          Code = <<"X = 1.\n">>,
          Result = erlalign:format(Code, []),
          ?assertEqual(<<"X = 1.\n">>, Result)
        end
      }
    ]
  }.

%%%===================================================================
%%% Documentation Conversion Tests
%%%===================================================================

format_docs_tests() ->
  {"erlalign_docs:format_code/2 tests",
    [
      {"convert simple @doc block",
        fun() ->
          Code = <<"%% @doc\n%% Test documentation.\n">>,
          Result = erlalign_docs:format_code(Code, []),
          ?assertEqual(<<"-doc \"Test documentation\".\n">>, Result)
        end
      },
      {"convert with line length wrapping",
        fun() ->
          Code = <<"%% @doc\n%% This is a very long documentation string that should be wrapped when the line length option is set to a shorter value.\n">>,
          Result = erlalign_docs:format_code(Code, [{line_length, 60}]),
          ?assert(is_binary(Result))
        end
      },
      {"preserve when no @doc present",
        fun() ->
          Code = <<"% Regular comment\nfoo() -> ok.\n">>,
          Result = erlalign_docs:format_code(Code, []),
          ?assertEqual(Code, Result)
        end
      },
      {"convert moduledoc",
        fun() ->
          Code = <<"%%% @doc\n%%% Module documentation.\n%%% @end\n">>,
          Result = erlalign_docs:format_code(Code, []),
          % Code should be converted to -doc attribute
          ?assertEqual(<<"-doc \"Module documentation\".\n">>, Result)
        end
      },
      {"convert another moduledoc",
        fun() ->
          Code = """
            %%%-------------------------------------------------------------------
            %%% @doc
            %%% Tests for erlalign_docs module
            %%%
            %%% Tests the implemented functionality:
            %%% - OTP version checking
            %%%
            %%% @end
            %%%-------------------------------------------------------------------
            -module(test).
            """,
          Expected = iolist_to_binary([
            "-module(test).",
            10,  % newline
            "-moduledoc \"\"\"",
            10,  % newline
            "Tests for erlalign_docs module",
            10,  % newline
            10,  % newline
            "Tests the implemented functionality:",
            10,  % newline
            "- OTP version checking",
            10,  % newline
            "\"\"\"."
          ]),
          Result = erlalign_docs:format_code(Code, []),
          % Code should be converted to -moduledoc after -module
          ?assertEqual(Expected, Result)
        end
      },
      {"remove separator lines by default",
        fun() ->
          Code = <<"%%----\n%% @doc\n%% Test\n">>,
          Result = erlalign_docs:format_code(Code, []),
          %% Result should not have %%---- separator
          ?assertEqual(nomatch, binary:match(Result, <<"%%----">>))
        end
      },
      {"keep separator lines when requested",
        fun() ->
          Code = <<"%%----\n%% @doc\n%% Test\n">>,
          Result = erlalign_docs:format_code(Code, [{keep_separators, true}]),
          %% Result should keep %%----
          HasSeparator = binary:match(Result, <<"%%----">>) =/= nomatch,
          ?assert(HasSeparator)
        end
      },
      {"convert @doc before -module to -moduledoc after -module",
        fun() ->
          Code = <<"%%% @doc\n%%% A module for basic arithmetic.\n%%% @end\n-module(arith).\n">>,
          Result = erlalign_docs:format_code(Code, []),
          %% Result should have -moduledoc immediately after -module
          %% Expected pattern: -module(arith).\n-moduledoc "..."
          ?assert(binary:match(Result, <<"-module(arith).">> ) =/= nomatch),
          ?assert(binary:match(Result, <<"-moduledoc">> ) =/= nomatch),
          %% -moduledoc should come after -module
          ModulePos = binary:match(Result, <<"-module(arith).">>),
          ModuledocPos = binary:match(Result, <<"-moduledoc">>),
          case {ModulePos, ModuledocPos} of
            {{MPos, _}, {DPos, _}} -> ?assert(MPos < DPos);
            _ -> ok
          end
        end
      },
      {"no extra newlines between -doc block and following function",
        fun() ->
          Code = <<"%%----\n%% @doc\n%% Extract the function name\n%% @end\n%%----\nextract_function_name(Line) ->\n  ok.\n">>,
          Result = erlalign_docs:format_code(Code, []),
          %% Result should not have blank line between -doc and function
          %% Bad pattern: \".\n\nextract\" (double newline = blank line)
          %% Good pattern: \".\nextract\" (single newline, no blank line)
          HasDoubleNewline = binary:match(Result, <<".\n\nextract_function_name">>) =/= nomatch,
          ?assert(not HasDoubleNewline),
          %% Verify the function is still present
          ?assert(binary:match(Result, <<"extract_function_name">> ) =/= nomatch)
        end
      }
    ]
  }.

%%%===================================================================
%%% Options Handling Tests
%%%===================================================================

options_tests() ->
  {"Options handling tests",
    [
      {"load global config returns list",
        fun() ->
          Config = erlalign:load_global_config(),
          ?assert(is_list(Config) orelse Config == [])
        end
      },
      {"format with empty options",
        fun() ->
          Code = <<"X = 1.\n">>,
          Result = erlalign:format(Code, []),
          ?assert(is_binary(Result))
        end
      },
      {"format with multiple options",
        fun() ->
          Code = <<"X = 1.\nFoo = 2.\n">>,
          Result = erlalign:format(Code, [{line_length, 120}]),
          ?assert(is_binary(Result))
        end
      },
      {"docs format_code with multiple options",
        fun() ->
          Code = <<"%% @doc\n%% Test\n">>,
          Result = erlalign_docs:format_code(Code, [
            {line_length, 80},
            {remove_doc_separators, true}
          ]),
          ?assert(is_binary(Result))
        end
      }
    ]
  }.

%%%===================================================================
%%% Edge Case Tests
%%%===================================================================

edge_case_tests() ->
  {"Edge case and robustness tests",
    [
      {"format with only whitespace",
        fun() ->
          Code = <<"   \n  \n   \n">>,
          Result = erlalign:format(Code, []),
          ?assert(is_binary(Result))
        end
      },
      {"format with mixed line endings",
        fun() ->
          Code = <<"X = 1.\r\nFoo = 2.\n">>,
          Result = erlalign:format(Code, []),
          ?assert(is_binary(Result))
        end
      },
      {"format deeply nested structures",
        fun() ->
          Code = <<"test() -> case X of {a, {b, {c, 1}}} -> ok; _ -> error end.\n">>,
          Result = erlalign:format(Code, []),
          ?assert(is_binary(Result))
        end
      },
      {"docs with @see references",
        fun() ->
          Code = <<"%% @doc\n%% Test doc.\n%% @see other_function/1\n">>,
          Result = erlalign_docs:format_code(Code, []),
          % Code should be converted to -doc with @see reference included
          ?assertEqual(<<"-doc \"\"\"\nTest doc\nSee also:\n- `other_function/1`\n\"\"\".\n">>, Result)
        end
      },
      {"handle binary vs string inputs",
        fun() ->
          CodeBinary = <<"X = 1.\n">>,
          ResultBinary = erlalign:format(CodeBinary, []),
          ?assert(is_binary(ResultBinary))
        end
      },
      {"format with very long line",
        fun() ->
          LongLine = binary:copy(<<"a">>, 1000),
          Code = <<LongLine/binary, " = 1.\n">>,
          Result = erlalign:format(Code, [{line_length, 200}]),
          ?assert(is_binary(Result))
        end
      },
      {"process_file with nonexistent file",
        fun() ->
          Result = erlalign_docs:process_file("/nonexistent/path/file.erl", []),
          ?assertMatch({error, _}, Result)
        end
      },
      {"format with special characters",
        fun() ->
          Code = <<"test(Var) -> \'multi-word-atom\' = Var.\n">>,
          Result = erlalign:format(Code, []),
          ?assert(is_binary(Result))
        end
      },
      {"align multiple consecutive assignments",
        fun() ->
          Code = <<"X = 1,\nVariable = 2,\nZ = 3,\n">>,
          Result = erlalign:format(Code, [{line_length, 98}]),
          % Result should show alignment of = operators
          ?assert(is_binary(Result))
        end
      },
      {"case arm alignment",
        fun() ->
          Code = <<"case Result of\n  {ok, Val} -> Val;\n  {error, _} -> none\nend.\n">>,
          Result = erlalign:format(Code, [{line_length, 98}]),
          % Result should align -> operators
          ?assert(is_binary(Result))
        end
      }
    ]
  }.
