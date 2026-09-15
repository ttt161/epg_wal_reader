# epg_wal_reader

## Logical Replication Protocol

`epg_wal_reader` implements PostgreSQL's logical replication protocol with support for:

- **pgoutput plugin** - Native PostgreSQL logical replication output format
- **Real-time streaming** - Continuous WAL (Write-Ahead Log) data streaming
- **Transaction boundaries** - BEGIN/COMMIT message handling
- **Schema information** - Automatic relation metadata decoding
- **Data type conversion** - Automatic conversion of PostgreSQL types to Erlang terms

### Supported Message Types

- `BEGIN` - Transaction start
- `COMMIT` - Transaction commit
- `INSERT` - Row insertion
- `UPDATE` - Row update (with old/new values)
- `DELETE` - Row deletion
- `RELATION` - Table schema information
- `TYPE` - Custom type information
- `TRUNCATE` - Table truncation

## Data Types Support

The epg_wal_reader supports all major PostgreSQL data types:

### Basic Types
- **Integers**: `int2`, `int4`, `int8`
- **Floating Point**: `float4`, `float8`
- **Text**: `text`, `varchar`, `char`, `bpchar`
- **Binary**: `bytea`
- **Boolean**: `bool`

### Date/Time Types
- **Date**: `date`
- **Time**: `time`, `timetz`
- **Timestamp**: `timestamp`, `timestamptz`
- **Interval**: `interval`

### Advanced Types
- **JSON**: `json`, `jsonb`
- **UUID**: `uuid`
- **Arrays**: All array types (e.g., `int4[]`, `text[]`, `jsonb[][][]`)
- **Network**: `inet`, `cidr`, `macaddr`
- **Geometric**: `point`
- **Range Types**: `int4range`, `int8range`, `tsrange`, `tstzrange`

### Type Decoding Limitations

Some PostgreSQL types are not automatically decoded and are returned as text representation (binary strings):

- **Extended types**: `cidr`, `inet`, `macaddr`, `macaddr8`
- **Geometric types**: `point` - returned as text (e.g., `<<"(1,2)">>`)
- **Range types**: `int4range`, `int8range`, `tsrange`, `tstzrange`, `daterange`
- **Advanced types**: `hstore`, `geometry`, `interval`
- **Custom types**: User-defined types and enums - returned as text

These types can be parsed manually in your application logic if needed.

## Examples

### Complete Replication Example

```erlang
-module(order_sync).
-behaviour(epg_wal_reader).

-export([start/0, handle_replication_data/2, handle_replication_stop/2]).

start() ->
    DbOpts = #{
        host => "production-db.example.com",
        port => 5432,
        database => "ecommerce",
        username => "repl_user",
        password => "secure_password" % or wrapped fun() -> "secure_password" end
    },

    Options = #{slot_type => persistent},

    epg_wal_reader:subscribe(
        {?MODULE, self()},
        DbOpts,
        "order_replication_slot",
        ["order_events", "inventory_changes"],
        Options
    ).

handle_replication_data(_Ref, Changes) ->
    ProcessedChanges = lists:map(fun transform_change/1, Changes),
    send_to_analytics_service(ProcessedChanges),
    update_cache(ProcessedChanges),
    ok.

handle_replication_stop(_Ref, SlotName) ->
    logger:warning("Replication stopped for slot: ~s", [SlotName]),
    % Implement reconnection logic here
    ok.

transform_change({<<"orders">>, insert, OrderData, _}) ->
    #{
        event_type => order_created,
        table => <<"orders">>,
        order_id => maps:get(<<"id">>, OrderData),
        customer_id => maps:get(<<"customer_id">>, OrderData),
        amount => maps:get(<<"total_amount">>, OrderData),
        timestamp => os:timestamp()
    };
transform_change({<<"orders">>, update, OrderData, _OldOrderData}) ->
    #{
        event_type => order_updated,
        table => <<"orders">>,
        order_id => maps:get(<<"id">>, OrderData),
        status => maps:get(<<"status">>, OrderData),
        timestamp => os:timestamp()
    };
transform_change({<<"inventory">>, Operation, Data, _OldData}) ->
    #{
        event_type => inventory_change,
        table => <<"inventory">>,
        operation => Operation,
        data => Data,
        timestamp => os:timestamp()
    };
transform_change({TableName, Operation, Data, _OldData}) ->
    #{
        event_type => generic_change,
        table => TableName,
        operation => Operation,
        data => Data,
        timestamp => os:timestamp()
    }.
```

### Development Setup

```bash
$ git clone https://github.com/ttt161/epg_wal_reader.git
$ cd epg_wal_reader
$ make wdeps-shell # docker compose up
$ rebar3 get-deps
$ rebar3 compile
$ rebar3 ct  # Run tests
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---
