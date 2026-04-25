%%%-------------------------------------------------------------------
%%% @doc
%%% EDoc to OTP-27 documentation attribute converter for Erlang.
%%%
%%% Converts EDoc-style `@doc' comments and type documentation to OTP-27
%%% compatible `-doc' attributes. Handles HTML markup conversion to Markdown,
%%% @see references, and proper attribute formatting.
%%%
%%% ## Options
%%%
%%% Supported options for `format_code/2':
%%%   - `{line_length, N}' - Width for line wrapping (default: 80, 0 = no wrapping)
%%%   - `{keep_separators, boolean()}' - Keep %%%%---- lines adjacent to -doc
%%%     attributes (default: false)
%%%
%%% Supported options for `process_file/2':
%%%   - `{line_length, N}' - Width for line wrapping (default: 80, 0 = no wrapping)
%%%   - `{keep_separators, boolean()}' - Keep %%%%---- lines (default: false)
%%%   - `{output, FilePath}' - Output file path (default: overwrites input file)
%%%
%%% @end
%%%-------------------------------------------------------------------

-module(erlalign_docs).

-export([
  convert_doc_block/3,
  convert_doc_block/2,
  convert_doc_block/1,
  parse_doc_block/3,
  parse_doc_block/2,
  convert_to_markdown/1,
  format_see_refs/1,
  wrap_lines/2,
  format_doc_attribute/2,
  format_doc_attribute/1,
  format_code/2,
  format_code/1,
  process_file/2,
  process_file/1,
  otp_version/0,
  is_otp_version_supported/0
]).

-define(DEFAULT_LINE_LENGTH, 80).
-define(MINIMUM_OTP_VERSION, 27).

%%--------------------------------------------------------------------
%% @doc
%% Convert an EDoc @doc block to an OTP-27 -doc attribute.
%%--------------------------------------------------------------------
convert_doc_block(TextLines) ->
  convert_doc_block(TextLines, []).

convert_doc_block(TextLines, SeeRefs) ->
  convert_doc_block(TextLines, SeeRefs, []).

convert_doc_block(TextLines, SeeRefs, Opts) ->
  Kind = proplists:get_value(kind, Opts, doc),
  Width = proplists:get_value(line_length, Opts, ?DEFAULT_LINE_LENGTH),
  Lines1 = convert_to_markdown(TextLines),
  Lines2 = Lines1 ++ format_see_refs(SeeRefs),
  Lines3 = wrap_lines(Lines2, Width),
  Lines4 = lists:reverse(lines_dropwhile(fun blank/1, lists:reverse(Lines3))),
  format_doc_attribute(Lines4, Kind).

%%--------------------------------------------------------------------
%% @doc
%% Parse an EDoc @doc block from Erlang source lines.
%%--------------------------------------------------------------------
parse_doc_block(Lines, StartIdx) ->
  parse_doc_block(Lines, StartIdx, <<"%%% ">>).

parse_doc_block(Lines, StartIdx, Prefix) ->
  PLen = byte_size(Prefix),
  FirstLine = case lists:nth(StartIdx + 1, Lines, <<>>) of
    Line when is_binary(Line) -> 
      case binary:match(Line, <<"\r">>) of
        nomatch -> Line;
        _ -> binary:part(Line, 0, byte_size(Line) - 1)
      end;
    Line -> binary:list_to_bin(Line)
  end,
  TagRest = case byte_size(FirstLine) > PLen + 4 of
    true -> binary:part(FirstLine, PLen + 4, byte_size(FirstLine) - PLen - 4);
    false -> <<>>
  end,
  TextLines = case binary:match(TagRest, <<" ">>) of
    {0, 1} -> [binary:part(TagRest, 1, byte_size(TagRest) - 1)];
    _ -> []
  end,
  collect_block_lines(Lines, StartIdx + 1, Prefix, TextLines, [], #{}).

%%--------------------------------------------------------------------
%% @doc
%% Convert EDoc markup to Markdown.
%%--------------------------------------------------------------------
convert_to_markdown(TextLines) ->
  Text = lists:join(<<"\\n">>, TextLines),
  Text2 = re:replace(Text, "`([^'`\\n]+)'", "`\\1`", [global, {return, binary}]),
  binary:split(Text2, <<"\\n">>, [global]).

%%--------------------------------------------------------------------
%% @doc Format @see references as Markdown.
%%--------------------------------------------------------------------
format_see_refs([]) ->
  [];
format_see_refs(Refs) ->
  [<<"See also:">> | lists:map(fun(Ref) ->
    <<"  - `", (binary:list_to_bin(Ref))/binary, "`">>
  end, Refs)].

%%--------------------------------------------------------------------
%% @doc Wrap lines to specified width.
%%--------------------------------------------------------------------
wrap_lines(Lines, 0) ->
  Lines;
wrap_lines(Lines, Width) when is_integer(Width), Width > 0 ->
  {Result, _} = lists:foldl(fun(Line, {Acc, InFence}) ->
    Trimmed = trim_leading_binary(Line),
    case {string:prefix(Trimmed, <<"```">>), InFence} of
      {nomatch, false} ->
        case re:match(Line, <<"^\\s*<\\w">>) of
          {match, _} ->
            {[Line | Acc], InFence};
          nomatch ->
            case re:match(Line, <<"^([-*]|\\d+\\.)\\s">>) of
              {match, _} ->
                Wrapped = wrap_paragraph(Line, Width),
                {lists:reverse(Wrapped) ++ Acc, InFence};
              nomatch ->
                case trim_binary(Line) of
                  <<>> ->
                    {[<<>> | Acc], InFence};
                  _ ->
                    Wrapped = wrap_paragraph(Line, Width),
                    {lists:reverse(Wrapped) ++ Acc, InFence}
                end
            end
        end;
      _ ->
        {[Line | Acc], not InFence}
    end
  end, {[], false}, Lines),
  lists:reverse(Result).

wrap_paragraph(<<>>, _Width) ->
  [<<>>];
wrap_paragraph(Line, Width) ->
  Trimmed = trim_binary(Line),
  case byte_size(Trimmed) =< Width of
    true -> [Trimmed];
    false ->
      Words = binary:split(Trimmed, <<" ">>, [global]),
      wrap_words(Words, Width, <<>>)
  end.

wrap_words([], _Width, Current) ->
  case trim_binary(Current) of
    <<>> -> [];
    Result -> [Result]
  end;
wrap_words([Word | Rest], Width, Current) ->
  Trimmed = trim_binary(Current),
  Candidate = case Trimmed of
    <<>> -> Word;
    _ -> <<Trimmed/binary, " ", Word/binary>>
  end,
  case byte_size(Candidate) =< Width of
    true ->
      wrap_words(Rest, Width, Candidate);
    false ->
      case Trimmed of
        <<>> ->
          [Word | wrap_words(Rest, Width, <<>>)];
        _ ->
          [Trimmed | wrap_words([Word | Rest], Width, <<>>)]
      end
  end.

%%--------------------------------------------------------------------
%% @doc Format collected lines as a -doc attribute.
%%--------------------------------------------------------------------
format_doc_attribute(Lines) ->
  format_doc_attribute(Lines, doc).

format_doc_attribute(Lines, Kind) ->
  KindStr = case Kind of
    moduledoc -> <<"-moduledoc">>;
    _ -> <<"-doc">>
  end,
  StrippedLines = lists:filtermap(fun(Line) ->
    Trimmed = trim_binary(Line),
    case byte_size(Trimmed) of
      0 -> false;
      _ ->
        Stripped = case binary:match(Trimmed, <<".">>, [{scope, {byte_size(Trimmed) - 1, 1}}]) of
          {_Pos, _Len} -> binary:part(Trimmed, 0, byte_size(Trimmed) - 1);
          nomatch -> Trimmed
        end,
        {true, Stripped}
    end
  end, Lines),
  case StrippedLines of
    [] ->
      <<KindStr/binary, " false.">>;
    [Single] ->
      case binary:match(Single, <<"\"">>) of
        {_Pos, _Len} ->
          <<KindStr/binary, " \"\"\"\\n", Single/binary, "\\n\"\"\".">>;
        nomatch ->
          <<KindStr/binary, " \"", Single/binary, "\".">>
      end;
    Many ->
      Body = iolist_to_binary(lists:join(<<"\\n">>, Many)),
      <<KindStr/binary, " \"\"\"\\n", Body/binary, "\\n\"\"\".">>
  end.

%%--------------------------------------------------------------------
%% @doc
%% Format Erlang source code, converting @doc blocks to -doc attributes.
%%
%% Takes source code as a binary string and returns the modified code.
%%
%% This function only performs the conversion if the OTP version is >= 27.
%% For earlier versions, returns the original code unchanged.
%%
%% Options:
%%   - {line_length, N} - Width for line wrapping (default: 80, 0 = no wrapping)
%%   - {keep_separators, boolean()} - Keep %%---- lines (default: false)
%% @end
%%--------------------------------------------------------------------
format_code(Content) ->
  format_code(Content, []).

format_code(Content, Opts) ->
  case is_otp_version_supported() of
    false ->
      Content;
    true ->
      format_code_internal(Content, Opts)
  end.

%%--------------------------------------------------------------------
%% @doc
%% Internal function to actually format code (assumes OTP >= 27).
%%--------------------------------------------------------------------
format_code_internal(Content, Opts) ->
  _LineLength = proplists:get_value(line_length, Opts, ?DEFAULT_LINE_LENGTH),
  KeepSeparators = proplists:get_value(keep_separators, Opts, false),

  Lines = binary:split(Content, <<"\n">>, [global]),

  % Process lines looking for @doc blocks (currently just passes through)
  ProcessedLines = Lines,

  % Second pass: remove any remaining separator lines adjacent to -doc
  FinalLines = case KeepSeparators of
    false -> remove_doc_separators(ProcessedLines);
    true -> ProcessedLines
  end,

  Result = binary:list_to_bin(lists:join(<<"\n">>, FinalLines)),
  erlalign:handle_eol_at_eof(Result, Opts).

%%--------------------------------------------------------------------
%% @doc
%% Process an Erlang file, converting @doc blocks to -doc attributes.
%%
%% Reads the file, applies documentation conversion, and writes the result.
%% Returns 'ok' on success or {error, Reason} on failure.
%%
%% This function only performs the conversion if the OTP version is >= 27.
%% For earlier versions, returns ok without modifying the file.
%%
%% Options:
%%   - {line_length, N} - Width for line wrapping (default: 80, 0 = no wrapping)
%%   - {keep_separators, boolean()} - Keep %%---- lines (default: false)
%%   - {output, FilePath} - Output file path (default: overwrites input file)
%% @end
%%--------------------------------------------------------------------
process_file(InputPath) ->
  process_file(InputPath, []).

process_file(InputPath, Opts) when is_list(InputPath); is_binary(InputPath) ->
  case is_otp_version_supported() of
    false ->
      ok;
    true ->
      process_file_internal(InputPath, Opts)
  end.

%%--------------------------------------------------------------------
%% @doc
%% Internal function to actually process file (assumes OTP >= 27).
%%--------------------------------------------------------------------
process_file_internal(InputPath, Opts) when is_list(InputPath); is_binary(InputPath) ->
  Path = case InputPath of
    _ when is_list(InputPath) -> unicode:characters_to_binary(InputPath);
    _ when is_binary(InputPath) -> InputPath
  end,
  case file:read_file(Path) of
    {ok, Content} ->
      Formatted = format_code_internal(Content, Opts),
      OutputPath = case proplists:get_value(output, Opts) of
        undefined -> Path;
        Out when is_list(Out) -> unicode:characters_to_binary(Out);
        Out when is_binary(Out) -> Out
      end,
      file:write_file(OutputPath, Formatted);
    {error, Reason} ->
      {error, Reason}
  end.

%%--------------------------------------------------------------------
%% @doc Remove separator lines adjacent to -doc/@doc attributes.
%%--------------------------------------------------------------------
remove_doc_separators(Lines) ->
  Indexed = lists:zip(lists:seq(1, length(Lines)), Lines),
  FilteredIndexed = lists:filter(fun({Idx, Line}) ->
    IsSeparator = is_separator_line(Line),
    case IsSeparator of
      false -> true;  % Keep non-separator lines
      true ->
        % Check adjacent lines for -doc/@doc
        HasPrevDoc = 
          case Idx > 1 of
            true ->
              PrevLine = element(2, lists:nth(Idx - 1, Indexed)),
              PrevTrimmed = trim_line(PrevLine),
              binary:match(PrevTrimmed, <<"-doc">>) =/= nomatch orelse
              binary:match(PrevTrimmed, <<"@doc">>) =/= nomatch;
            false -> false
          end,
        HasNextDoc =
          case Idx < length(Lines) of
            true ->
              NextLine = element(2, lists:nth(Idx + 1, Indexed)),
              NextTrimmed = trim_line(NextLine),
              binary:match(NextTrimmed, <<"-doc">>) =/= nomatch orelse
              binary:match(NextTrimmed, <<"@doc">>) =/= nomatch;
            false -> false
          end,
        not (HasPrevDoc orelse HasNextDoc)
    end
  end, Indexed),
  lists:map(fun({_Idx, Line}) -> Line end, FilteredIndexed).

%%--------------------------------------------------------------------
%% @doc Trim whitespace from both ends of a binary.
%%--------------------------------------------------------------------
trim_binary(B) when is_binary(B) ->
  trim_binary_right(trim_binary_left(B)).

trim_binary_left(<<32, Rest/binary>>) -> trim_binary_left(Rest);  % space
trim_binary_left(<<9, Rest/binary>>) -> trim_binary_left(Rest);   % tab
trim_binary_left(<<13, Rest/binary>>) -> trim_binary_left(Rest);  % carriage return
trim_binary_left(<<10, Rest/binary>>) -> trim_binary_left(Rest);  % newline
trim_binary_left(B) -> B.

trim_binary_right(B) ->
  case byte_size(B) of
    0 -> B;
    Size ->
      LastByte = binary:at(B, Size - 1),
      case LastByte of
        32 -> trim_binary_right(binary:part(B, 0, Size - 1));  % space
        9 -> trim_binary_right(binary:part(B, 0, Size - 1));   % tab
        13 -> trim_binary_right(binary:part(B, 0, Size - 1));  % carriage return
        10 -> trim_binary_right(binary:part(B, 0, Size - 1));  % newline
        _ -> B
      end
  end.

%%--------------------------------------------------------------------
%% @doc Trim leading whitespace from a binary line.
%%--------------------------------------------------------------------
trim_line(Line) ->
  case Line of
    B when is_binary(B) ->
      trim_leading_binary(B);
    L when is_list(L) ->
      trim_leading_string(L);
    _ -> 
      Line
  end.

trim_leading_binary(B) ->
  case B of
    <<32, Rest/binary>> -> trim_leading_binary(Rest);  % space
    <<9, Rest/binary>> -> trim_leading_binary(Rest);   % tab
    <<13, Rest/binary>> -> trim_leading_binary(Rest);  % carriage return
    <<10, Rest/binary>> -> trim_leading_binary(Rest);  % newline
    _ -> B
  end.

trim_leading_string(L) ->
  string:trim(L, leading).

%%--------------------------------------------------------------------
%% @doc Check if a line is a separator line (%%%%----).
%%--------------------------------------------------------------------
is_separator_line(Line) ->
  Trimmed = trim_line(Line),
  case re:run(Trimmed, <<"^%+\\-+%*$">>) of
    {match, _} -> true;
    nomatch -> false
  end.

%%--------------------------------------------------------------------
%% Helper Functions
%%--------------------------------------------------------------------

%%--------------------------------------------------------------------
%% @doc Get the current OTP version.
%%--------------------------------------------------------------------
otp_version() ->
  case erlang:system_info(otp_release) of
    Release when is_list(Release) ->
      try
        list_to_integer(Release)
      catch
        error:_ -> 0
      end;
    _ ->
      0
  end.

%%--------------------------------------------------------------------
%% @doc Check if the current OTP version supports documentation conversion.
%% Returns true if OTP version >= 27, false otherwise.
%%--------------------------------------------------------------------
is_otp_version_supported() ->
  otp_version() >= ?MINIMUM_OTP_VERSION.

collect_block_lines(Lines, Idx, Prefix, TextLines, SeeRefs, Meta) ->
  PLen = byte_size(Prefix),
  case Idx > length(Lines) of
    true ->
      {lists:reverse(TextLines), lists:reverse(SeeRefs), Meta, Idx};
    false ->
      Line = case lists:nth(Idx, Lines, <<>>) of
        L when is_binary(L) -> L;
        L -> binary:list_to_bin(L)
      end,
      SeePat = <<Prefix/binary, "@see ">>,
      AuthorPat = <<Prefix/binary, "@author">>,
      CopyPat = <<Prefix/binary, "@copyright">>,
      case binary:match(Line, SeePat) of
        {0, _} ->
          Ref = trim_binary(binary:part(Line, PLen + 5, byte_size(Line) - PLen - 5)),
          collect_block_lines(Lines, Idx + 1, Prefix, TextLines, [Ref | SeeRefs], Meta);
        nomatch ->
          case binary:match(Line, AuthorPat) of
            {0, _} ->
              Author = trim_binary(binary:part(Line, PLen + 7, byte_size(Line) - PLen - 7)),
              NewMeta = Meta#{author => Author},
              collect_block_lines(Lines, Idx + 1, Prefix, TextLines, SeeRefs, NewMeta);
            nomatch ->
              case binary:match(Line, CopyPat) of
                {0, _} ->
                  Copyright = trim_binary(binary:part(Line, PLen + 10, byte_size(Line) - PLen - 10)),
                  NewMeta = Meta#{copyright => Copyright},
                  collect_block_lines(Lines, Idx + 1, Prefix, TextLines, SeeRefs, NewMeta);
                nomatch ->
                  case binary:match(Line, Prefix) of
                    {0, _} ->
                      Text = binary:part(Line, PLen, byte_size(Line) - PLen),
                      collect_block_lines(Lines, Idx + 1, Prefix, [Text | TextLines], SeeRefs, Meta);
                    nomatch ->
                      {lists:reverse(TextLines), lists:reverse(SeeRefs), Meta, Idx}
                  end
              end
          end
      end
  end.

blank(Line) ->
  trim_binary(Line) == <<>>.

lines_dropwhile(_Pred, []) ->
  [];
lines_dropwhile(Pred, [H | T]) ->
  case Pred(H) of
    true -> lines_dropwhile(Pred, T);
    false -> [H | T]
  end.
