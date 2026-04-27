-module(test_exact_fixture_line2).
-export([test/0]).

test() ->
  %% Extract EXACT line as it appears in test fixture (with literal backslashes)
  %% Line 4 from the case statement:  ~"%% abc, -> \"efg, xyz\"" -> <<"%% abc">>;
  %% But in a raw binary string with 8-space indentation
  Line4_Raw = <<"        ~\"%% abc, -> \\\"efg, xyz\\\"\" -> <<\"%% abc\">>;">>,
  
  io:format("Line 4 from fixture (~w bytes)~n", [byte_size(Line4_Raw)]),
  io:format("Content: ~s~n~n", [Line4_Raw]),
  
  case binary:match(Line4_Raw, <<"->">>) of
    {Pos1, _} -> io:format("First -> found by binary:match at: ~w~n", [Pos1]);
    nomatch -> io:format("No ->~n")
  end,
  
  Pos2 = erlalign:find_arrow_pos(Line4_Raw),
  io:format("find_arrow_pos returned: ~w~n", [Pos2]).
