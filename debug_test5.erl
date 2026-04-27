-module(debug_test5).
-export([test/0]).

test() ->
  %% The actual input line that erlalign receives
  Line = <<"        ~\"%% abc, \\\"efg, xxx\\\"\" -> <<\"%% abc\">>;">>,
  io:format("Line: ~s~n", [Line]),
  io:format("Bytes (first 30):~n"),
  <<Start:30/binary, _/binary>> = Line,
  lists:foreach(fun({Idx, B}) ->
    Char = case B of
      92 -> "\\";
      34 -> "\"";
      32 -> "SP";
      _ when B >= 32, B < 127 -> [B];
      _ -> io_lib:format("~3w", [B])
    end,
    io:format("  [~2w]: ~s (~w)~n", [Idx, Char, B])
  end, lists:enumerate(0, binary_to_list(Start))),
  ok.
