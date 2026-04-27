-module(test_content).
-export([test/0]).

test() ->
  Line = <<"    ~\"%% abc, -> \\\"efg, xyz\\\"\" -> <<\"%% abc\">>;">>,
  io:format("Line: ~s~n", [Line]),
  io:format("Line bytes: ~w~n", [binary:bin_to_list(Line)]),
  
  % Simulate what find_real_arrow does
  {match, [{TildePos, _}]} = binary:match(Line, <<"~">>),
  io:format("Tilde at position: ~w~n", [TildePos]),
  
  % Extract from tilde
  Remaining = binary:part(Line, TildePos, byte_size(Line) - TildePos),
  io:format("From tilde: ~s~n", [Remaining]),
  
  % Extract after ~"
  case Remaining of
    <<"~\"", ContentRest/binary>> ->
      io:format("Content after ~\": ~s~n", [ContentRest]),
      io:format("Content bytes: ~w~n", [binary:bin_to_list(ContentRest)]),
      
      % Now find sigil close
      Result = erlalign:find_sigil_close(ContentRest, 0),
      io:format("find_sigil_close result: ~w~n", [Result]);
    _ ->
      io:format("Sigil pattern not found~n")
  end,
  halt().
