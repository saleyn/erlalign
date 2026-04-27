-module(debug_test7).
-export([test/0]).

test() ->
  %% The actual case line from the input
  Line = <<"    ~\"%% abc, \\\"efg, xxx\\\"\" -> <<\"%% abc\">>;">>,
  io:format("Testing full line:~n"),
  io:format("  Line: ~s~n", [Line]),
  io:format("  Length: ~w~n", [byte_size(Line)]),
  
  %% Test protected regions
  Protected = erlalign:find_protected_regions_debug(Line),
  io:format("  Protected regions: ~p~n", [Protected]),
  
  %% Test arrow position
  Pos = erlalign:find_arrow_pos(Line),
  io:format("  Arrow position: ~p~n", [Pos]),
  
  case Pos >= 0 of
    true  -> io:format("  Bytes at arrow pos: ~s~n", [binary:part(Line, Pos, min(2, byte_size(Line) - Pos))]);
    false -> io:format("  No arrow found!~n")
  end,
  
  ok.
