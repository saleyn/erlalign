-module(verify_bytes).
-export([test/0]).

test() ->
  L1 = <<"<<\"%\", \"%\", \"%\", _/binary>> -> <<\"%%% \">>;">>,
  L2 = <<"<<\"%\", \"%\", _/binary>> -> <<\"%% \">>;">>,
  L3 = <<"<<\"%\", \"% ->\", _/binary>> -> <<\"%% \">>;">>,
  L4 = <<"~\"%% abc, \\\"efg, xxx\\\"\" -> <<\"%% abc\">>;">>,
  L5 = <<"~\"%% abc, -> \\\"efg, xxx\\\"\" -> <<\"%% abc\">>;">>,
  L6 = <<"~b\"%% cde, efg, xxx\" -> <<\"%% cde\">>;">>,
  L7 = <<"~B\"%% efg, efg, xyz\" -> <<\"%% efg\">>;">>,
  L8 = <<"_ -> <<\"%% \">>;">>,
  
  Lines = [L1, L2, L3, L4, L5, L6, L7, L8],
  lists:foreach(fun({N, Line}) ->
    io:format("Line ~w: ~w bytes~n", [N, byte_size(Line)])
  end, lists:zip(lists:seq(1, length(Lines)), Lines)).
