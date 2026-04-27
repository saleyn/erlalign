-module(verify_test_lines3).
-export([test/0]).

test() ->
  Original = ~b"""
  find_doc_prefix(Trimmed) ->
    case Trimmed of
      <<"%", "%", "%", _/binary>> -> <<"%%% ">>;
      <<"%", "%", _/binary>> -> <<"%% ">>;
      <<"%", "% ->", _/binary>> -> <<"%% ">>;
      ~"%% abc, -> \"efg, xxx\"" -> <<"%% abc">>;
      ~b"%% cde, efg, xyz" -> <<"%% cde">>;
      ~B"%% efg, efg, xyz" -> <<"%% efg">>;
      _ -> <<"%% ">>
    end.
  """,
  
  Lines = binary:split(Original, <<"\n">>, [global]),
  io:format("Total lines: ~w~n", [length(Lines)]),
  
  lists:foreach(fun({N, Line}) ->
    HasBinary = binary:match(Line, <<"<<">>) =/= nomatch,
    HasSigil = binary:match(Line, <<"~">>) =/= nomatch,
    case {HasBinary, HasSigil} of
      {true, _} ->
        io:format("Line ~w (~w bytes): ~s~n", [N, byte_size(Line), binary:part(Line, 0, min(50, byte_size(Line)))]),
        case binary:match(Line, <<"->">>) of
          {Pos, _} -> io:format("  Arrow at position: ~w~n", [Pos]);
          nomatch -> io:format("  No arrow~n")
        end;
      {_, true} ->
        io:format("Line ~w (~w bytes): ~s~n", [N, byte_size(Line), binary:part(Line, 0, min(50, byte_size(Line)))]),
        case binary:match(Line, <<"->">>) of
          {Pos, _} -> io:format("  Arrow at position: ~w~n", [Pos]);
          nomatch -> io:format("  No arrow~n")
        end;
      _ -> ok
    end
  end, lists:zip(lists:seq(1, length(Lines)), Lines)).
