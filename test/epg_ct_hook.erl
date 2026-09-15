-module(epg_ct_hook).

-include_lib("epgsql/include/epgsql.hrl").

-export([init/2, terminate/1, pre_init_per_suite/3]).

-export([db_opts/0]).

init(_Id, State) ->
    _ = start_applications(),
    ok = init_db(),
    State.

pre_init_per_suite(_SuiteName, Config, State) ->
    {Config ++ State, State}.

terminate(_State) ->
    {ok, C} = epgsql:connect(db_opts()),
    {ok, _, _} = epgsql:squery(C, "TRUNCATE TABLE t1"),
    {ok, _, _} = epgsql:squery(C, "TRUNCATE TABLE t2"),
    ok = epgsql:close(C),
    ok.
%%

db_opts() ->
    #{
        host => "postgres",
        port => 5432,
        database => "connector_db",
        username => "connector",
        password => fun() -> "connector" end
    }.

%%

start_applications() ->
    lists:foreach(
        fun(App) ->
            _ = application:load(App),
            lists:foreach(fun({K, V}) -> ok = application:set_env(App, K, V) end, app_env(App)),
            {ok, _} = application:ensure_all_started(App)
        end,
        app_list()
    ).

%

app_list() ->
    %% in order of launch
    [
        epg_wal_reader
    ].

app_env(epg_wal_reader) ->
    [].

%

init_db() ->
    {ok, C} = epgsql:connect(db_opts()),
    {ok, _, _} = epgsql:squery(C, "CREATE TABLE IF NOT EXISTS t1 (
        bool bool,
        int2 int2 PRIMARY KEY,
        int4 int4,
        int8 int8,
        float4 float4,
        float8 float8,
        char char,
        varchar varchar(12),
        text text,
        bytea bytea,
        json json,
        jsonb jsonb,
        date date,
        time time,
        timestamp timestamp,
        timestamptz timestamptz,
        timetz timetz,
        uuid uuid,
        jsonb_array jsonb[][])"
    ),
    {ok, _, _} = epgsql:squery(C, "CREATE TABLE IF NOT EXISTS t2 (
        int2 int2 PRIMARY KEY,
        varchar varchar(12),
        text text,
        bytea bytea,
        jsonb jsonb)"
    ),
    case epgsql:squery(C, "CREATE PUBLICATION \"default/default\" FOR TABLE t1") of
        {ok, _, _} ->
            ok;
        {error, #error{codename = duplicate_object}} ->
            ok
    end,
    case epgsql:squery(C, "CREATE PUBLICATION \"default/persistent\" FOR TABLE t2") of
        {ok, _, _} ->
            ok;
        {error, #error{codename = duplicate_object}} ->
            ok
    end,
    {ok, _, _} = epgsql:squery(C, "ALTER TABLE t1 REPLICA IDENTITY FULL"),
    {ok, _, _} = epgsql:squery(C, "ALTER TABLE t2 REPLICA IDENTITY FULL"),
    ok = epgsql:close(C),
    ok.
