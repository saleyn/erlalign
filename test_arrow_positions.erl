-module(test_arrow_positions).
-export([test/0]).

test() ->
  Lines = [
    <<"        <<\"%\", \"%\", \"%\", _/binary>> -> <<\"%%% \">>;  ">>,
    <<"        <<\"%\", \"%\", _/binary>> -> <<\"%% \">>;">>,
    <<"        <<\"%\", \"% ->\", _/binary>> -> <<\"%% \">>;">>,
    <<"        ~\"%% abc, -> \\\"efg, xxx\\\"\" -> <<\"%% abc\">>;">>,
    <<"        ~b\"%% cde, efg, xxx\" -> <<\"%% cde\">>;">>,
    <<"        ~B\"%% efg, efg, xxx\" -> <<\"%% efg\">>;">>,
    <<"        _ -> <<\"%% \">>">>, 
    <<"      end.">>
  ],
  io:format("Arrow positions:~n"),
  lists:foreach(fun(Line) ->
    Pos = erlalign:find_arrow_pos(Line),
    Trimmed = string:trim(Line),
    io:format("  Pos: ~w | ~s~n", [Pos, Trimmed])
  end, Lines).
