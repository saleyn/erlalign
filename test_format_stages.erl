-module(test_format_stages).
-export([test/0]).

test() ->
  Original = <<"find_doc_prefix(Trimmed) ->\n  case Trimmed of\n    <<\"%\", \"%\", \"%\", _/binary>> -> <<\"%%% \">>;   \n    <<\"%\", \"%\", _/binary>> -> <<\"%% \">>;     \n    ~\"%% abc, \\\"efg, xyz\\\"\" -> <<\"%% abc\">>;     \n    ~b\"%% cde, efg, xyz\" -> <<\"%% cde\">>;        \n    ~B\"%% efg, efg, xyz\" -> <<\"%% efg\">>;        \n    _                           -> <<\"%% \">>\n  end.">>,
  
  io:format("ORIGINAL:~n~s~n~n", [Original]),
  
  %% Stage 1
  Aligned1 = erlalign:align_variable_assignments(Original),
 io:format("AFTER align_variable_assignments:~n~s~n~n", [Aligned1]),
  
  %% Check if it changed
  case Aligned1 =:= Original of
    true  -> io:format("Stage 1: NO CHANGE~n");
    false -> io:format("Stage 1: CHANGED!~n")
  end,
  io:format("~n"),
  
  %% Stage 2
  Aligned2 = erlalign:align_case_arrows(Aligned1),
  io:format("AFTER align_case_arrows:~n~s~n~n", [Aligned2]),
  
  case Aligned2 =:= Aligned1 of
    true  -> io:format("Stage 2: NO CHANGE~n");
    false -> io:format("Stage 2: CHANGED!~n")
  end,
  io:format("~n"),
  
  %% Stage 3
  Aligned3 = erlalign:align_comments(Aligned2),
  io:format("AFTER align_comments:~n~s~n~n", [Aligned3]),
  
  case Aligned3 =:= Aligned2 of
    true  -> io:format("Stage 3: NO CHANGE~n");
    false -> io:format("Stage 3: CHANGED!~n")
  end,
  
  ok.
