-module(analyze_positions).
-export([test/0]).

test() ->
  Lines = [
    <<"        <<\"%\", \"%\", \"%\", _/binary>> -> <<\"%%% \">>;">>,
    <<"        <<\"%\", \"%\", _/binary>> -> <<\"%% \">>;">>,
    <<"        <<\"%\", \"% ->\", _/binary>> -> <<\"%% \">>;">>,
    <<"        ~\"%% abc, \\\"efg, xxx\\\"\" -> <<\"%% abc\">>;">>,
    <<"        ~\"%% abc, -> \\\"efg, xxx\\\"\" -> <<\"%% abc\">>;">>,
    <<"        ~b\"%% cde, efg, xxx\" -> <<\"%% cde\">>;">>,
    <<"        ~B\"%% efg, efg, xyz\" -> <<\"%% efg\">>;">>,
    <<"        _ -> <<\"%% \">>;">>
  ],
  
  lists:foreach(fun({N, Line}) ->
    io:format("Line ~w (~w bytes): ~s~n", [N, byte_size(Line), Line]),
    
    %% Show what's at position 26-30
    case byte_size(Line) >= 30 of
      true ->
        Segment = binary:part(Line, 26, 5),
        io:format("  Bytes 26-30: ~s~n", [Segment]);
      false ->
        ok
    end,
    
    %% Find all arrows in line
    case binary:match(Line, <<"->">>, []) of
      {Pos, _} ->
        io:format("  First -> at position: ~w~n", [Pos]),
        case binary:match(Line, <<"->">>, [{scope, {Pos+2, byte_size(Line)-Pos-2}}]) of
          {Pos2, _} ->
            io:format("  Second -> at position: ~w~n", [Pos2]);
          nomatch ->
            io:format("  Only one ->~n")
        end;
      nomatch ->
        io:format("  No -> found~n")
    end,
    io:format("~n")
  end, lists:zip(lists:seq(1, length(Lines)), Lines)),
  ok.
