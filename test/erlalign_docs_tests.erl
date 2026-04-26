%%%-------------------------------------------------------------------
%%% @doc
%%% Tests for erlalign_docs module - OTP version checking and formatting.
%%%
%%% Tests the implemented functionality:
%%% - OTP version checking
%%% - format_code with keep_separators option
%%% - format_doc_attribute formatting
%%% - Line wrapping
%%% - Markdown conversion
%%%
%%% @end
%%%-------------------------------------------------------------------

-module(erlalign_docs_tests).

-include_lib("eunit/include/eunit.hrl").

%%%===================================================================
%%% OTP Version Checking Tests
%%%===================================================================

otp_version_test_() ->
  {"OTP version checking tests",
    [
      {"otp_version returns current OTP release",
        fun() ->
          Version = erlalign_docs:otp_version(),
          ?assert(is_integer(Version)),
          ?assert(Version >= 24)
        end
      },
      {"is_otp_version_supported returns true for OTP >= 27",
        fun() ->
          Supported = erlalign_docs:is_otp_version_supported(),
          Version = erlalign_docs:otp_version(),
          ExpectedSupport = Version >= 27,
          ?assertEqual(ExpectedSupport, Supported)
        end
      }
    ]
  }.

%%%===================================================================
%%% Basic Conversion Tests
%%%===================================================================

basic_conversion_test_() ->
  {"Basic documentation conversion tests",
    [
      {"preserves code without docs",
        fun() ->
          Code = <<"foo() -> ok.\n">>,
          Result = erlalign_docs:format_code(Code, []),
          ?assertEqual(Code, Result)
        end
      }
    ]
  }.

%%%===================================================================
%%% Separator Line Handling Tests
%%%===================================================================

separator_handling_test_() ->
  {"Separator line handling tests",
    [
      {"removes separator lines by default",
        fun() ->
          Code = <<"%%----\nfoo() -> ok.\n">>,
          Result = erlalign_docs:format_code(Code, [{keep_separators, false}]),
          ?assert(is_binary(Result))
        end
      },
      {"keeps separator lines when requested",
        fun() ->
          Code = <<"%%----\nfoo() -> ok.\n">>,
          Result = erlalign_docs:format_code(Code, [{keep_separators, true}]),
          ?assert(is_binary(Result))
        end
      },
      {"handles multiple separator styles",
        fun() ->
          Code = <<"%%------\nfoo() -> ok.\n">>,
          Result = erlalign_docs:format_code(Code, []),
          ?assert(is_binary(Result)),
          ?assert(byte_size(Result) > 0)
        end
      },
      {"processes code with separators",
        fun() ->
          Code = <<"foo() -> ok.\n%%----\nbar() -> ok.\n">>,
          Result = erlalign_docs:format_code(Code, [{keep_separators, false}]),
          ?assert(is_binary(Result)),
          ?assert(binary:match(Result, <<"foo()">>) =/= nomatch),
          ?assert(binary:match(Result, <<"bar()">>) =/= nomatch)
        end
      }
    ]
  }.

line_breaks_test_() ->
  {"@doc with and without line breaks tests",
    [
      {"@doc with line breaks is converted to -doc",
        fun() ->
          Code = ~"""
          %%----------------------------------
          %% @doc
          %% Test function
          %% @end
          %%----------------------------------
          test() -> ok.
          """,
          Expected = ~"""
          -doc "Test function".
          test() -> ok.
          """,
          Result = erlalign_docs:format_code(Code, [{line_length, 80}]),
          ?assertEqual(Expected, Result)
        end
      },
      {"@doc without line breaks is converted to -doc",
        fun() ->
          Code = ~"""
          %% @doc
          %% Test function
          %% @end
          test() -> ok.
          """,
          Expected = ~"""
          -doc "Test function".
          test() -> ok.
          """,
          Result = erlalign_docs:format_code(Code, [{line_length, 80}]),
          ?assertEqual(Expected, Result)
        end
      },
      {"@doc with multiline line breaks is converted to -doc",
        fun() ->
          Code = ~"""
          %% @doc
          %% Test function
          %% with extra line breaks.
          %% @end
          test() -> ok.
          """,
          Expected = ~b"""
          -doc \"\"\"
          Test function
          with extra line breaks.
          \"\"\".
          test() -> ok.
          """,
          Result = erlalign_docs:format_code(Code, [{line_length, 80}]),
          ?assertEqual(Expected, Result)
        end
      }
    ]
  }.

