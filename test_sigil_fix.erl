-module(test_sigil_close).
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
      %% The \" is the content (escaped quote), the final " closes it
      {Count + 1, found};
    _ ->
      %% Just an escaped quote in content, keep scanning
      find_sigil_close(Rest, Count + 2)
  end;
%% Regular character - count it and continue
find_sigil_close(<<_:1/binary, Rest/binary>>, Count) ->
  find_sigil_close(Rest, Count + 1).

test() ->
  %% Test case 1: Normal sigil with `` closing
  Content1 = <<"%% abc">> ,
  {Offset1, found} = find_sigil_close(Content1, 0),
  io:format("Test 1 (normal): offset ~p (expected 6)~n", [Offset1]),

  %% Test case 2: Escaped quote sigil  
  Content2 = <<"%% abc, -> \\\"efg, xyz\\\"\"">>,
  case find_sigil_close(Content2, 0) of
    {Offset2, found} ->
      io:format("Test 2 (escaped): offset ~p (expected 23)~n", [Offset2]);
    Other ->
      io:format("Test 2 (escaped): ~p~n", [Other])
  end.
