-module(debug_test2).
-export([test/0]).

test() ->
  %% Test all three failing lines from the test case
  Lines = [
    <<"    <<\"%\", \"%\", \"%\", _/binary>> ->">>,
    <<"    <<\"%\", \"%\", _/binary>>      ->">>,
    <<"    ~\"%% abc, \"efg, xxx\"\"     ->">>
  ],
  
  lists:foreach(fun(Line) ->
    io:format("Line: ~p~n", [Line]),
    Protected = erlalign:find_protected_regions_debug(Line),
    io:format("  Protected: ~p~n", [Protected]),
    Pos = erlalign:find_arrow_pos(Line),
    io:format("  Arrow pos: ~p~n", [Pos]),
    case Pos >= 0 of
      true  -> io:format("  Bytes at pos: ~p~n", [binary:part(Line, Pos, 2)]);
      false -> ok
    end,
    io:format("~n")
  end, Lines),
  ok.
