-module(test_exact_original).
-export([test/0]).

test() ->
  %% The EXACT Original from the test fixture
  Original = ~b"""
  find_doc_prefix(Trimmed) ->
    case Trimmed of
      <<"%", "%", "%", _/binary>> -> <<"%%% ">>;
      <<"%", "%", _/binary>> -> <<"%% ">>;
      ~"%% abc, \"efg, xxx\"" -> <<"%% abc">>;
      ~b"%% cde, efg, xyz" -> <<"%% cde">>;
      ~B"%% efg, efg, xyz" -> <<"%% efg">>;
      _ -> <<"%% ">>
    end.
  """,
  
  %% Format it
  Opts = [],
  Result = erlalign:format(Original, Opts),
  
  %% Check output  
  io:format("INPUT:~n~s~n~n", [Original]),
  io:format("OUTPUT:~n~s~n~n", [Result]),
  
  %% Check inputfor escapes
  case binary:match(Original, <<"\\">>) of
    nomatch -> io:format("Input has NO backslashes~n");
    {P, L} -> io:format("Input has backslash at position ~w~n", [P])
  end,
  
  %% Check output for escapes
  case binary:match(Result, <<"\\">>) of
    nomatch -> io:format("Output has NO backslashes~n");
    {P2, L2} -> io:format("Output has backslash at position ~w~n", [P2])
  end,
  
  ok.
