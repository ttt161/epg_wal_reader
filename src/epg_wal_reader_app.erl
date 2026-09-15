%%%-------------------------------------------------------------------
%% @doc epg_wal_reader public API
%% @end
%%%-------------------------------------------------------------------

-module(epg_wal_reader_app).

-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    epg_wal_reader_sup:start_link().

stop(_State) ->
    ok.

%% internal functions
