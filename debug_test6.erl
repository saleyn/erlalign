-module(debug_test6).
-export([test/0]).

test() ->
  %%  Content after the opening ~ in ~"%% abc, \"efg, xxx\""
  Content = <<"%% abc, \\\"efg, xxx\\\"\"">>,
  io:format("Content: ~s~n", [Content]),
  io:format("Bytes: "),
  lists:foreach(fun(B) -> if B >= 32, B < 127 -> io:format("~c", [B]); true -> io:format("[~w]", [B]) end end, binary_to_list(Content)),
  io:format("~n~n"),
  
  %% Test find_quote_close
  Result = erlalign:find_quote_close_debug(Content),
  io:format("find_quote_close result: ~p~n", [Result]),
  
  %% Expected: the byte count to the CLOSING quote
  %% That should be: %% abc, \"efg, xxx\" = 21 bytes before the closing quote
  io:format("Expected: ~w (bytes before closing quote)~n", [byte_size(Content) - 1]),
  
  ok.
