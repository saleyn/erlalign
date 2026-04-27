-module(test_sigil_with_arrow).
-export([test/0]).

test() ->
  %% The line with arrow INSIDE the sigil content
  Line = <<"    ~\"%% abc, -> \\\"efg, xxx\\\"\" -> <<\"%% abc\">>;">>,
  
  io:format("Line: ~s~n", [Line]),
  io:format("Line size: ~w~n", [byte_size(Line)]),
  
  %% How many arrows?
  case binary:match(Line, <<"->">>, [{scope, {0, byte_size(Line)}}]) of
    {Pos1, _} ->
      io:format("First -> at: ~w~n", [Pos1]),
      case binary:match(Line, <<"->">>, [{scope, {Pos1+2, byte_size(Line)-Pos1-2}}]) of
        {Pos2, _} ->
          io:format("Second -> at: ~w~n", [Pos2]);
        nomatch ->
          io:format("No second ->~n")
      end
  end,
  
  %% What does find_arrow_pos return?
  Result = erlalign:find_arrow_pos(Line),
  io:format("find_arrow_pos returned: ~w~n", [Result]),
  
  ok.
