# Changelog

## 4.0.0

### Added

- `EncodeError` and `DecodeError` types: `encode` and `decode` now return
  structured errors instead of `String`. Includes `encode_error_to_string`
  and `decode_error_to_string` for human-readable messages
- Encoding and decoding support for the object-identifier types
  (`regproc`, `regprocedure`, `regoper`, `regoperator`, `regclass`,
  `regtype`, `xid`, `cid`)
- Encoding and decoding support for `citext`
- `Tid`, `Macaddr`, `Point`, `Line`, `LineSegment`, and `Circle` values with
  encoders and decoders for the `tid`, `macaddr`, `point`, `line`, `lseg`,
  and `circle` types. Decoders return the PostgreSQL text output format as
  a string (e.g. `"(1,2)"` for a point)
- `Path` and `Polygon` values with encoders and decoders for the `path` and
  `polygon` types, following the same string-decoding convention

### Changed

- **Breaking:** `encode` returns `Result(BitArray, EncodeError)` instead of
  `Result(_, String)`
- **Breaking:** `decode` returns `Result(Dynamic, DecodeError)` instead of
  `Result(_, String)`

## 3.1.0

### Added

- `bpchar` support in text encode and decode paths

### Changed

- `uuid` `to_string` output is now single-quoted
- Empty arrays now encode as `'{}'` instead of `ARRAY[]`
- `time_to_string` now emits microsecond precision
- Type mismatch error message now reads `Type mismatch: expected X, got Y`

### Fixed

- `to_iso8601_string` printed two signs for negative intervals
- `decode_time` crashed on `24:00:00`
- `encode_date` crashed on invalid dates. The function now returns `Error`
- `uuid_to_string` truncated UUIDs that are not 128 bits. The function now rejects them
- Years are zero-padded to 4 digits in `date_to_string`
- Hstores with trailing bytes after the declared count are now rejected

## 3.0.1

- Updated `gleam_stdlib`

## 3.0.0

### Added

- `Enum` value type with encoder and decoder
- `Json` value type with `json` and `jsonb` encoder and decoder
- `gleam_json` dependency (`>= 3.1.0`)

### Changed

- Replaced `Offset` type with `gleam/time/duration.Duration` in `Timestamptz`
  variant — removed `Offset`, `offset()`, and `minutes()` from the public API
- `hstore_to_string` now wraps keys and values in double quotes per
  PostgreSQL's canonical hstore format

### Fixed

- `offset_to_duration` derived sign from hours only, making negative sub-hour
  offsets (e.g., UTC-0:30) unrepresentable
- `hstore_to_string` was missing required double-quote wrapping around keys
  and values
- `decode_float4` and `decode_float8` silently rounded decoded values (4 and 8
  decimal places respectively) instead of preserving full wire precision
- `text_to_string` used backslash-escaped single quotes (`\'`) instead of
  SQL-standard doubled quotes (`''`)
- Fixed incorrect epoch comments ("Dec 31, 1999" → "Jan 1, 2000")

## 2.0.0

### Added

- `Uuid` value type with encoder
- UUID decoder
- `Hstore` value type with encoder
- Hstore decoder
- Decoders for `gleam/time/timestamp.Timestamp`, `gleam/time/calendar.TimeOfDay`,
  `gleam/time/calendar.Date`

## 1.0.0

### Added

- Initial release
- Supported types: `Null`, `Bool`, `Int`, `Float`, `Text`, `Bytea`, `Time`,
  `Date`, `Timestamp`, `Timestamptz`, `Interval`, `Array`
- Binary encoding and decoding for PostgreSQL wire format
- `to_string` for SQL literal formatting
