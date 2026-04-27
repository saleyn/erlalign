-module(test_arrow_find).
-export([test/0]).

test() ->
  Lines = [
    <<"    <<\"%\", \"%\", \"%\", _/binary>> -> <<\"%%% \">>;">>,
    <<"    <<\"%\", \"%\", _/binary>> -> <<\"%% \">>;  ">>,
    <<"    ~\"%% abc, \\\"efg, xyz\\\"\" -> <<\"%% abc\">>;  ">>,
    <<"    ~b\"%% cde, efg, xyz\" -> <<\"%% cde\">>;  ">>,
    <<"    _ -> <<\"%% \">>;">>
  ],
  
  io:format("Testing find_arrow_pos for each line:~n"),
  
  lists:foreach(fun(Line) ->
    Pos = erlalign:find_arrow_pos(Line),
    Bytes = case Pos >= 0 andalso Pos + 2 <= byte_size(Line) of
      true  -> binary:part(Line, Pos, 2);
      false -> <<"???">>
    end,
    
    io:format("Pos: ~w, bytes: ", [Pos]),
    lists:foreach(fun(B) -> 
      if B >= 32, B < 127 -> io:format("~c", [B]);
         true -> io:format("[~w]", [B])
      end
    end, binary_to_list(Bytes)),
    
    io:format("~n"),
    
    %% Verify it's an arrow
    case Pos >= 0 andalso binary:part(Line, Pos, 2) =:= <<"->">> of
      true  -> io:format("  CORRECT~n");
      false -> io:format("  WRONG~n")
    end
  end, Lines),
  
  ok.
