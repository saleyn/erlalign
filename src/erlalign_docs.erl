%%%-------------------------------------------------------------------
%%% @doc
%%% EDoc to OTP-27 documentation attribute converter for Erlang.
%%%
%%% Converts EDoc-style @doc comments and type documentation to OTP-27
%%% compatible -doc attributes. Handles HTML markup conversion to Markdown,
%%% cross-references, and proper attribute formatting.
%%%
%%% Options supported:
%%%
%%% For format_code/2:
%%%   - line_length: N - Width for line wrapping (default: 80, 0 = no wrapping)
%%%   - keep_separators: boolean() - Keep separator lines (default: false)
%%%
%%% For process_file/2:
%%%   - line_length: N - Width for line wrapping (default: 80, 0 = no wrapping)
%%%   - keep_separators: boolean() - Keep separator lines (default: false)
%%%   - output: FilePath - Output file path (default: overwrites input file)
%%%
%%% @end
%%%-------------------------------------------------------------------
-module(erlalign_docs).

-export([
  process_file/2,
  process_file/1,
  format_code/2,
  format_code/1,
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
  Text = lists:join(<<"\n">>, TextLines),
  Text2 = re:replace(Text, "`([^'`\n]+)'", "`\\1`", [global, {return, binary}]),
  binary:split(Text2, <<"\n">>, [global]).

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
        case re:run(Line, <<"^\\s*<\\w">>) of
          {match, _} ->
            {[Line | Acc], InFence};
          nomatch ->
            case re:run(Line, <<"^([-*]|\\d+\\.)\\s">>) of
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
  StrippedLines = lists:map(fun(Line) ->
    Trimmed = trim_binary(Line),
    case byte_size(Trimmed) of
      0 -> <<>>;
      _ ->
        case binary:match(Trimmed, <<".">>, [{scope, {byte_size(Trimmed) - 1, 1}}]) of
          {_Pos, _Len} -> binary:part(Trimmed, 0, byte_size(Trimmed) - 1);
          nomatch -> Trimmed
        end
    end
  end, Lines),
  case StrippedLines of
    [] ->
      <<KindStr/binary, " false.">>;
    [Single] ->
      case binary:match(Single, <<"\"">>) of
        {_Pos, _Len} ->
          <<KindStr/binary, " \"\"\"\n", Single/binary, "\n\"\"\".">>;
        nomatch ->
          <<KindStr/binary, " \"", Single/binary, "\".">>
      end;
    Many ->
      Body = iolist_to_binary(lists:join(<<"\n">>, Many)),
      <<KindStr/binary, " \"\"\"\n", Body/binary, "\n\"\"\".">>
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
  %% First, convert @doc blocks to -doc attributes
  Converted = convert_doc_blocks(Content, Opts),
  
  %% Then apply column alignment formatting from erlalign
  Formatted = erlalign:format(Converted, Opts),
  
  %% Remove separator lines unless explicitly kept
  KeepSeparators = proplists:get_value(keep_separators, Opts, false),
  case KeepSeparators of
    true ->
      Formatted;
    false ->
      %% Split into lines, remove separators, rejoin
      Lines1 = binary:split(Formatted, <<"\n">>, [global]),
      
      %% First pass: check if we should remove doc separators
      RemoveDocSeparators = proplists:get_value(remove_doc_separators, Opts, false),
      FilteredLines1 = case RemoveDocSeparators of
        true ->
          remove_doc_separators(Lines1);
        false ->
          %% Just remove normal separator lines
          lists:filtermap(fun(Line) ->
            Trimmed = trim_binary(Line),
            case binary:match(Trimmed, <<"%%----">>) of
              nomatch -> {true, Line};
              _ -> false
            end
          end, Lines1)
      end,
      iolist_to_binary(lists:join(<<"\n">>, FilteredLines1))
  end.

%%--------------------------------------------------------------------
%% @doc
%% Convert all @doc blocks in content to -doc attributes.
%%--------------------------------------------------------------------
convert_doc_blocks(Content, Opts) ->
  ContentBinary = case is_binary(Content) of
    true -> Content;
    false -> iolist_to_binary(Content)
  end,
  Lines = binary:split(ContentBinary, <<"\n">>, [global]),
  Width = proplists:get_value(line_length, Opts, ?DEFAULT_LINE_LENGTH),
  KeepSeparators = proplists:get_value(keep_separators, Opts, false),
  ProcessedLines = process_doc_lines(Lines, Width, KeepSeparators, []),
  ReversedLines = lists:reverse(ProcessedLines),
  FinalLines = handle_moduledoc_placement(ReversedLines),
  iolist_to_binary(lists:join(<<"\n">>, FinalLines)).

%%--------------------------------------------------------------------
%% @doc
%% Handle conversion of -doc to -moduledoc when it appears before -module.
%%--------------------------------------------------------------------
handle_moduledoc_placement(Lines) ->
  find_and_move_moduledoc(Lines, []).

find_and_move_moduledoc([], Acc) ->
  lists:reverse(Acc);
find_and_move_moduledoc([Line | Rest], Acc) ->
  Trimmed = trim_binary(Line),
  case {is_doc_attr(Trimmed), find_module_in_rest(Rest)} of
    {true, {found, ModuleIdx, ModuleLine}} ->
      ModuledocLine = convert_doc_to_moduledoc(Line),
      {BeforeModule, [_|AfterModule]} = lists:split(ModuleIdx, Rest),
      AllLines = lists:reverse(Acc) ++ lists:reverse(BeforeModule) ++ [ModuleLine, ModuledocLine] ++ AfterModule,
      find_and_move_moduledoc(AllLines, []);
    _ ->
      find_and_move_moduledoc(Rest, [Line | Acc])
  end.

is_doc_attr(Trimmed) ->
  case binary:match(Trimmed, <<"-doc ">>) of
    {0, _} -> true;
    _ -> false
  end.

find_module_in_rest(Lines) ->
  find_module_in_rest_helper(Lines, 0).

find_module_in_rest_helper([], _) ->
  false;
find_module_in_rest_helper([Line | Rest], Idx) ->
  Trimmed = trim_binary(Line),
  case binary:match(Trimmed, <<"-module">>) of
    {0, _} -> {found, Idx, Line};
    _ -> find_module_in_rest_helper(Rest, Idx + 1)
  end.

convert_doc_to_moduledoc(DocLine) ->
  case binary:match(DocLine, <<"-doc">>) of
    {Pos, _} ->
      Prefix = binary:part(DocLine, 0, Pos),
      Suffix = binary:part(DocLine, Pos + 4, byte_size(DocLine) - Pos - 4),
      <<Prefix/binary, "-moduledoc", Suffix/binary>>;
    nomatch ->
      DocLine
  end.

%%--------------------------------------------------------------------
%% @doc
%% Check if a line is a comment line (starts with %).
%%--------------------------------------------------------------------
is_comment_line(Line) ->
  StrippedLine = string:trim(Line, leading),
  case byte_size(StrippedLine) of
    0 -> false;
    _ -> binary:at(StrippedLine, 0) == $%
  end.

%%--------------------------------------------------------------------
%% @doc
%% Process lines to find and convert @doc blocks.
%%--------------------------------------------------------------------
process_doc_lines([], _Width, _KeepSeparators, Acc) ->
  Acc;
process_doc_lines([Line | Rest], Width, KeepSeparators, Acc) ->
  Trimmed = trim_binary(Line),
  % Check if this line has @doc AND is a comment line
  case binary:match(Trimmed, <<"@doc">>) of
    nomatch ->
      % Not a @doc line, check if it's a separator
      case is_separator_line(Trimmed) of
        true when not KeepSeparators ->
          % Skip separator unless keep_separators is true
          process_doc_lines(Rest, Width, KeepSeparators, Acc);
        _ ->
          % Keep the line
          process_doc_lines(Rest, Width, KeepSeparators, [Line | Acc])
      end;
    _ ->
      % Found @doc pattern, verify it's actually in a comment (Bug #4 fix)
      case is_comment_line(Line) of
        false ->
          % @doc is in a string literal or other non-comment context, keep the line
          process_doc_lines(Rest, Width, KeepSeparators, [Line | Acc]);
        true ->
          % Found @doc in a comment, extract the full block
          {TextLines, SeeRefs, RemainingLines} = extract_doc_block([Line | Rest]),
          % Convert to -doc attribute
          DocAttr = convert_doc_block(TextLines, SeeRefs, [{line_length, Width}]),
          % Add to accumulator
          AccWithDoc = [DocAttr | Acc],
          % Skip any separator after @end if not keeping separators, but don't add blank line
          % unless the next non-separator line is not a function/clause start (Bug #2 fix)
          {RemainingLines2, AddBlank} = case KeepSeparators of
            true -> {RemainingLines, false};
            false -> 
              {Rest2, WasSeparator} = skip_separator_after_end_with_blank(RemainingLines),
              % Only add blank if we removed a separator AND next line is not code
              {Rest2, WasSeparator andalso should_add_blank_after_doc(Rest2)}
          end,
          % Add blank line if needed
          AccWithDoc2 = case AddBlank of
            true -> [<<>> | AccWithDoc];
            false -> AccWithDoc
          end,
          process_doc_lines(RemainingLines2, Width, KeepSeparators, AccWithDoc2)
      end
  end.

%%--------------------------------------------------------------------
%% @doc
%% Check if a blank line should be added after a -doc block.
%% Never add blank lines - let the code flow naturally.
%%--------------------------------------------------------------------
should_add_blank_after_doc(_) ->
  false.


%%--------------------------------------------------------------------
%% @doc
%% Extract a complete @doc block, including text and @see references.
%% Returns {TextLines, SeeRefs, RemainingLines}.
%%--------------------------------------------------------------------
extract_doc_block([FirstLine | Rest]) ->
  Trimmed = trim_binary(FirstLine),
  % Determine the prefix pattern (e.g., "%% ", "%%% ")
  Prefix = find_doc_prefix(Trimmed),
  % Extract initial text from @doc line if present
  InitialText = case binary:match(Trimmed, <<"@doc">>) of
    {Pos, Len} ->
      StartPos = Pos + Len,
      case byte_size(Trimmed) > StartPos of
        true ->
          Text = binary:part(Trimmed, StartPos, byte_size(Trimmed) - StartPos),
          TrimmedText = trim_binary(Text),
          case byte_size(TrimmedText) > 0 of
            true -> [TrimmedText];
            false -> []
          end;
        false -> []
      end;
    nomatch -> []
  end,
  % Collect remaining doc text lines and @see references
  {RestText, SeeRefs, RemainingLines} = collect_doc_lines(Rest, Prefix, [], []),
  TextLines = InitialText ++ RestText,
  {TextLines, SeeRefs, RemainingLines};
extract_doc_block([]) ->
  {[], [], []}.

find_doc_prefix(Trimmed) ->
  case Trimmed of
    <<"%", "%", "%", _/binary>> -> <<"%%% ">>;
    <<"%", "%", _/binary>> -> <<"%% ">>;
    _ -> <<"%% ">>
  end.

%%--------------------------------------------------------------------
%% @doc
%% Collect lines until @end marker.
%%--------------------------------------------------------------------
collect_doc_lines([], _Prefix, TextAcc, SeeAcc) ->
  {lists:reverse(TextAcc), lists:reverse(SeeAcc), []};
collect_doc_lines([Line | Rest], Prefix, TextAcc, SeeAcc) ->
  Trimmed = trim_binary(Line),
  % Check if this line is the @end marker
  case binary:match(Trimmed, <<"@end">>) of
    nomatch ->
      % Check if this line has @see reference
      case binary:match(Trimmed, <<"@see">>) of
        nomatch ->
          % Check if line continues the doc block
          PrefixLen = byte_size(Prefix),
          case byte_size(Trimmed) >= PrefixLen andalso
               binary:part(Trimmed, 0, PrefixLen) == Prefix of
            true ->
              % Extract text after prefix
              TextPart = binary:part(Trimmed, PrefixLen, byte_size(Trimmed) - PrefixLen),
              collect_doc_lines(Rest, Prefix, [TextPart | TextAcc], SeeAcc);
            false ->
              % Not a continuation, check if it's just the comment marker
              case Trimmed of
                <<"%%%">> -> collect_doc_lines(Rest, Prefix, [<<>> | TextAcc], SeeAcc);
                <<"%%">> -> collect_doc_lines(Rest, Prefix, [<<>> | TextAcc], SeeAcc);
                _ ->
                  % End of block
                  {lists:reverse(TextAcc), lists:reverse(SeeAcc), [Line | Rest]}
              end
          end;
        _ ->
          % Extract @see reference
          SeeRef = extract_see_ref(Trimmed),
          collect_doc_lines(Rest, Prefix, TextAcc, [SeeRef | SeeAcc])
      end;
    _ ->
      % Found @end, return collected data
      {lists:reverse(TextAcc), lists:reverse(SeeAcc), Rest}
  end.

%%--------------------------------------------------------------------
%% @doc
%% Extract the reference from a @see line.
%%--------------------------------------------------------------------
extract_see_ref(Line) ->
  case binary:match(Line, <<"@see">>) of
    {Pos, Len} ->
      StartPos = Pos + Len,
      Ref = binary:part(Line, StartPos, byte_size(Line) - StartPos),
      Trimmed = trim_binary(Ref),
      case is_binary(Trimmed) of
        true -> binary:bin_to_list(Trimmed);
        false -> Trimmed
      end;
    nomatch ->
      ""
  end.

%%--------------------------------------------------------------------
%% @doc
%% Skip a trailing separator line after @end.
%%--------------------------------------------------------------------
skip_separator_after_end([Line | Rest]) ->
  case is_separator_line(trim_binary(Line)) of
    true -> Rest;
    false -> [Line | Rest]
  end;
skip_separator_after_end([]) ->
  [].

%%--------------------------------------------------------------------
%% @doc
%% Skip a trailing separator line after @end, returning whether blank was added.
%%--------------------------------------------------------------------
skip_separator_after_end_with_blank([Line | Rest]) ->
  case is_separator_line(trim_binary(Line)) of
    true -> {Rest, true};
    false -> {[Line | Rest], false}
  end;
skip_separator_after_end_with_blank([]) ->
  {[], false}.

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
%% @doc Trim leading whitespace from a binary.
%%--------------------------------------------------------------------
trim_leading_binary(B) ->
  case B of
    <<32, Rest/binary>> -> trim_leading_binary(Rest);  % space
    <<9, Rest/binary>> -> trim_leading_binary(Rest);   % tab
    <<13, Rest/binary>> -> trim_leading_binary(Rest);  % carriage return
    <<10, Rest/binary>> -> trim_leading_binary(Rest);  % newline
    _ -> B
  end.

%%--------------------------------------------------------------------
%% @doc Trim leading whitespace from a line (binary or list).
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

%%--------------------------------------------------------------------
%% @doc Trim leading whitespace from a string.
%%--------------------------------------------------------------------
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
