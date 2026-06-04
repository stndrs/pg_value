# Changelog

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
