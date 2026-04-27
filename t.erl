-module(t).
-export([find_doc_prefix/1]).

find_doc_prefix(Trimmed) ->
  case Trimmed of
    <<"%", "%", "%", _/binary>> -> <<"%%% ">>;
    <<"%", "%", _/binary>> -> <<"%% ">>;
    <<"%", "% ->", _/binary>> -> <<"%% ">>;
    ~"%% abc, -> \"efg, xxx\"" -> <<"%% abc">>;
    ~b"%% cde, efg, xxx" -> <<"%% cde">>;
    ~B"%% efg, efg, xxx" -> <<"%% efg">>;
    _ -> <<"%% ">>
  end.
