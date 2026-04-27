-module(test_sigil_debug).
-export([test/0]).

test() ->
  % The content after ~" in the problematic sigil
  Content = <<"%% abc, -> ", 92, 34, "efg, xxx", 92, 34>>, % 92=\, 34="
  io:format("Content bytes: ~w~n", [Content]),
  io:format("Content as string: ~s~n", [Content]),
  
  % Manual tracing
  Len = byte_size(Content),
  io:format("Content length: ~w~n", [Len]),
  
  % Find where the closing quote actually is
  ClosingQuotePos = Len - 1,
  io:format("Last byte (should be closing quote): ~w~n", [binary:at(Content, ClosingQuotePos)]),
  
  % Test find_sigil_close
  case find_sigil_close(Content, 0) of
    {Offset, found} ->
      io:format("find_sigil_close returned: ~w~n", [Offset]),
      io:format("Expected: ~w (position after closing quote)~n", [Len]);
    nomatch ->
      io:format("No match found~n")
  end.

find_sigil_close(<<>>, _Count) ->
  nomatch;
find_sigil_close(<<"\"\"", _/binary>>, Count) ->
  {Count + 2, found};
find_sigil_close(<<"\\\"", Rest/binary>>, Count) ->
  case Rest of
    <<"\"", _/binary>> ->
      {Count + 2, found};
    _ ->
      find_sigil_close(Rest, Count + 2)
  end;
find_sigil_close(<<_:1/binary, Rest/binary>>, Count) ->
  find_sigil_close(Rest, Count + 1).
