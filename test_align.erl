-module(test_align).
-export([test/0]).

test() ->
  %% These are the exact lines from the test case
  Line1 = <<"    <<\"%\", \"%\", \"%\", _/binary>> -> <<\"%%% \">>;">>,
  Line2 = <<"    <<\"%\", \"%\", _/binary>> -> <<\"%% \">>;">>,
  Line3 = <<"    ~\"%% abc, \\\"efg, xxx\\\"\" -> <<\"%% abc\">>;">>,
  
  Lines = [Line1, Line2, Line3],
  
  io:format("Testing find_arrow_pos on case lines:~n~n"),
  
  lists:foreach(fun(Line) ->
    Pos = erlalign:find_arrow_pos(Line),
    Protected = erlalign:find_protected_regions_debug(Line),
    
    io:format("Line: ~s~n", [binary:part(Line, 0, min(50, byte_size(Line)))]),
    io:format("  Length: ~w~n", [byte_size(Line)]),
    io:format("  Protected: ~p~n", [Protected]),
    io:format("  Arrow pos: ~w~n", [Pos]),
    
    case Pos >= 0 andalso Pos < byte_size(Line) of
      true ->
        Len = min(2, byte_size(Line) - Pos),
        Bytes = binary:part(Line, Pos, Len),
        io:format("  Bytes at pos: ~s~n", [Bytes]);
      false ->
        io:format("  No arrow found~n")
    end,
    io:format("~n")
  end, Lines),
  
  %% Now test align_group  
  io:format("Testing align_group with these lines:~n"),
  Aligned = erlalign:align_group(Lines, fun erlalign:find_arrow_pos/1),
  lists:foreach(fun(Line) ->
    io:format("~s~n", [Line])
  end, Aligned),
  
  ok.
