-module(verify_test_lines2).
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
    io:format("Line ~w (~w bytes): ", [N, byte_size(Line)]),
    case binary:match(Line, <<"<<">>) orelse binary:match(Line, <<"~">>) of
      nomatch -> io:format("(not a case line)~n");
      {_, _} ->
        io:format("~s~n", [binary:part(Line, 0, min(50, byte_size(Line)))]),
        case binary:match(Line, <<"->">>) of
          {Pos, _} -> io:format("  Arrow at position: ~w~n", [Pos]);
          nomatch -> ok
        end
    end
  end, lists:zip(lists:seq(1, length(Lines)), Lines)).
