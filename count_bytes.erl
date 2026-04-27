-module(count_bytes).
-export([test/0]).

test() ->
  Line = <<"        <<\"%\", \"%\", _/binary>> -> <<\"%% \">>;">>,
  io:format("Line: ~s~n", [Line]),
  io:format("Byte size: ~w~n", [byte_size(Line)]),
  
  %% Find arrow position
  case binary:match(Line, <<"->">>) of
    {Pos, _} -> io:format("Arrow -> at position: ~w~n", [Pos]);
    nomatch -> io:format("No arrow~n")
  end.
