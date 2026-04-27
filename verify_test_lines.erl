-module(verify_test_lines).
-export([test/0]).

test() ->
  Original = ~b"""
  find_doc_prefix(Trimmed) ->
    case Trimmed of
      <<"%", "%", "%", _/binary>> -> <<"%%% ">>;
      <<"%", "%", _/binary>> -> <<"%% ">>;
      <<"%", "% ->", _/binary>> -> <<"%% ">>;
      ~"%% abc, -> \"efg, xxx\"" -> <<"%% abc">>;
      ~b"%% cde, efg, xxx" -> <<"%% cde">>;
      ~B"%% efg, efg, xyz" -> <<"%% efg">>;
      _ -> <<"%% ">>
    end.
  """,
  
  Lines = binary:split(Original, <<"\n">>, [global]),
  case Lines of
    [Line0, Line1, Line2, Line3, Line4, Line5, Line6, Line7, Line8, Line9, Line10 | _] ->
      io:format("Line 4 (case binary pattern 1): ~w bytes~n", [byte_size(Line4)]),
      io:format("Content: ~s~n~n", [Line4]),
      io:format("Line 5 (case binary pattern 2): ~w bytes~n", [byte_size(Line5)]),
      io:format("Content: ~s~n~n", [Line5]);
    _ ->
      io:format("Not enough lines~n")
  end.
