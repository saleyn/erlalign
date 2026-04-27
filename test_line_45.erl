-module(test_line_45).
-export([test/0]).

test() ->
  %% Create a 45-byte line
  %% 4 spaces + ~"... pattern
  Line = <<"    ~\"%% abc, -> \"efg, xxx\\\"\""             >>,
  io:format("Line: ~p~n", [Line]),
  io:format("Size: ~p~n", [byte_size(Line)]),
  
  %% Count bytes
  Bytes = binary_to_list(Line),
  io:format("Bytes: ~p~n", [Bytes]),
  io:format("Byte count: ~p~n", [length(Bytes)]),
  
  %% Find arrow manually
  case binary:match(Line, <<"->">>) of
    {Pos, 2} ->
      io:format("Arrow at position: ~p~n", [Pos]);
    nomatch ->
      io:format("No arrow found~n", [])
  end.
