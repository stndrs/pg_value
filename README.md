# pg_value

[![test](https://github.com/stndrs/pg_value/actions/workflows/test.yml/badge.svg)](https://github.com/stndrs/pg_value/actions/workflows/test.yml)
[![Package Version](https://img.shields.io/hexpm/v/pg_value)](https://hex.pm/packages/pg_value)
[![Hex Docs](https://img.shields.io/badge/hex-docs-ffaff3)](https://hexdocs.pm/pg_value/)

PostgreSQL data types, binary encoders, and binary decoders for Gleam.
Designed to be used by PostgreSQL client libraries. Currently used by
[pgl](https://github.com/stndrs/pgl).

## Supported Types

| PostgreSQL Type | Value Variant | Gleam Type |
|---|---|---|
| `boolean` | `Bool` | `Bool` |
| `smallint`, `integer`, `bigint`, `oid` | `Int` | `Int` |
| `real`, `double precision` | `Float` | `Float` |
| `text`, `varchar`, `char`, `name` | `Text` | `String` |
| `bytea` | `Bytea` | `BitArray` |
| `uuid` | `Uuid` | `BitArray` |
| `time` | `Time` | `gleam/time/calendar.TimeOfDay` |
| `date` | `Date` | `gleam/time/calendar.Date` |
| `timestamp` | `Timestamp` | `gleam/time/timestamp.Timestamp` |
| `timestamptz` | `Timestamptz` | `gleam/time/timestamp.Timestamp` + `gleam/time/duration.Duration` || `interval` | `Interval` | `pg_value/interval.Interval` |
| `json`, `jsonb` | `Json` | `gleam/json.Json` |
| `hstore` | `Hstore` | `Dict(String, Option(String))` |
| enum types | `Enum` | `String` |
| arrays | `Array` | `List(Value)` |
| | `Null` | |

## Usage

```gleam
import gleam/json
import gleam/option.{None, Some}
import pg_value

// Construct values
let params = [
  pg_value.int(42),
  pg_value.text("hello"),
  pg_value.bool(True),
  pg_value.null,
  pg_value.json(json.object([#("key", json.string("value"))])),
  pg_value.array([1, 2, 3], of: pg_value.int),
  pg_value.nullable(pg_value.text, Some("present")),
  pg_value.nullable(pg_value.text, None),
]
```

### Encoding

Values are encoded to PostgreSQL's binary wire format using
`TypeInfo` from the database connection:

```gleam
let assert Ok(encoded) = pg_value.encode(pg_value.int(10), int4_type_info)
```

### Decoding

Binary data from PostgreSQL is decoded into `Dynamic` values,
which can then be decoded into typed data using
[`gleam/dynamic/decode`](https://hexdocs.pm/gleam_stdlib/gleam/dynamic/decode.html):

```gleam
let assert Ok(dynamic_value) = pg_value.decode(bits, int4_type_info)
```

Typed decoders are provided for time types and intervals:

- `pg_value.time_decoder()` decodes into `gleam/time/calendar.TimeOfDay`
- `pg_value.date_decoder()` decodes into `gleam/time/calendar.Date`
- `pg_value.timestamp_decoder()` decodes into `gleam/time/timestamp.Timestamp`
- `interval.decoder()` decodes into `pg_value/interval.Interval`

## Notes

### `timestamptz` convention

When encoding a `Timestamptz`, the `Timestamp` is treated as a wall-clock time
in the given zone and the offset is subtracted to produce the UTC instant on
the wire. Decoding always yields the UTC instant with no offset, so
`decode(encode(Timestamptz(ts, offset)))` equals `ts` only when `offset` is
zero. If your `Timestamp` is already an absolute UTC instant, pass a zero
offset.

### `timestamp` infinity

Finite timestamps decode to an integer microsecond `Dynamic`, but PostgreSQL's
`infinity`/`-infinity` decode to the strings `"infinity"`/`"-infinity"`. The
provided `timestamp_decoder()` only handles finite values; decode infinity
separately (e.g. with `decode.string`).

## Installation

```sh
gleam add pg_value@3
```

## Development

```sh
gleam test  # Run the tests
```

## Acknowledgements

Much thanks to [`pg_types`](https://github.com/tsloughter/pg_types) for encoding and decoding logic.
