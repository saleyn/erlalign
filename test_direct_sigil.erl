-module(test_direct_sigil).
-export([test/0]).

test() ->
  % The actual line from the test
  Line = <<"    ~\"%% abc, -> \\\"efg, xyz\\\"\" -> <<\"%% abc\">>;">>,
  
  io:format("Full line: ~s~n", [Line]),
  io:format("Line length: ~w~n", [byte_size(Line)]),
  
  % Manually find arrow
  case binary:match(Line, <<"->">>) of
    {Pos, Len} ->
      io:format("Arrow found at position ~w~n", [Pos]);
    nomatch ->
      io:format("No arrow found with binary:match~n")
  end,
  
  % Use find_arrow_pos
  ArrowPos = erlalign:find_arrow_pos(Line),
  io:format("find_arrow_pos returned: ~w~n", [ArrowPos]),
  
  % Extract the sigil part
  SigilStart = 4,
  SigilEnd = binary:match(Line, <<"\" ->">>),
  case SigilEnd of
    {EndPos, _} ->
      Sigil = binary:part(Line, SigilStart, EndPos - SigilStart + 1),
      io:format("Sigil: ~s~n", [Sigil]),
      io:format("Sigil length: ~w~n", [byte_size(Sigil)]);
    nomatch ->
      io:format("Could not find sigil end~n")
  end.
