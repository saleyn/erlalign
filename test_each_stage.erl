-module(test_each_stage).
-export([test/0]).

test() ->
  Original = <<"find_doc_prefix(Trimmed) ->\n  case Trimmed of\n    <<\"%\", \"%\", \"%\", _/binary>> -> <<\"%%% \">>;    \n    <<\"%\", \"%\", _binary>> -> <<\"%% \">>;     \n    ~\"%% abc, \\\"efg, xyz\\\"\" -> <<\"%% abc\">>;     \n    _ -> <<\"%% \">>\n  end.">>,
  
  io:format("=== ORIGINAL ===~n~s~n~n", [Original]),
  
  Aligned1 = erlalign:align_variable_assignments(Original),
  io:format("=== AFTER align_variable_assignments ===~n~s~n~n", [Aligned1]),
  
  case Aligned1 =/= Original of
    true ->
      io:format("CHANGED by align_variable_assignments~n"),
      case binary:match(Aligned1, <<"->">>) of
        nomatch -> io:format("No -> found~n");
        {Pos, _} -> 
          Start = max(0, Pos - 10),
          Length = min(20, byte_size(Aligned1) - Start),
          io:format("Found -> at ~w, context: ~n", [Pos]),
          lists:foreach(fun(B) ->
            if B >= 32, B < 127 -> io:format("~c", [B]);
               true -> io:format("[~w]", [B])
            end
          end, binary:bin_to_list(binary:part(Aligned1, Start, Length)))
      end;
    false ->
      io:format("NO CHANGE by align_variable_assignments~n")
  end,
  
  ok.
