-module(test_arrow_calc).
-export([test/0]).

test() ->
  Line = <<"        ~\"%% abc, -> \\\"efg, xxx\\\"\" -> <<\"%% abc\">>;">>,
  Pos = erlalign:find_arrow_pos(Line),
  io:format("Line: ~s~n", [Line]),
  io:format("Line bytes: ~w~n", [byte_size(Line)]),
  io:format("Arrow pos: ~w~n", [Pos]),
  if Pos >= 0 ->
    Arrow = binary:part(Line, Pos, 2),
    io:format("Char at pos ~w: ~s~n", [Pos, Arrow]);
  true -> ok
  end,
  halt().
