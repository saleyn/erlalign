-module(debug_test).
-export([test/0]).

test() ->
  Line1 = <<"    <<\"%\", \"%\", \"%\", _/binary>> ->">>,
  io:format("Testing line: ~p~n", [Line1]),
  
  %% Test the protected regions
  Protected = erlalign:find_protected_regions_debug(Line1),
  io:format("Protected regions: ~p~n", [Protected]),
  
  %% Test arrow position
  Pos = erlalign:find_arrow_pos(Line1),
  io:format("Arrow position: ~p~n", [Pos]),
  
  %% Manual check
  io:format("Byte at arrow pos: ~p~n", [binary:part(Line1, Pos, 2)]),
  ok.
