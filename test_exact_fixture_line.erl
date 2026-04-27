-module(test_exact_fixture_line).
-export([test/0]).

test() ->
  %% Extract EXACT line as it appears in test fixture
  %% Line 4 from the case statement 
  Line4_Raw = ~b"""        ~"%% abc, -> \"efg, xyz\"" -> <<"%% abc">>;""",
  
  io:format("Line 4 from fixture (~w bytes)~n", [byte_size(Line4_Raw)]),
  io:format("Content: ~s~n~n", [Line4_Raw]),
  
  case binary:match(Line4_Raw, <<"->">>) of
    {Pos, _} -> io:format("First -> found by binary:match at: ~w~n", [Pos]);
    nomatch -> io:format("No ->~n")
  end,
  
  Pos = erlalign:find_arrow_pos(Line4_Raw),
  io:format("find_arrow_pos returned: ~w~n", [Pos]).
