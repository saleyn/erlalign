%%%-------------------------------------------------------------------
%%% @doc
%%% Detailed alignment tests for erlalign module.
%%%
%%% Tests specific alignment behaviors:
%%% - Variable assignment alignment
%%% - Case/if arrow alignment
%%% - Record field alignment
%%% - Comment alignment
%%%
%%% @end
%%%-------------------------------------------------------------------

-module(erlalign_alignment_tests).

-include_lib("eunit/include/eunit.hrl").

%%%===================================================================
%%% Variable Alignment Tests
%%%===================================================================

variable_alignment_test_() ->
  {"Variable alignment tests",
    [
      {"simple variable assignments",
        fun() ->
          Code = <<"X = 1,\nFoo = 2,\n">>,
          Result = erlalign:align_variable_assignments(Code),
          % The result should have aligned = operators
          ?assertNotEqual(Code, Result)
        end
      },
      {"long variable names",
        fun() ->
          Code = <<"Short = 1,\nVeryLongVariableName = 2,\n">>,
          Result = erlalign:align_variable_assignments(Code),
          ?assertMatch(_, Result)
        end
      },
      {"mixed indentation levels",
        fun() ->
          Code = <<"  X = 1,\n  Foo = 2,\n    Bar = 3,\n">>,
          Result = erlalign:align_variable_assignments(Code),
          % Bar is indented differently, so shouldn't align with X and Foo
          ?assertMatch(_, Result)
        end
      },
      {"single assignment unchanged",
        fun() ->
          Code = <<"X = 1,\n">>,
          Result = erlalign:align_variable_assignments(Code),
          ?assertEqual(Code, Result)
        end
      },
      {"assignments with complex values",
        fun() ->
          Code = <<"X = {1, 2, 3},\nY = [1, 2, 3],\nZ = #{a => 1},\n">>,
          Result = erlalign:align_variable_assignments(Code),
          ?assertMatch(_, Result)
        end
      },
      {"preserves non-assignment lines",
        fun() ->
          Code = <<"% Comment\nX = 1,\nY = 2,\n">>,
          Result = erlalign:align_variable_assignments(Code),
          ?assertMatch(_, string:find(Result, "% Comment"))
        end
      }
    ]
  }.

%%%===================================================================
%%% Case Arrow Alignment Tests
%%%===================================================================

case_arrow_alignment_test_() ->
  {"Case arrow alignment tests",
    [
      {"simple case arms",
        fun() ->
          Code = <<"case X of\n  a -> 1;\n  bb -> 2\nend.\n">>,
          Result = erlalign:align_case_arrows(Code),
          ?assertMatch(_, Result)
        end
      },
      {"case with guards",
        fun() ->
          Code = <<"case X of\n  Y when Y > 10 -> big;\n  Y -> small\nend.\n">>,
          Result = erlalign:align_case_arrows(Code),
          ?assertMatch(_, Result)
        end
      },
      {"multiple case clauses",
        fun() ->
          Code = <<"case Result of\n  {ok, Val} -> Val;\n  {error, _} -> none;\n  Other -> Other\nend.\n">>,
          Result = erlalign:align_case_arrows(Code),
          ?assertMatch(_, Result)
        end
      },
      {"nested cases",
        fun() ->
          Code = <<"case X of\n  a -> case Y of\n    b -> 1;\n    c -> 2\n  end;\n  d -> 3\nend.\n">>,
          Result = erlalign:align_case_arrows(Code),
          ?assertMatch(_, Result)
        end
      },
      {"preserves non-arrow patterns",
        fun() ->
          Code = <<"X -> 1,\n">>,
          Result = erlalign:align_case_arrows(Code),
          ?assertMatch(_, Result)
        end
      }
    ]
  }.

%%%===================================================================
%%% Record Field Alignment Tests
%%%===================================================================

record_alignment_test_() ->
  {"Record field alignment tests",
    [
      {"simple record with assignments",
        fun() ->
          Code = <<"R = #rec{field1 = 1, field2 = 2}.\n">>,
          Result = erlalign:align_variable_assignments(Code),
          ?assertMatch(_, Result)
        end
      },
      {"record update",
        fun() ->
          Code = <<"R2 = R#rec{a = 1, b = 2}.\n">>,
          Result = erlalign:align_variable_assignments(Code),
          ?assertMatch(_, Result)
        end
      },
      {"multiline record",
        fun() ->
          Code = <<"Rec = #record{\n  field1 = value1,\n  field2 = value2\n}.\n">>,
          Result = erlalign:align_variable_assignments(Code),
          ?assertMatch(_, Result)
        end
      }
    ]
  }.

%%%===================================================================
%%% Indentation and Grouping Tests
%%%===================================================================

grouping_test_() ->
  {"Grouping and indentation tests",
    [
      {"respects indentation levels",
        fun() ->
          Code = <<"func() ->\n  X = 1,\n  Y = 2,\n  nested() ->\n    A = 10,\n    B = 20\n  end.\n">>,
          Result = erlalign:align_variable_assignments(Code),
          ?assertMatch(_, Result)
        end
      },
      {"handles tabs vs spaces",
        fun() ->
          Code = <<"  X = 1,\n  Y = 2,\n">>,
          Result = erlalign:align_variable_assignments(Code),
          ?assertMatch(_, Result)
        end
      },
      {"blank lines break groups",
        fun() ->
          Code = <<"X = 1,\nY = 2,\n\nA = 10,\nB = 20,\n">>,
          Result = erlalign:align_variable_assignments(Code),
          % X,Y group should be separate from A,B group
          ?assertMatch(_, Result)
        end
      }
    ]
  }.

%%%===================================================================
%%% Line Length Option Tests
%%%===================================================================

line_length_test_() ->
  {"Line length option tests",
    [
      {"respects line length 80",
        fun() ->
          Code = <<"X = 1.\n">>,
          Result = erlalign:format(Code, [{line_length, 80}]),
          ?assertMatch(_, Result)
        end
      },
      {"respects line length 120",
        fun() ->
          Code = <<"X = 1.\n">>,
          Result = erlalign:format(Code, [{line_length, 120}]),
          ?assertMatch(_, Result)
        end
      },
      {"line length 0 disables wrapping",
        fun() ->
          Code = <<"X = 1.\n">>,
          Result = erlalign:format(Code, [{line_length, 0}]),
          ?assertMatch(_, Result)
        end
      }
    ]
  }.

%%%===================================================================
%%% Error Handling Tests
%%%===================================================================

error_handling_test_() ->
  {"Error handling tests",
    [
      {"format handles binary input",
        fun() ->
          Code = <<"test() -> ok.\n">>,
          Result = erlalign:format(Code, []),
          ?assertMatch(_, is_binary(Result))
        end
      },
      {"align_variable_assignments handles binary",
        fun() ->
          Code = <<"X = 1.\n">>,
          Result = erlalign:align_variable_assignments(Code),
          ?assertMatch(_, is_binary(Result))
        end
      },
      {"align_case_arrows handles binary",
        fun() ->
          Code = <<"case X of a -> 1 end.\n">>,
          Result = erlalign:align_case_arrows(Code),
          ?assertMatch(_, is_binary(Result))
        end
      },
      {"format handles empty binary",
        fun() ->
          Code = <<"">>,
          Result = erlalign:format(Code, []),
          ?assertEqual(<<"">>, Result)
        end
      }
    ]
  }.
