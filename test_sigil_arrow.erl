-module(test_sigil_arrow).
-export([test/0]).

test() ->
  %% The exact line from the test
  Line = <<"    ~\"%% abc, \\\"efg, xxx\\\"\" -> <<\"%% abc\">>;">>, 
  
  io:format("Line: ~s~n", [Line]),
  io:format("Line size: ~w~n", [byte_size(Line)]),
  
  %% Find actual arrow position manually
  case binary:match(Line, <<"->">>) of
    {Pos, _} ->
      io:format("First -> found at: ~w~n", [Pos]),
      io:format("Bytes: ~s~n", [binary:part(Line, Pos, 2)]);
    nomatch -> io:format("No -> found~n")
  end,
  
  %% Find with find_arrow_pos
  Result = erlalign:find_arrow_pos(Line),
  io:format("find_arrow_pos returned: ~w~n", [Result]),
  
  case Result >= 0 andalso Result < byte_size(Line) of
    true ->
      Bytes = binary:part(Line, Result, min(2, byte_size(Line) - Result)),
      io:format("Bytes at pos: ~s~n", [Bytes]);
    false -> io:format("Invalid position~n")
  end,
  
  ok.
