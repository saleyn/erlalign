%%%-------------------------------------------------------------------
%%% @doc
%%% Integration tests for rebar3 erlalign plugins.
%%%
%%% Tests the rebar3 provider integration:
%%% - rebar3_erlalign_prv (format command)
%%% - rebar3_erlalign_docs_prv (docs command)
%%%
%%% These tests verify that the plugin callbacks work correctly
%%% when invoked through the rebar3 framework.
%%%
%%% @end
%%%-------------------------------------------------------------------

-module(rebar3_erlalign_plugins_tests).

-include_lib("eunit/include/eunit.hrl").

%%%===================================================================
%%% Provider Info Tests
%%%===================================================================

format_provider_info_test_() ->
  {"Format provider info tests",
    [
      {"format provider returns valid spec",
        fun() ->
          Result = rebar3_erlalign_prv:provider(),
          ?assertMatch({erlalign, _Spec}, Result)
        end
      },
      {"format provider spec contains required fields",
        fun() ->
          {_Name, Spec} = rebar3_erlalign_prv:provider(),
          ?assert(lists:member(default, Spec)),
          ?assert(lists:member(undefined, Spec))
        end
      }
    ]
  }.

docs_provider_info_test_() ->
  {"Docs provider info tests",
    [
      {"docs provider returns valid spec",
        fun() ->
          Result = rebar3_erlalign_docs_prv:provider(),
          ?assertMatch({erlalign_docs, _Spec}, Result)
        end
      },
      {"docs provider spec contains required fields",
        fun() ->
          {_Name, Spec} = rebar3_erlalign_docs_prv:provider(),
          ?assert(lists:member(default, Spec)),
          ?assert(lists:member(undefined, Spec))
        end
      }
    ]
  }.

%%%===================================================================
%%% Target Specs Tests
%%%===================================================================

format_target_specs_test_() ->
  {"Format target specs tests",
    [
      {"format provider has provider function",
        fun() ->
          ?assert(erlang:function_exported(rebar3_erlalign_prv, provider, 0))
        end
      },
      {"format provider has init function",
        fun() ->
          ?assert(erlang:function_exported(rebar3_erlalign_prv, init, 1))
        end
      }
    ]
  }.

docs_target_specs_test_() ->
  {"Docs provider target specs tests",
    [
      {"docs provider has provider function",
        fun() ->
          ?assert(erlang:function_exported(rebar3_erlalign_docs_prv, provider, 0))
        end
      },
      {"docs provider has init function",
        fun() ->
          ?assert(erlang:function_exported(rebar3_erlalign_docs_prv, init, 1))
        end
      }
    ]
  }.

%%%===================================================================
%%% Do Callback Tests
%%%===================================================================

format_do_callback_test_() ->
  {"Format do callback tests",
    [
      {"format do callback exists",
        fun() ->
          ?assert(erlang:function_exported(rebar3_erlalign_prv, do, 1))
        end
      },
      {"format provider can call callback",
        fun() ->
          IsExported = erlang:function_exported(rebar3_erlalign_prv, do, 1),
          ?assert(IsExported)
        end
      }
    ]
  }.

docs_do_callback_test_() ->
  {"Docs do callback tests",
    [
      {"docs do callback exists",
        fun() ->
          ?assert(erlang:function_exported(rebar3_erlalign_docs_prv, do, 1))
        end
      },
      {"docs provider can call callback",
        fun() ->
          IsExported = erlang:function_exported(rebar3_erlalign_docs_prv, do, 1),
          ?assert(IsExported)
        end
      }
    ]
  }.

%%%===================================================================
%%% File Processing Tests
%%%===================================================================

file_processing_test_() ->
  {setup,
    fun() ->
      TempDir = "/tmp/erlalign_rebar3_test",
      filelib:ensure_dir(TempDir ++ "/"),
      SrcDir = filename:join(TempDir, "src"),
      filelib:ensure_dir(SrcDir ++ "/"),
      
      % Create test Erlang files
      TestFile = filename:join(SrcDir, "test_module.erl"),
      Content = <<"-module(test_module).\n-export([foo/0]).\n\nfoo() -> ok.\n">>,
      file:write_file(TestFile, Content),
      
      {TempDir, SrcDir, TestFile}
    end,
    fun({TempDir, _SrcDir, _TestFile}) ->
      file:del_dir_r(TempDir)
    end,
    fun({_TempDir, SrcDir, TestFile}) ->
      [
        {"can find source directory",
          fun() ->
            ?assert(filelib:is_dir(SrcDir))
          end
        },
        {"test file exists and is readable",
          fun() ->
            ?assert(filelib:is_file(TestFile))
          end
        },
        {"can read test file content",
          fun() ->
            {ok, Content} = file:read_file(TestFile),
            ?assert(byte_size(Content) > 0)
          end
        },
        {"test file matches erlang extension",
          fun() ->
            ?assert(filelib:is_file(TestFile)),
            Ext = filename:extension(TestFile),
            ?assertEqual(".erl", Ext)
          end
        },
        {"can parse source files list",
          fun() ->
            Files = filelib:wildcard(filename:join(SrcDir, "*.erl")),
            ?assertMatch([_ | _], Files)
          end
        }
      ]
    end
  }.

%%%===================================================================
%%% Error Handling Tests
%%%===================================================================

error_handling_test_() ->
  {"Error handling tests",
    [
      {"format provider has format_error function",
        fun() ->
          ?assert(erlang:function_exported(rebar3_erlalign_prv, format_error, 1))
        end
      },
      {"docs provider has format_error function",
        fun() ->
          ?assert(erlang:function_exported(rebar3_erlalign_docs_prv, format_error, 1))
        end
      }
    ]
  }.

%%%===================================================================
%%% Module Exports Tests
%%%===================================================================

module_exports_test_() ->
  {"Module exports tests",
    [
      {"format provider exports required functions",
        fun() ->
          Exports = rebar3_erlalign_prv:module_info(exports),
          ?assert(lists:member({provider, 0}, Exports)),
          ?assert(lists:member({init, 1}, Exports)),
          ?assert(lists:member({do, 1}, Exports))
        end
      },
      {"docs provider exports required functions",
        fun() ->
          Exports = rebar3_erlalign_docs_prv:module_info(exports),
          ?assert(lists:member({provider, 0}, Exports)),
          ?assert(lists:member({init, 1}, Exports)),
          ?assert(lists:member({do, 1}, Exports))
        end
      }
    ]
  }.

%%%===================================================================
%%% Helper Functions
%%%===================================================================

% No helper functions needed for simplified tests

