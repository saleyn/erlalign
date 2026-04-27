-module(check_arrow_pos).
-export([test/0]).

test() ->
  Lines = [
    <<"        <<\"%\", \"%\", \"%\", _/binary>> -> <<"%%% \">>;  ">>,
    <<"        <<\"%\", \"%\", _/binary>> -> <<\"%% \">>;">>,
    <<"        <<\"%\", \"% ->\", _/binary>> -> <<\"%% \">>;  ">>,
    <<"        ~\"%% abc, -> \\\"efg, xxx\\\"\" -> <<\"%% abc\">>;">>,
  ],
  
  Positions = lists:map(fun(Line) ->
    {erlalign:find_arrow_pos(Line), string:trim(Line)}
  end, Lines),
  
  lists:foreach(fun({Pos, _Line}) ->
    case Pos of
      -1 -> io:format("  Arrow not found~n");
      _ -> io:format("  Pos: ~3w~n", [Pos])
    end
  end, Positions),
  
  {ValidPos, _} = lists:unzip(Positions),
  MaxPos = lists:max([P || P <- ValidPos, P >= 0]),
  io:format("~nMax position: ~w~n", [MaxPos]),
  
  % Calculate expected padding for each line
  io:format("~nExpected padding per line:~n"),
  lists:foreach(fun({Pos, Line}) ->
    case Pos of
      -1 -> 
        % This line wasn't aligned, just print it
        io:format("  (arrow not found) ~s~n", [Line]);
      _ when Pos < MaxPos ->
        Padding = MaxPos - Pos,
        io:format("  +~w spaces | longest: ~s~n", [Padding, Line]);
      _ ->
        io:format("  +0 spaces | longest: ~s~n", [Line])
    end
  end, Positions),
  
  halt().
