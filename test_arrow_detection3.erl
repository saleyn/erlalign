-module(test_arrow_detection3).
-export([test/0]).

%% The functions from erlalign.erl
find_sigil_close(<<>>, _Count) ->
  nomatch;
find_sigil_close(<<"\"\"", _/binary>>, Count) ->
  {Count + 2, found};
find_sigil_close(<<"\\\"", Rest/binary>>, Count) ->
  case Rest of
    <<"\"", _/binary>> ->
      {Count + 2, found};
    _ ->
      find_sigil_close(Rest, Count + 2)
  end;
find_sigil_close(<<_:1/binary, Rest/binary>>, Count) ->
  find_sigil_close(Rest, Count + 1).

find_string_close(<<>>, _Count) ->
  nomatch;
find_string_close(<<"\"", _/binary>>, Count) ->
  {Count + 1, found};
find_string_close(<<_:1/binary, Rest/binary>>, Count) ->
  find_string_close(Rest, Count + 1).

find_real_arrow(Line, Pos) when Pos >= byte_size(Line) - 1 ->
  -1;
find_real_arrow(Line, Pos) ->
  Remaining = binary:part(Line, Pos, byte_size(Line) - Pos),
  case Remaining of
    <<"->", _/binary>> ->
      Pos;
    <<"~\"", Rest/binary>> ->
      case find_sigil_close(Rest, 0) of
        {Offset, found} ->
          find_real_arrow(Line, Pos + 2 + Offset);
        nomatch ->
          find_real_arrow(Line, Pos + 2)
      end;
    <<"\"", Rest/binary>> ->
      case find_string_close(Rest, 0) of
        {Offset, found} ->
          find_real_arrow(Line, Pos + 1 + Offset);
        nomatch ->
          find_real_arrow(Line, Pos + 1)
      end;
    <<_:1/binary, _/binary>> ->
      find_real_arrow(Line, Pos + 1)
  end.

test() ->
  %% Line 4 from the test
  Line = <<"    ~\"%% abc, -> \\\"efg, xxx\\\"\"  ->"  , 32:8, 60:8, 60:8>>, % Adding some bytes at the end
  io:format("Line: ~p~n", [Line]),
  io:format("Size: ~p~n", [byte_size(Line)]),
  
  Pos = find_real_arrow(Line, 0),
  io:format("Arrow position: ~p~n", [Pos]).
