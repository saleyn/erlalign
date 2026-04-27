-module(test_positions_debug).
-export([test/0]).

test() ->
  Lines = [
    <<"    <<\"%\", \"%\", \"%\", _/binary>> -> <<\"%%% \">>;">>,
    <<"    <<\"%\", \"%\", _/binary>> -> <<\"%% \">>;">>,
    <<"    <<\"%\", \"% ->\", _/binary>> -> <<\"%% \">>;">>,
    <<"    ~\"%% abc, -> \\\"efg, xxx\\\"\" -> <<\"%% abc\">>;">>,
  ],
  io:format("Arrow positions:~n"),
  lists:foreach(fun(Line) ->
    Pos = erlalign:find_arrow_pos(Line),
    Trimmed = string:trim(Line),
    io:format("  Pos: ~w | ~s~n", [Pos, Trimmed])
  end, Lines),
  halt().