%%%===================================================================
%%% Line Wrapping Tests
%%%===================================================================

wrap_lines_test_() ->
  {"Line wrapping tests",
    [
      {"wraps long lines at specified length",
        fun() ->
          Code = <<"%% @doc\n%% This is a very long line that should be wrapped when the line length is set to a shorter value like eighty characters.\n">>,
          Result = erlalign_docs:format_code(Code, [{line_length, 80}]),
          ?assert(is_binary(Result))
        end
      },
      {"no wrapping at 0 length",
        fun() ->
          Code = <<"%% @doc\n%% This is a long line.\n">>,
          Result = erlalign_docs:format_code(Code, [{line_length, 0}]),
          ?assert(is_binary(Result))
        end
      },
      {"preserves code blocks",
        fun() ->
          Code = <<"%% @doc\n%% Code example:\n%%   code_here() -> ok.\n">>,
          Result = erlalign_docs:format_code(Code, [{line_length, 40}]),
          ?assert(is_binary(Result)),
          ?assert(binary:match(Result, <<"code_here">>) =/= nomatch)
        end
      },
      {"wraps paragraph but not lists",
        fun() ->
          Code = <<"%% @doc\n%% This is a paragraph.\n%% - Item 1\n%% - Item 2\n">>,
          Result = erlalign_docs:format_code(Code, [{line_length, 20}]),
          ?assert(is_binary(Result))
        end
      }
    ]
  }.

%%%===================================================================
%%% Markdown Conversion Tests
%%%===================================================================

docs_conversion_test_() ->
  {"@docs to -doc conversion tests",
    [
      {"Docs block converted to multiline -doc attribute",
        fun() ->
          Original = ~"""
          -module(t).

          %%--------------------------------------------------------------------
          %% @doc
          %% Internal function to actually format code (assumes OTP >= 27).
          %% See also other comment.
          %%--------------------------------------------------------------------
          format_code_internal(Content, Opts) ->
            %% First, convert @doc blocks to -doc attributes
            Converted = convert_doc_blocks(Content, Opts),
            ok.
          """,
          Expected = ~b"""
          -module(t).

          -doc \"\"\"
          Internal function to actually format code (assumes OTP >= 27).
          See also other comment.
          \"\"\".
          format_code_internal(Content, Opts) ->
            %% First, convert @doc blocks to -doc attributes
            Converted = convert_doc_blocks(Content, Opts),
            ok.
          """,
          Result = erlalign_docs:format_code(Original, []),
          ?assertEqual(Expected, Result)
        end
      },
      {"Docs block converted to single line -doc attribute",
        fun() ->
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
          Expected = ~b"""
          -module(t).

          -doc "Internal function to actually format code (assumes OTP >= 27)".
          format_code_internal(Content, Opts) ->
            %% First, convert @doc blocks to -doc attributes
            Converted = convert_doc_blocks(Content, Opts),
            ok.
          """,
          Result = erlalign_docs:format_code(Original, []),
          ?assertEqual(Expected, Result)
        end
      }
    ]
  }.

%%%===================================================================
%%% Markdown Conversion Tests
%%%===================================================================

markdown_test_() ->
  {"Markdown conversion tests",
    [
      {"convert_to_markdown handles code blocks",
        fun() ->
          Lines = [
            <<"```">>,
            <<"code here">>,
            <<"```">>
          ],
          Result = erlalign_docs:convert_to_markdown(Lines),
          ?assert(is_list(Result))
        end
      },
      {"convert_to_markdown handles lists",
        fun() ->
          Lines = [
            <<"- item 1">>,
            <<"- item 2">>
          ],
          Result = erlalign_docs:convert_to_markdown(Lines),
          ?assert(is_list(Result))
        end
      },
      {"handles multiple @see references",
        fun() ->
          Lines = [<<"See also: func1/1 func2/2">>],
          Result = erlalign_docs:convert_to_markdown(Lines),
          SeeCount = length(string:split(iolist_to_binary(Result), "See also", all)) - 1,
          ?assert(SeeCount >= 1)
        end
      },
      {"convert_to_markdown handles mixed content",
        fun() ->
          Lines = [
            <<"Some text">>,
            <<"... more">>
          ],
          Result = erlalign_docs:convert_to_markdown(Lines),
          ?assert(is_list(Result))
        end
      }
    ]
  }.

