-module(test_sigil_close_fix2).
-export([test/0]).

%% Find closing "" for a sigil
find_sigil_close(<<>>, _Count) ->
  nomatch;
%% Two consecutive quotes - sigil end for unescaped content
find_sigil_close(<<"\"\"", _/binary>>, Count) ->
  {Count, found};
%% Backslash-quote followed by quote: \" then " - this ends the sigil!
find_sigil_close(<<"\\\"", Rest/binary>>, Count) ->
  case Rest of
    <<"\"", _/binary>> ->
      %% This is \"" which ends the sigil!
      %% Count points to \, Count+1 is ", Count+2 is the closing "
      {Count + 2, found};
    _ ->
      %% Just an escaped quote in content, keep scanning
      find_sigil_close(Rest, Count + 2)
  end;
%%Regular character - count it and continue
find_sigil_close(<<_:1/binary, Rest/binary>>, Count) ->
  find_sigil_close(Rest, Count + 1).

test() ->
  %% Test case 2: Escaped quote sigil  
  Content2 = <<"%% abc, -> \\\"efg, xyz\\\"\"">>,
  io:format("Content: ~p~n", [Content2]),
  io:format("Bytes: "),
  [io:format("~w ", [B]) || B <- binary_to_list(Content2)],
  io:format("~n"),
  
  case find_sigil_close(Content2, 0) of
    {Offset2, found} ->
      io:format("Offset: ~p (expected 25)~n", [Offset2]);
    Other2 ->
      io:format("Result: ~p~n", [Other2])
  end.
