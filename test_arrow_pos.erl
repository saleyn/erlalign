-module(test_arrow_pos).
-export([test/0]).

test() ->
  Line2 = <<"        <<\"%\", \"%\", _/binary>> -> <<\"%% \">>;">>,
  io:format("Line 2 size: ~w~n", [byte_size(Line2)]),
  case binary:match(Line2, <<"->">>) of
    {Pos, _} -> io:format("First -> at position: ~w~n", [Pos]);
    nomatch -> io:format("No ->~n")
  end.
