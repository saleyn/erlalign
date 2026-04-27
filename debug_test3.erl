-module(debug_test3).
-export([test/0]).

test() ->
  %% Test just the problematic sigil line
  Line = <<"    ~\"%% abc, \"efg, xxx\"\"     ->"  >>,
  io:format("Full line: ~p~n", [Line]),
  io:format("Length: ~w~n", [byte_size(Line)]),
  
  %% Manually test what happens after ~"
  AfterTilde = <<"~\"%% abc, \"efg, xxx\"\"     ->">>,
  AfterQuote = <<"%% abc, \"efg, xxx\"\"     ->">>,
  
  io:format("~nAfter tilde (sigil): ~p~n", [AfterTilde]),
  io:format("After quote: ~p~n", [AfterQuote]),
  
  %% Test find_quote_close directly
  Result = erlalign:find_quote_close_debug(AfterQuote),
  io:format("find_quote_close result: ~p~n", [Result]),
  
  ok.
