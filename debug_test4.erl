-module(debug_test4).
-export([test/0]).

test() ->
  %% What does the Erlang compiler actually create for this sigil?
  String1 = ~"%% abc, \"efg, xxx\"",
  io:format("Sigil string: ~p~n", [String1]),
  io:format("Sigil as binary: ~w~n", [String1]),
  io:format("Bytes:~n"),
  lists:foreach(fun(B) -> io:format("  ~w (~c)~n", [B, B]) end, binary_to_list(String1)),
  ok.
