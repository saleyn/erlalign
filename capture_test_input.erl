-module(capture_test_input).
-export([test/0]).

test() ->
  Original = ~b"""
  find_doc_prefix(Trimmed) ->
    case Trimmed of
      <<"%", "%", "%", _/binary>> -> <<"%%% ">>;
      <<"%", "%", _/binary>> -> <<"%% ">>;
      <<"%", "% ->", _/binary>> -> <<"%% ">>;
      ~"%% abc, \"efg, xxx\"" -> <<"%% abc">>;
      ~"%% abc, -> \"efg, xxx\"" -> <<"%% abc">>;
      ~b"%% cde, efg, xxx" -> <<"%% cde">>;
      ~B"%% efg, efg, xyz" -> <<"%% efg">>;
      _ -> <<"%% ">>
    end.
  """,
  
  Lines = binary:split(Original, <<"\n">>, [global]),
  lists:foreach(fun({N, Line}) ->
    case Line of
      <<>> -> ok;
      _ ->
        case binary:match(Line, <<"->">>) of
          nomatch -> ok;
          {FirstPos, _} ->
            io:format("Line ~w (~w bytes): ~s~n", [N, byte_size(Line), Line]),
            io:format("  First -> at position ~w~n", [FirstPos])
        end
    end
  end, lists:zip(lists:seq(1, length(Lines)), Lines)).