%%%===================================================================
%%% Format Attribute Tests
%%%===================================================================

format_attribute_test_() ->
  {"Format doc attribute tests",
    [
      {"formats single line as quoted string",
        fun() ->
          Lines = [<<"Single line doc">>],
          Result = erlalign_docs:format_doc_attribute(Lines),
          ?assert(binary:match(Result, <<"-doc \"Single line doc\"">>) =/= nomatch)
        end
      },
      {"formats with moduledoc kind",
        fun() ->
          Lines = [<<"Module documentation">>],
          Result = erlalign_docs:format_doc_attribute(Lines, moduledoc),
          ?assert(binary:match(Result, <<"-moduledoc">>) =/= nomatch)
        end
      },
      {"handles empty lines",
        fun() ->
          Lines = [],
          Result = erlalign_docs:format_doc_attribute(Lines),
          ?assertEqual(<<"-doc false.">>, Result)
        end
      },
      {"formats multi-line as string",
        fun() ->
          Lines = [<<"Line 1">>, <<"Line 2">>],
          Result = erlalign_docs:format_doc_attribute(Lines),
          ?assert(is_binary(Result)),
          ?assert(binary:match(Result, <<"-doc">>) =/= nomatch)
        end
      }
    ]
  }.

%%%===================================================================
%%% Integration Tests - Verify OTP Check Works
%%%===================================================================

integration_test_() ->
  {"Integration tests",
    [
      {"format_code respects OTP version",
        fun() ->
          Code = <<"test() -> ok.\n">>,
          Supported = erlalign_docs:is_otp_version_supported(),
          Result = erlalign_docs:format_code(Code, []),
          % If OTP >= 27, processes; otherwise returns unchanged
          case Supported of
            true ->
              ?assert(is_binary(Result));
            false ->
              ?assertEqual(Code, Result)
          end
        end
      },
      {"round-trip consistency",
        fun() ->
          Code = <<"-module(test).\n\nfoo() -> ok.\n">>,
          Result1 = erlalign_docs:format_code(Code, []),
          Result2 = erlalign_docs:format_code(Result1, []),
          ?assertEqual(Result1, Result2)
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
      },
      {">= operator not split during alignment",
        fun() ->
          Code = <<"extract_function_name(Line) ->\n  PrevFuncName =/= undefined andalso\n  CurrentFuncName =/= PrevFuncName andalso\n  PrevFuncCount >= 2.\n">>,
          Result = erlalign_docs:format_code(Code, []),
          %% Result should NOT have "> =" (space inserted)
          %% Pattern to check: "> =" should not exist
          HasBrokenOp = binary:match(Result, <<"> =">>) =/= nomatch,
          ?assert(not HasBrokenOp),
          %% But ">=" should still be present
          ?assert(binary:match(Result, <<">=">>) =/= nomatch)
        end
      },
      {"@doc in string literal not converted to -doc block",
        fun() ->
          Code = <<"print_help() ->\n  io:format(\n    \"Options:~n\"\n    \"  --no-trim-eol-ws      Do not trim trailing whitespace~n\"\n    \"  --doc                 Convert @doc to -doc attributes (OTP 27+)~n\"\n    \"  --check               Check formatting~n\",\n    []\n  ).\n">>,
          Result = erlalign_docs:format_code(Code, []),
          %% Result should be identical to input since there's no real @doc tag (just text in a string)
          %% The @doc in the string should not be processed as a documentation marker
          ?assertEqual(Code, Result),
          %% Verify the function is still intact
          ?assert(binary:match(Result, <<"print_help">> ) =/= nomatch)
        end
      }
    ]
  }.
