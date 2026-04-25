%%%-------------------------------------------------------------------
%%% @doc
%%% Escript entry point for erlalign formatter.
%%% This module serves as the main entry point when erlalign is run as an escript.
%%% @end
%%%-------------------------------------------------------------------

-module(erlalign_escript).

-export([main/1]).

%%--------------------------------------------------------------------
%% @doc
%% Escript entry point. Called when erlalign is executed as an escript.
%% @end
%%--------------------------------------------------------------------
main(Args) ->
  erlalign:main(Args).
