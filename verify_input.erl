-module(verify_input).
-export([test/0]).

test() ->
  Original = <<"find_doc_prefix(Trimmed) ->\n  case Trimmed of\n    <<\"%\", \"%\", \"%\", _/binary>> -> <<\"%%% \">>;\ \n    <<\"%\", \"%\", _/binary>> -> <<\"%% \">>;    \n    ~\"%% abc, \\\"efg, xxx\\\"\" -> <<\"%% abc\">>;     \n    ~b\"%% cde, efg, xyz\" -> <<\"%% cde\">>;        \n    ~B\"%% efg, efg, xyz\" -> <<\"%% efg\">>;        \n    _                           -> <<\"%% \">>\n  end.">>,
  
  %% Split into lines
  Lines = binary:split(Original,<<"\n">>, [global]),
  
  %% Find the sigil line
  lists:foreach(fun(Line) ->
    case binary:match(Line, <<"~">>) of
      nomatch -> ok;
      {Pos, _} ->
        io:format("Found sigil line at position ~w~n", [Pos]),
        io:format("Line: ~s~n", [Line]),
        io:format("Bytes around sigil: "),
        <<_:Pos/binary, Sub:15/binary, _/binary>> = Line,
        lists:foreach(fun(B) -> 
          if B >= 32, B < 127 -> io:format("~c", [B]);
             true -> io:format("[~w]", [B])
          end
        end, binary_to_list(Sub)),
        io:format("~n")
    end
  end, Lines),
  
  ok.
