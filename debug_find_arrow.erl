-module(debug_find_arrow).
-export([test/0]).

test() ->
  Line2 = <<"        <<\"%\", \"%\", _/binary>> -> <<\"%% \">>;">>,
  io:format("Testing line (~w bytes): ~s~n", [byte_size(Line2), Line2]),
  
  %% Call the erlalign arrow finder
  Result = erlalign:find_arrow_pos(Line2),
  io:format("erlalign:find_arrow_pos returned: ~w~n", [Result]),
  
  %% Manual binary:match for comparison
  case binary:match(Line2, <<"->">>) of
    {Pos, _} -> io:format("binary:match found -> at: ~w~n", [Pos]);
    nomatch -> io:format("binary:match found no ->~n")
  end.
