-module(test_exact_bytes).
-export([test/0]).

test() ->
  %% This is the exact line from the test output
  Line = <<"    ~\"%% abc, -> \\\"efg, xxx\\\"\" -> <<\"%% abc\">>;">>,
  
  io:format("Line as printed: ~p~n", [Line]),
  io:format("Size: ~p~n", [byte_size(Line)]),
  
  %% Get the bytes
  Bytes = binary_to_list(Line),
  io:format("First 40 bytes: ~p~n", [lists:sublist(Bytes, 40)]),
  
  %% Find arrow positions
  case binary:match(Line, <<"->">>) of
    {Pos1, 2} ->
      %% Find next arrow
      Rest1 = binary:part(Line, Pos1 + 2, byte_size(Line) - Pos1 - 2),
      case binary:match(Rest1, <<"->">>) of
        {Pos2, 2} ->
          io:format("First -> at ~p, Second -> at ~p~n", [Pos1, Pos1 + 2 + Pos2]);
        nomatch ->
          io:format("First -> at ~p, No second->~n", [Pos1])
      end;
    nomatch ->
      io:format("No -> found~n", [])
  end.
