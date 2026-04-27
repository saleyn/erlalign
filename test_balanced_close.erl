-module(test_balanced_close).
-export([test/0]).

test() ->
  % Content after << in the first line
  Content1 = <<"\"%\", \"%\", \"%\", _/binary>> -> <<\"%%% \">>;">>,
  
  io:format("Testing find_balanced_close on a binary pattern:~n"),
  io:format("Content: ~s~n", [Content1]),
  
  % This should find the position of >> (not including it)
  % Expected: 23 (the bytes from after << to before the first >>)
  Result1 = erlalign:find_balanced_close_debug(Content1, 0, false),
  
  io:format("Result: ~p~n", [Result1]),
  io:format("Expected: around 23 (bytes until first >>)~n"),
  
  case Result1 of
    nomatch -> io:format("ERROR: find_balanced_close returned nomatch!~n");
    N when is_integer(N) ->
      EndPos = 4 + 2 + N + 2,  % Pos + << + Offset + >>
      io:format("End position would be: ~w~n", [EndPos]),
      io:format("That corresponds to the byte sequence: ~s~n", [binary:part(Content1, 0, N)])
  end,
  ok.
