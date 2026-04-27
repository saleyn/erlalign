-module(verify_positions).
-export([test/0]).

test() ->
  Line5 = <<"    <<\"%\", \"% ->\", _/binary>> -> <<\"%% \">>;">>,
  Line6 = <<"    ~\"%% abc, -> \\\"efg, xyz\\\"\" -> <<\"%% abc\">>;">>,
  
  io:format("Line 5 (~w bytes): ~s~n", [byte_size(Line5), Line5]),
  case binary:match(Line5, <<"->">>) of
    {Pos, _} -> io:format("  binary:match finds -> at: ~w~n", [Pos]);
    nomatch -> io:format("  No arrow~n")
  end,
  Pos5 = erlalign:find_arrow_pos(Line5),
  io:format("  find_arrow_pos returns: ~w~n~n", [Pos5]),
  
  io:format("Line 6 (~w bytes): ~s~n", [byte_size(Line6), Line6]),
  case binary:match(Line6, <<"->">>) of
    {Pos1, _} -> io:format("  binary:match finds -> at: ~w~n", [Pos1]);
    nomatch -> io:format("  No arrow~n")
  end,
  Pos6 = erlalign:find_arrow_pos(Line6),
  io:format("  find_arrow_pos returns: ~w~n", [Pos6]).
