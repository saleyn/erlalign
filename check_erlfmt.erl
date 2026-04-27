-module(check_erlfmt).
-export([test/0]).

test() ->
  Original = ~b"""
  find_doc_prefix(Trimmed) ->
    case Trimmed of
      <<"%", "%", "%", _/binary>> -> <<"%%% ">>;
      <<"%", "%", _/binary>> -> <<"%% ">>;
      ~"%% abc, \"efg, xxx\"" -> <<"%% abc">>;
      ~b"%% cde, efg, xxx" -> <<"%% cde">>;
      ~B"%% efg, efg, xyz" -> <<"%% efg">>;
      _ -> <<"%% ">>
    end.
  """,
  
  %% Check what erlfmt produces
  case erlfmt:format_string(Original, []) of
    {ok, Formatted} ->
      Lines = binary:split(Formatted, <<"\n">>, [global]),
      lists:foreach(fun(Line) ->
        case binary:match(Line, <<"abc">>) of
          nomatch -> ok;
          {_,_} ->
            %% This is a line containing the sigil
            io:format("Formatted line length: ~w~n", [byte_size(Line)]),
            io:format("Formatted line: ~s~n", [Line]),
            %% Show the bytes
            case binary:match(Line, <<"abc">>) of
              {Pos, _} ->
                Start = max(0, Pos - 10),
                Length = min(30, byte_size(Line) - Start),
                Sub = binary:part(Line, Start, Length),
                io:format("Bytes: "),
                lists:foreach(fun(B) ->
                  if B >= 32, B < 127 -> io:format("~c", [B]);
                     B == 92 -> io:format("BSLASH");
                     B == 34 -> io:format("QUOTE");
                     true -> io:format("[~w]", [B])
                  end
                end, binary_to_list(Sub)),
                io:format("~n")
            end
        end
      end, Lines);
    {error, Err} ->
      io:format("erlfmt error: ~p~n", [Err])
  end,
  ok.
