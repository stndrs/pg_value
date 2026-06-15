//// PostgreSQL values, along with their encoders and decoders. Can
//// be used by PostgreSQL client libraries written in gleam.
//// Currently used by [pgl][1].
////
//// [1]: https://github.com/stndrs/pgl

import gleam/bit_array
import gleam/bool
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/dynamic/decode
import gleam/float
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/time/calendar
import gleam/time/duration
import gleam/time/timestamp
import pg_value/interval
import pg_value/type_info

/// The `Value` type represents PostgreSQL data types. Values can be encoded
/// to PostgreSQL's binary format. `Value`s can be used when interacting with
/// PostgreSQL databases through client libraries like [pgl][1].
///
/// [1]: https://github.com/stndrs/pgl
pub type Value {
  Null
  Bool(Bool)
  Int(Int)
  Float(Float)
  Text(String)
  Bytea(BitArray)
  Time(calendar.TimeOfDay)
  Date(calendar.Date)
  Timestamp(timestamp.Timestamp)
  Timestamptz(timestamp.Timestamp, duration.Duration)
  Interval(interval.Interval)
  Array(List(Value))
  Uuid(BitArray)
  Hstore(Dict(String, Option(String)))
  Enum(String)
  Json(json.Json)
}

pub const null = Null

pub const true = Bool(True)

pub const false = Bool(False)

/// Returns a Bool value.
pub fn bool(bool: Bool) -> Value {
  Bool(bool)
}

/// Returns an Int value.
pub fn int(int: Int) -> Value {
  Int(int)
}

/// Returns a Float value.
pub fn float(float: Float) -> Value {
  Float(float)
}

/// Returns a Text value.
pub fn text(text: String) -> Value {
  Text(text)
}

/// Returns a Bytea value.
pub fn bytea(bytea: BitArray) -> Value {
  Bytea(bytea)
}

/// Returns a UUID `Value`. Callers are responsible for ensuring the provided
/// value is a valid UUID. If the value is not a valid UUID, encoding will fail.
pub fn uuid(uuid: BitArray) -> Value {
  Uuid(uuid)
}

/// Returns an Hstore value. Keys map to optional string values.
pub fn hstore(hstore: Dict(String, Option(String))) -> Value {
  Hstore(hstore)
}

/// Returns a Time value.
pub fn time(time_of_day: calendar.TimeOfDay) -> Value {
  Time(time_of_day)
}

/// Returns a Date value.
pub fn date(date: calendar.Date) -> Value {
  Date(date)
}

/// Returns a Timestamp value.
pub fn timestamp(timestamp: timestamp.Timestamp) -> Value {
  Timestamp(timestamp)
}

/// Returns a Timestamptz value with a timezone offset.
///
/// Note on convention: `encode` treats the `Timestamp` as a wall-clock time in
/// the zone described by `offset` and subtracts the offset to produce the UTC
/// instant on the wire. Decoding always yields the UTC instant with no offset.
/// Consequently `decode(encode(Timestamptz(ts, off)))` equals `ts` only when
/// `off` is zero. If your `Timestamp` is already an absolute UTC instant, pass
/// `duration.seconds(0)` as the offset.
pub fn timestamptz(
  timestamp: timestamp.Timestamp,
  offset: duration.Duration,
) -> Value {
  Timestamptz(timestamp, offset)
}

/// Returns an Interval value.
pub fn interval(interval: interval.Interval) -> Value {
  Interval(interval)
}

/// Returns an Enum value with the given label.
pub fn enum(label: String) -> Value {
  Enum(label)
}

/// Returns a Json value.
pub fn json(json: json.Json) -> Value {
  Json(json)
}

/// Returns an Array value. Each element is converted using the provided function.
pub fn array(elements: List(a), of kind: fn(a) -> Value) -> Value {
  elements
  |> list.map(kind)
  |> Array
}

/// Checks if the provided value is `option.Some` or `option.None`. If
/// `None` then the value returned is `value.Null`. If `Some` value is
/// provided then it is passed to the `inner_type` function.
///
/// Example:
///
/// ```gleam
///   let int = pg_value.nullable(pg_value.int, Some(10))
///
///   let null = pg_value.nullable(pg_value.int, None)
/// ```
pub fn nullable(inner_type: fn(a) -> Value, optional: Option(a)) -> Value {
  case optional {
    Some(term) -> inner_type(term)
    None -> Null
  }
}

/// Converts a `Value` to a string formatted properly for PostgreSQL
///
/// Intended for building SQL literals for debugging and logging. String
/// escaping is only safe when the server has `standard_conforming_strings = on`
/// (the default since PostgreSQL 9.1); with it off, backslash handling can
/// un-terminate the literal and enable injection. For untrusted data, prefer
/// parameterized queries with the binary `encode` path rather than
/// interpolating `to_string` output.
pub fn to_string(value: Value) -> String {
  case value {
    Null -> "NULL"
    Bool(val) -> bool_to_string(val)
    Int(val) -> int.to_string(val)
    Float(val) -> float.to_string(val)
    Text(val) -> text_to_string(val)
    Bytea(val) -> bytea_to_string(val)
    Time(val) -> time_to_string(val)
    Date(val) -> date_to_string(val)
    Timestamp(val) -> timestamp_to_string(val)
    Timestamptz(ts, offset) -> timestamptz_to_string(ts, offset)
    Interval(val) -> interval.to_iso8601_string(val) |> single_quote
    Array(vals) -> array_to_string(vals)
    Uuid(val) -> uuid_to_string(val) |> single_quote
    Hstore(val) -> hstore_to_string(val)
    Enum(val) -> string.replace(in: val, each: "'", with: "''") |> single_quote
    Json(val) ->
      json.to_string(val)
      |> string.replace(each: "'", with: "''")
      |> single_quote
  }
}

fn hstore_to_string(hstore: Dict(String, Option(String))) -> String {
  hstore
  |> dict.to_list
  |> list.map(with: fn(key_val) {
    let #(key, val) = key_val
    let key = "\"" <> escape(key) <> "\""

    let val = case val {
      Some(val) -> "\"" <> escape(val) <> "\""
      None -> "NULL"
    }

    key <> "=>" <> val
  })
  |> string.join(", ")
  |> single_quote
}

fn escape(str: String) -> String {
  str
  |> string.replace(each: "\\", with: "\\\\")
  |> string.replace(each: "\"", with: "\\\"")
  |> string.replace(each: "'", with: "''")
}

fn uuid_to_string(uuid: BitArray) -> String {
  // A UUID is exactly 128 bits. Reject other sizes rather than silently
  // truncating to a shorter, invalid literal.
  case uuid {
    <<_:big-int-size(128)>> -> do_uuid_to_string(uuid, 0, "", "-")
    _ -> ""
  }
}

fn do_uuid_to_string(
  uuid: BitArray,
  position: Int,
  acc: String,
  separator: String,
) -> String {
  case position {
    8 | 13 | 18 | 23 ->
      do_uuid_to_string(uuid, position + 1, acc <> separator, separator)
    _ ->
      case uuid {
        <<i:size(4), rest:bits>> -> {
          let string = int.to_base16(i) |> string.lowercase
          do_uuid_to_string(rest, position + 1, acc <> string, separator)
        }
        _ -> acc
      }
  }
}

fn text_to_string(text: String) -> String {
  let val = string.replace(in: text, each: "'", with: "''")

  single_quote(val)
}

// https://www.postgresql.org/docs/current/arrays.html#ARRAYS-INPUT
fn array_to_string(array: List(Value)) -> String {
  case array {
    // PostgreSQL rejects a bare `ARRAY[]` without a type cast, so emit the
    // typeless empty-array literal instead.
    [] -> "'{}'"
    [val] -> "ARRAY[" <> to_string(val) <> "]"
    vals -> {
      let elems =
        vals
        |> list.map(to_string)
        |> string.join(", ")

      "ARRAY[" <> elems <> "]"
    }
  }
}

// https://www.postgresql.org/docs/current/datatype-boolean.html#DATATYPE-BOOLEAN
fn bool_to_string(bool: Bool) -> String {
  case bool {
    True -> "TRUE"
    False -> "FALSE"
  }
}

// https://www.postgresql.org/docs/current/datatype-binary.html#DATATYPE-BINARY-BYTEA-HEX-FORMAT
fn bytea_to_string(bytea: BitArray) -> String {
  let val = "\\x" <> bit_array.base16_encode(bytea)

  single_quote(val)
}

fn date_to_string(date: calendar.Date) -> String {
  let year = pad(date.year, 4)
  let month = calendar.month_to_int(date.month) |> pad_zero
  let day = pad_zero(date.day)

  let date = year <> "-" <> month <> "-" <> day

  single_quote(date)
}

fn time_to_string(time_of_day: calendar.TimeOfDay) -> String {
  let hours = pad_zero(time_of_day.hours)
  let minutes = pad_zero(time_of_day.minutes)
  let seconds = pad_zero(time_of_day.seconds)
  let microseconds = time_of_day.nanoseconds / 1000

  let fractional = case microseconds {
    0 -> ""
    _ -> {
      // Pad to 6 digits then trim trailing zeros for microsecond precision.
      let digits = pad(microseconds, 6)
      "." <> trim_trailing_zeros(digits)
    }
  }

  let time = hours <> ":" <> minutes <> ":" <> seconds <> fractional

  single_quote(time)
}

fn trim_trailing_zeros(str: String) -> String {
  case string.ends_with(str, "0") {
    True -> trim_trailing_zeros(string.drop_end(str, 1))
    False -> str
  }
}

fn timestamp_to_string(timestamp: timestamp.Timestamp) -> String {
  timestamp.to_rfc3339(timestamp, calendar.utc_offset)
  |> single_quote
}

fn timestamptz_to_string(
  timestamp: timestamp.Timestamp,
  offset: duration.Duration,
) -> String {
  negate_duration(offset)
  |> timestamp.add(timestamp, _)
  |> timestamp_to_string
}

fn negate_duration(d: duration.Duration) -> duration.Duration {
  duration.difference(d, duration.seconds(0))
}

fn single_quote(value: String) -> String {
  "'" <> value <> "'"
}

fn pad_zero(n: Int) -> String {
  case n < 10 {
    True -> "0" <> int.to_string(n)
    False -> int.to_string(n)
  }
}

// Left-pads a non-negative integer with zeros to at least `width` digits.
fn pad(n: Int, width: Int) -> String {
  let str = int.to_string(n)
  let len = string.length(str)

  case len < width {
    True -> string.repeat("0", width - len) <> str
    False -> str
  }
}

/// Returns a decoder for `TimeOfDay` values.
pub fn time_decoder() -> decode.Decoder(calendar.TimeOfDay) {
  use hours <- decode.field(0, decode.int)
  use minutes <- decode.field(1, decode.int)
  use seconds <- decode.field(2, decode.int)
  use microseconds <- decode.field(3, decode.int)

  let nanoseconds = microseconds * 1000

  calendar.TimeOfDay(hours:, minutes:, seconds:, nanoseconds:)
  |> decode.success
}

/// Returns a decoder for `Timestamp` values.
///
/// This decoder expects the finite, integer-microsecond representation produced
/// by `decode` for `timestamp`/`timestamptz`. PostgreSQL's `infinity` and
/// `-infinity` decode to the strings `"infinity"`/`"-infinity"` instead, which
/// this decoder does not handle; decode those cases separately (for example
/// with `decode.string`).
pub fn timestamp_decoder() -> decode.Decoder(timestamp.Timestamp) {
  use microseconds <- decode.map(decode.int)
  let seconds = microseconds / 1_000_000
  let nanoseconds = { microseconds % 1_000_000 } * 1000
  timestamp.from_unix_seconds_and_nanoseconds(seconds, nanoseconds)
}

/// Returns a decoder for `Date` values.
pub fn date_decoder() -> decode.Decoder(calendar.Date) {
  use year <- decode.field(0, decode.int)
  use month <- decode.field(1, decode.int)
  use day <- decode.field(2, decode.int)

  case calendar.month_from_int(month) {
    Ok(month) -> calendar.Date(year:, month:, day:) |> decode.success
    _ ->
      calendar.Date(0, calendar.January, 1)
      |> decode.failure("Date")
  }
}

// ---------- Encoding ---------- //

/// Encodes a Value as a PostgreSQL data type
pub fn encode(
  value: Value,
  info: type_info.TypeInfo,
) -> Result(BitArray, String) {
  case value {
    Null -> encode_null()
    Bool(val) -> encode_bool(val, info)
    Int(val) -> encode_int(val, info)
    Float(val) -> encode_float(val, info)
    Text(val) -> encode_text(val, info)
    Bytea(val) -> encode_bytea(val, info)
    Time(val) -> encode_time(val, info)
    Date(val) -> encode_date(val, info)
    Timestamp(val) -> encode_timestamp(val, info)
    Timestamptz(ts, offset) -> encode_timestamptz(ts, offset, info)
    Interval(val) -> encode_interval(val, info)
    Array(val) -> encode_array(val, info)
    Uuid(val) -> encode_uuid(val, info)
    Hstore(val) -> encode_hstore(val, info)
    Enum(val) -> encode_enum(val, info)
    Json(val) -> encode_json(val, info)
  }
}

fn validate_typesend(
  expected: String,
  info: type_info.TypeInfo,
  next: fn() -> Result(t, String),
) -> Result(t, String) {
  use <- bool.lazy_guard(when: expected == info.typesend, return: next)

  Error("Attempted to encode " <> expected <> " as " <> info.typesend)
}

fn encode_uuid(
  uuid: BitArray,
  info: type_info.TypeInfo,
) -> Result(BitArray, String) {
  use <- validate_typesend("uuid_send", info)

  case uuid {
    <<uuid:big-int-size(128)>> ->
      Ok(<<16:big-int-size(32), uuid:big-int-size(128)>>)
    _ -> Error("Invalid UUID")
  }
}

fn encode_hstore(
  hstore: Dict(String, Option(String)),
  info: type_info.TypeInfo,
) -> Result(BitArray, String) {
  use <- validate_typesend("hstore_send", info)

  use encoded <- result.map(do_encode_hstore(hstore))

  let size = bit_array.byte_size(encoded)

  <<size:big-int-size(32), encoded:bits>>
}

fn do_encode_hstore(
  hstore: Dict(String, Option(String)),
) -> Result(BitArray, String) {
  let encoded =
    hstore
    |> dict.to_list
    |> list.fold(<<>>, fn(acc, key_val) {
      let encoded_key =
        key_val.0
        |> bit_array.from_string

      let key_size = bit_array.byte_size(encoded_key)

      let encoded_value = case key_val.1 {
        Some(val) -> {
          let encoded_val = bit_array.from_string(val)
          let val_size = bit_array.byte_size(encoded_val)

          <<val_size:big-int-size(32), encoded_val:bits>>
        }
        None -> <<-1:big-int-size(32)>>
      }

      acc
      |> bit_array.append(<<key_size:big-int-size(32), encoded_key:bits>>)
      |> bit_array.append(encoded_value)
    })

  let size = dict.size(hstore)

  Ok(<<size:big-int-size(32), encoded:bits>>)
}

fn encode_array(
  elems: List(Value),
  info: type_info.TypeInfo,
) -> Result(BitArray, String) {
  use <- validate_typesend("array_send", info)

  case info.elem_type {
    Some(elem_ti) -> {
      // PostgreSQL's wire format flattens multidimensional arrays: a single
      // header (ndim, flags, scalar element oid), one {len, lower bound} pair
      // per dimension, and the leaf elements laid out flat in row-major order.
      let scalar_ti = scalar_elem_type(elem_ti)

      use dimensions <- result.try(array_dimensions(elems))
      use leaves <- result.try(array_leaves(elems))

      use encoded_elems <- result.try(
        list.try_map(leaves, encode(_, scalar_ti)),
      )

      let has_nulls = list.contains(encoded_elems, <<-1:big-int-size(32)>>)

      do_encode_array(dimensions, has_nulls, scalar_ti, encoded_elems)
    }
    None -> Error("Missing elem type info")
  }
}

// Resolves the scalar (non-array) element TypeInfo by descending through any
// nested array element types. Multidimensional arrays share a single scalar
// element type on the wire.
fn scalar_elem_type(info: type_info.TypeInfo) -> type_info.TypeInfo {
  case info.typesend, info.elem_type {
    "array_send", Some(inner) -> scalar_elem_type(inner)
    _, _ -> info
  }
}

// Determines the dimensions of a (possibly nested) array, validating that it
// is rectangular: every sibling sub-array at a given depth must have the same
// length, and elements at a given depth must all be arrays or all be scalars.
fn array_dimensions(elems: List(Value)) -> Result(List(Int), String) {
  case elems {
    [] -> Ok([])
    [Array(inner), ..rest] -> {
      let dim = list.length(elems)

      use <- bool.guard(
        when: !list.all(rest, is_array),
        return: Error("Array is not rectangular"),
      )

      use inner_dims <- result.try(array_dimensions(inner))

      // Ensure every sibling sub-array shares the same inner dimensions.
      use <- bool.guard(
        when: !list.all(rest, fn(sibling) {
          case sibling {
            Array(other) -> array_dimensions(other) == Ok(inner_dims)
            _ -> False
          }
        }),
        return: Error("Array is not rectangular"),
      )

      Ok([dim, ..inner_dims])
    }
    _ -> {
      use <- bool.guard(
        when: list.any(elems, is_array),
        return: Error("Array is not rectangular"),
      )

      Ok([list.length(elems)])
    }
  }
}

fn is_array(value: Value) -> Bool {
  case value {
    Array(_) -> True
    _ -> False
  }
}

// Flattens a (possibly nested) array into its leaf scalar values in row-major
// order.
fn array_leaves(elems: List(Value)) -> Result(List(Value), String) {
  list.try_fold(elems, [], fn(acc, elem) {
    case elem {
      Array(inner) -> {
        use inner_leaves <- result.map(array_leaves(inner))
        list.append(acc, inner_leaves)
      }
      _ -> Ok(list.append(acc, [elem]))
    }
  })
}

fn do_encode_array(
  dimensions: List(Int),
  has_nulls: Bool,
  info: type_info.TypeInfo,
  encoded: List(BitArray),
) -> Result(BitArray, String) {
  let header = array_header(dimensions, has_nulls, info.oid)

  let encoder = fn(bits) {
    let len = bit_array.byte_size(bits)

    Ok(<<len:big-int-size(32), bits:bits>>)
  }

  case encoded {
    [] -> encoder(header)
    _ -> bit_array.concat([header, ..encoded]) |> encoder
  }
}

fn array_header(
  dimensions: List(Int),
  has_nulls: Bool,
  elem_type_oid: Int,
) -> BitArray {
  let num_dims = list.length(dimensions)

  let flags = case has_nulls {
    True -> 1
    False -> 0
  }

  let encoded_dimensions =
    dimensions
    |> list.map(fn(dim) { <<dim:big-int-size(32), 1:big-int-size(32)>> })
    |> bit_array.concat

  [
    <<num_dims:int-size(32), flags:int-size(32), elem_type_oid:int-size(32)>>,
    encoded_dimensions,
  ]
  |> bit_array.concat
}

fn encode_null() -> Result(BitArray, String) {
  Ok(<<-1:big-int-size(32)>>)
}

fn encode_bool(
  bool: Bool,
  info: type_info.TypeInfo,
) -> Result(BitArray, String) {
  use <- validate_typesend("boolsend", info)

  case bool {
    True -> Ok(<<1:big-int-size(32), 1:big-int-size(8)>>)
    False -> Ok(<<1:big-int-size(32), 0:big-int-size(8)>>)
  }
}

fn encode_oid(num: Int, info: type_info.TypeInfo) -> Result(BitArray, String) {
  use <- validate_typesend("oidsend", info)

  case 0 <= num && num <= oid_max {
    True -> Ok(<<4:big-int-size(32), num:big-int-size(32)>>)
    False -> Error("Out of range for oid")
  }
}

fn encode_int(num: Int, info: type_info.TypeInfo) -> Result(BitArray, String) {
  case info.typesend {
    "oidsend" -> encode_oid(num, info)
    "int2send" -> encode_int2(num, info)
    "int4send" -> encode_int4(num, info)
    "int8send" -> encode_int8(num, info)
    _ -> {
      let message =
        "Attempted to encode " <> int.to_string(num) <> " as " <> info.typesend

      Error(message)
    }
  }
}

fn encode_int2(num: Int, info: type_info.TypeInfo) -> Result(BitArray, String) {
  use <- validate_typesend("int2send", info)

  case int2_min <= num && num <= int2_max {
    True -> Ok(<<2:big-int-size(32), num:big-int-size(16)>>)
    False -> Error("Out of range for int2")
  }
}

fn encode_int4(num: Int, info: type_info.TypeInfo) -> Result(BitArray, String) {
  use <- validate_typesend("int4send", info)

  case int4_min <= num && num <= int4_max {
    True -> Ok(<<4:big-int-size(32), num:big-int-size(32)>>)
    False -> Error("Out of range for int4")
  }
}

fn encode_int8(num: Int, info: type_info.TypeInfo) -> Result(BitArray, String) {
  use <- validate_typesend("int8send", info)

  case int8_min <= num && num <= int8_max {
    True -> Ok(<<8:big-int-size(32), num:big-int-size(64)>>)
    False -> Error("Out of range for int8")
  }
}

fn encode_float(
  num: Float,
  info: type_info.TypeInfo,
) -> Result(BitArray, String) {
  case info.typesend {
    "float4send" -> encode_float4(num, info)
    "float8send" -> encode_float8(num, info)
    _ -> Error("Unsupported float type")
  }
}

fn encode_float4(
  num: Float,
  info: type_info.TypeInfo,
) -> Result(BitArray, String) {
  use <- validate_typesend("float4send", info)

  Ok(<<4:big-int-size(32), num:big-float-size(32)>>)
}

fn encode_float8(
  num: Float,
  info: type_info.TypeInfo,
) -> Result(BitArray, String) {
  use <- validate_typesend("float8send", info)

  Ok(<<8:big-int-size(32), num:big-float-size(64)>>)
}

fn encode_text(
  text: String,
  info: type_info.TypeInfo,
) -> Result(BitArray, String) {
  let encoder = fn(text) {
    let bits = bit_array.from_string(text)
    let len = bit_array.byte_size(bits)

    Ok(<<len:big-int-size(32), bits:bits>>)
  }

  case info.typesend {
    "varcharsend" -> encoder(text)
    "textsend" -> encoder(text)
    "charsend" -> encoder(text)
    "bpcharsend" -> encoder(text)
    "namesend" -> encoder(text)
    _ -> Error("Attempted to encode '" <> text <> "' as " <> info.typesend)
  }
}

fn encode_enum(
  label: String,
  info: type_info.TypeInfo,
) -> Result(BitArray, String) {
  use <- validate_typesend("enum_send", info)

  let bits = bit_array.from_string(label)
  let len = bit_array.byte_size(bits)

  Ok(<<len:big-int-size(32), bits:bits>>)
}

fn encode_json(
  json_val: json.Json,
  info: type_info.TypeInfo,
) -> Result(BitArray, String) {
  let json_string = json.to_string(json_val)
  let json_bits = bit_array.from_string(json_string)

  case info.typesend {
    "json_send" -> {
      let len = bit_array.byte_size(json_bits)
      Ok(<<len:big-int-size(32), json_bits:bits>>)
    }
    "jsonb_send" -> {
      let len = bit_array.byte_size(json_bits) + 1
      Ok(<<len:big-int-size(32), 1:int-size(8), json_bits:bits>>)
    }
    _ -> Error("Attempted to encode json as " <> info.typesend)
  }
}

fn encode_bytea(
  bits: BitArray,
  info: type_info.TypeInfo,
) -> Result(BitArray, String) {
  use <- validate_typesend("byteasend", info)

  let len = bit_array.byte_size(bits)

  Ok(<<len:big-int-size(32), bits:bits>>)
}

fn encode_date(
  date: calendar.Date,
  info: type_info.TypeInfo,
) -> Result(BitArray, String) {
  use <- validate_typesend("date_send", info)

  let month = calendar.month_to_int(date.month)

  // calendar:date_to_gregorian_days/3 raises for invalid dates (Feb 30, day 0,
  // year < 1, etc.), so validate up front to honour the Result contract.
  use <- bool.guard(
    when: !is_valid_date(date.year, month, date.day),
    return: Error("Invalid date"),
  )

  let gregorian_days = date_to_gregorian_days(date.year, month, date.day)
  let pg_days = gregorian_days - postgres_gd_epoch

  Ok(<<4:big-int-size(32), pg_days:big-int-size(32)>>)
}

fn is_valid_date(year: Int, month: Int, day: Int) -> Bool {
  year >= 1
  && month >= 1
  && month <= 12
  && day >= 1
  && day <= days_in_month(year, month)
}

fn days_in_month(year: Int, month: Int) -> Int {
  case month {
    1 | 3 | 5 | 7 | 8 | 10 | 12 -> 31
    4 | 6 | 9 | 11 -> 30
    2 ->
      case is_leap_year(year) {
        True -> 29
        False -> 28
      }
    _ -> 0
  }
}

fn is_leap_year(year: Int) -> Bool {
  { year % 4 == 0 && year % 100 != 0 } || year % 400 == 0
}

fn encode_time(
  time_of_day: calendar.TimeOfDay,
  info: type_info.TypeInfo,
) -> Result(BitArray, String) {
  use <- validate_typesend("time_send", info)

  let usecs =
    duration.hours(time_of_day.hours)
    |> duration.add(duration.minutes(time_of_day.minutes))
    |> duration.add(duration.seconds(time_of_day.seconds))
    |> duration.add(duration.nanoseconds(time_of_day.nanoseconds))
    |> to_microseconds(duration.to_seconds_and_nanoseconds)

  Ok(<<8:big-int-size(32), usecs:big-int-size(64)>>)
}

fn encode_interval(
  interval: interval.Interval,
  info: type_info.TypeInfo,
) -> Result(BitArray, String) {
  use <- validate_typesend("interval_send", info)

  let interval.Interval(months:, days:, seconds:, microseconds:) = interval

  let usecs = { seconds * usecs_per_sec } + microseconds

  let encoded = <<
    16:big-int-size(32),
    usecs:big-int-size(64),
    days:big-int-size(32),
    months:big-int-size(32),
  >>

  Ok(encoded)
}

fn encode_timestamp(
  timestamp: timestamp.Timestamp,
  info: type_info.TypeInfo,
) -> Result(BitArray, String) {
  use <- validate_typesend("timestamp_send", info)

  let timestamp_int =
    unix_seconds_before_postgres_epoch()
    |> timestamp.add(timestamp, _)
    |> to_microseconds(timestamp.to_unix_seconds_and_nanoseconds)

  Ok(<<8:big-int-size(32), timestamp_int:big-int-size(64)>>)
}

fn encode_timestamptz(
  timestamp: timestamp.Timestamp,
  offset: duration.Duration,
  info: type_info.TypeInfo,
) -> Result(BitArray, String) {
  use <- validate_typesend("timestamptz_send", info)

  let negated_offset = negate_duration(offset)

  let timestamp_int =
    unix_seconds_before_postgres_epoch()
    |> duration.add(negated_offset)
    |> timestamp.add(timestamp, _)
    |> to_microseconds(timestamp.to_unix_seconds_and_nanoseconds)

  Ok(<<8:big-int-size(32), timestamp_int:big-int-size(64)>>)
}

// ---------- Decoding ---------- //

/// Decodes binary PostgreSQL data into a Dynamic value. Dynamic values
/// can then be decoded using [gleam/dynamic/decode][1].
///
/// [1]: https://hexdocs.pm/gleam_stdlib/gleam/dynamic/decode.html
pub fn decode(
  bits: BitArray,
  info: type_info.TypeInfo,
) -> Result(Dynamic, String) {
  case info.typereceive {
    "array_recv" ->
      decode_array(bits, with: fn(elem) {
        case info.elem_type {
          Some(elem_ti) -> decode(elem, elem_ti)
          None -> Error("elem type missing")
        }
      })
    "boolrecv" -> decode_bool(bits)
    "oidrecv" -> decode_oid(bits)
    "int2recv" -> decode_int2(bits)
    "int4recv" -> decode_int4(bits)
    "int8recv" -> decode_int8(bits)
    "float4recv" -> decode_float4(bits)
    "float8recv" -> decode_float8(bits)
    "textrecv" -> decode_text(bits)
    "varcharrecv" -> decode_varchar(bits)
    "namerecv" -> decode_text(bits)
    "charrecv" -> decode_text(bits)
    "bpcharrecv" -> decode_text(bits)
    "bytearecv" -> decode_bytea(bits)
    "uuid_recv" -> decode_uuid(bits)
    "hstore_recv" -> decode_hstore(bits)
    "time_recv" -> decode_time(bits)
    "date_recv" -> decode_date(bits)
    "timestamp_recv" -> decode_timestamp(bits)
    "timestamptz_recv" -> decode_timestamp(bits)
    "interval_recv" -> decode_interval(bits)
    "enum_recv" -> decode_enum(bits)
    "json_recv" -> decode_json(bits)
    "jsonb_recv" -> decode_jsonb(bits)
    _ -> Error("Unsupported type")
  }
}

fn decode_array(
  bits: BitArray,
  with decoder: fn(BitArray) -> Result(Dynamic, String),
) -> Result(Dynamic, String) {
  case bits {
    <<
      dimensions:big-signed-int-size(32),
      _flags:big-signed-int-size(32),
      _elem_oid:big-signed-int-size(32),
      rest:bits,
    >> -> {
      use data <- result.try(do_decode_array(dimensions, rest, []))

      decode_array_elems(data.0, decoder, [])
      |> result.map(dynamic.array)
    }
    _ -> Error("invalid array")
  }
}

fn do_decode_array(
  count: Int,
  bits: BitArray,
  acc: List(#(Int, Int)),
) -> Result(#(BitArray, List(#(Int, Int))), String) {
  case count {
    0 -> Ok(#(bits, acc))
    idx -> {
      case bits {
        <<
          nbr:big-signed-int-size(32),
          l_bound:big-signed-int-size(32),
          rest1:bits,
        >> -> {
          let current = #(nbr, l_bound)

          let data_info1 = list.prepend(acc, current)

          do_decode_array({ idx - 1 }, rest1, data_info1)
        }
        _ -> Error("invalid array")
      }
    }
  }
}

fn decode_array_elems(
  bits: BitArray,
  decoder: fn(BitArray) -> Result(Dynamic, String),
  acc: List(Dynamic),
) -> Result(List(Dynamic), String) {
  case bits {
    <<>> -> Ok(list.reverse(acc))
    <<-1:big-signed-int-size(32), rest:bits>> -> {
      list.prepend(acc, dynamic.nil())
      |> decode_array_elems(rest, decoder, _)
    }
    <<size:big-signed-int-size(32), rest:bits>> -> {
      let elem_len = size * 8

      case rest {
        <<val_bin:bits-size(elem_len), rest1:bits>> -> {
          use decoded <- result.try(decoder(val_bin))

          list.prepend(acc, decoded)
          |> decode_array_elems(rest1, decoder, _)
        }
        _ -> Error("invalid array")
      }
    }
    _ -> Error("invalid array")
  }
}

fn decode_bool(bits: BitArray) -> Result(Dynamic, String) {
  case bits {
    <<1:big-signed-int-size(8)>> -> Ok(dynamic.bool(True))
    <<0:big-signed-int-size(8)>> -> Ok(dynamic.bool(False))
    _ -> Error("invalid bool")
  }
}

fn decode_int2(bits: BitArray) -> Result(Dynamic, String) {
  case bits {
    <<num:big-signed-int-size(16)>> -> Ok(dynamic.int(num))
    _ -> Error("invalid int2")
  }
}

fn decode_oid(bits: BitArray) -> Result(Dynamic, String) {
  case bits {
    <<num:big-unsigned-int-size(32)>> -> Ok(dynamic.int(num))

    _ -> Error("invalid oid")
  }
}

fn decode_int4(bits: BitArray) -> Result(Dynamic, String) {
  case bits {
    <<num:big-signed-int-size(32)>> -> Ok(dynamic.int(num))
    _ -> Error("invalid int4")
  }
}

fn decode_int8(bits: BitArray) -> Result(Dynamic, String) {
  case bits {
    <<num:big-signed-int-size(64)>> -> Ok(dynamic.int(num))
    _ -> Error("invalid int8")
  }
}

fn decode_float4(bits: BitArray) -> Result(Dynamic, String) {
  case bits {
    <<value:big-float-size(32)>> -> {
      value
      |> dynamic.float
      |> Ok
    }
    _ -> Error("invalid float4")
  }
}

fn decode_float8(bits: BitArray) -> Result(Dynamic, String) {
  case bits {
    <<value:big-float-size(64)>> -> {
      value
      |> dynamic.float
      |> Ok
    }
    _ -> Error("invalid float8")
  }
}

fn decode_varchar(bits: BitArray) -> Result(Dynamic, String) {
  bit_array.to_string(bits)
  |> result.map(dynamic.string)
  |> result.replace_error("invalid varchar")
}

fn decode_text(bits: BitArray) -> Result(Dynamic, String) {
  bit_array.to_string(bits)
  |> result.map(dynamic.string)
  |> result.replace_error("invalid text")
}

fn decode_enum(bits: BitArray) -> Result(Dynamic, String) {
  bit_array.to_string(bits)
  |> result.map(dynamic.string)
  |> result.replace_error("invalid enum")
}

fn decode_json(bits: BitArray) -> Result(Dynamic, String) {
  bit_array.to_string(bits)
  |> result.map(dynamic.string)
  |> result.replace_error("invalid json")
}

fn decode_jsonb(bits: BitArray) -> Result(Dynamic, String) {
  case bits {
    <<1:int-size(8), rest:bits>> ->
      bit_array.to_string(rest)
      |> result.map(dynamic.string)
      |> result.replace_error("invalid jsonb")
    _ -> Error("invalid jsonb")
  }
}

fn decode_bytea(bits: BitArray) -> Result(Dynamic, String) {
  Ok(dynamic.bit_array(bits))
}

fn decode_uuid(bits: BitArray) -> Result(Dynamic, String) {
  case bits {
    <<_uuid:big-int-size(128)>> -> Ok(dynamic.bit_array(bits))
    _ -> Error("invalid uuid")
  }
}

fn decode_hstore(bits: BitArray) -> Result(Dynamic, String) {
  case bits {
    <<size:big-int-size(32), rest:bits>> -> {
      do_decode_hstore(size, rest, dict.new())
      |> result.map(fn(hstore) {
        hstore
        |> dict.to_list
        |> list.map(fn(key_val) {
          let key = dynamic.string(key_val.0)
          let val = case key_val.1 {
            Some(val) -> dynamic.string(val)
            None -> dynamic.nil()
          }

          #(key, val)
        })
        |> dynamic.properties
      })
      |> result.replace_error("invalid hstore")
    }
    _ -> Error("invalid hstore")
  }
}

fn do_decode_hstore(
  size: Int,
  bits: BitArray,
  acc: Dict(String, Option(String)),
) -> Result(Dict(String, Option(String)), Nil) {
  case size, bits {
    0, <<>> -> Ok(acc)
    // Declared count exhausted but trailing bytes remain: malformed input.
    0, _ -> Error(Nil)
    size, bits1 -> {
      use #(key, rest) <- result.try(decode_hstore_key(bits1))
      use #(val, rest1) <- result.try(decode_hstore_value(rest))

      let acc = acc |> dict.insert(key, val)

      do_decode_hstore(size - 1, rest1, acc)
    }
  }
}

fn decode_hstore_key(bits: BitArray) -> Result(#(String, BitArray), Nil) {
  case bits {
    <<key_len:big-int-size(32), key:bytes-size(key_len), rest:bits>> -> {
      use key <- result.map(bit_array.to_string(key))

      #(key, rest)
    }
    _ -> Error(Nil)
  }
}

fn decode_hstore_value(
  bits: BitArray,
) -> Result(#(Option(String), BitArray), Nil) {
  case bits {
    <<-1:big-signed-int-size(32), rest:bits>> -> Ok(#(None, rest))
    <<val_len:big-int-size(32), val:bytes-size(val_len), rest:bits>> -> {
      use val <- result.map(bit_array.to_string(val))

      #(Some(val), rest)
    }
    _ -> Error(Nil)
  }
}

fn decode_time(bits: BitArray) -> Result(Dynamic, String) {
  case bits {
    <<microseconds:big-int-size(64)>> -> {
      let tod = from_microseconds(microseconds)

      dynamic.array([
        dynamic.int(tod.hours),
        dynamic.int(tod.minutes),
        dynamic.int(tod.seconds),
        dynamic.int(tod.nanoseconds / 1000),
      ])
      |> Ok
    }
    _ -> Error("invalid time")
  }
}

fn decode_timestamp(bits: BitArray) -> Result(Dynamic, String) {
  let pos_infinity = int8_max
  let neg_infinity = int8_min

  case bits {
    <<num:signed-big-int-size(64)>> -> {
      case num {
        _pos_inf if num == pos_infinity -> Ok(dynamic.string("infinity"))
        _neg_inf if num == neg_infinity -> Ok(dynamic.string("-infinity"))
        _ -> Ok(handle_timestamp(num))
      }
    }
    _ -> Error("invalid timestamp")
  }
}

fn handle_timestamp(microseconds: Int) -> Dynamic {
  let seconds_since_unix_epoch =
    { microseconds / 1_000_000 }
    |> int.add(postgres_gs_epoch)
    |> int.subtract(gs_to_unix_epoch)

  let usecs_since_unix_epoch = seconds_since_unix_epoch * 1_000_000

  usecs_since_unix_epoch
  |> int.add({ microseconds % 1_000_000 })
  |> dynamic.int
}

fn decode_date(bits: BitArray) -> Result(Dynamic, String) {
  case bits {
    <<days:big-signed-int-size(32)>> -> {
      days_to_date(days)
      |> result.map(fn(date) {
        let month = calendar.month_to_int(date.month)

        dynamic.array([
          dynamic.int(date.year),
          dynamic.int(month),
          dynamic.int(date.day),
        ])
      })
      |> result.replace_error("Invalid month")
    }
    _ -> Error("invalid date")
  }
}

fn decode_interval(bits: BitArray) -> Result(Dynamic, String) {
  case bits {
    <<
      microseconds:big-signed-int-size(64),
      days:big-signed-int-size(32),
      months:big-signed-int-size(32),
    >> -> {
      dynamic.array([
        dynamic.int(months),
        dynamic.int(days),
        dynamic.int(microseconds),
      ])
      |> Ok
    }
    _ -> Error("invalid interval")
  }
}

fn from_microseconds(usecs: Int) -> calendar.TimeOfDay {
  let seconds = usecs / usecs_per_sec
  let nanoseconds = { usecs % usecs_per_sec } * 1000

  // Compute h/m/s with integer math rather than calendar:seconds_to_time/1,
  // which guards Secs < 86400 and would crash on PostgreSQL's valid 24:00:00.
  let hours = seconds / 3600
  let minutes = { seconds % 3600 } / 60
  let seconds = seconds % 60

  calendar.TimeOfDay(hours:, minutes:, seconds:, nanoseconds:)
}

fn days_to_date(days: Int) -> Result(calendar.Date, Nil) {
  let #(year, month, day) = gregorian_days_to_date(days + postgres_gd_epoch)

  calendar.month_from_int(month)
  |> result.map(fn(month) { calendar.Date(year:, month:, day:) })
}

fn to_microseconds(
  kind: a,
  to_seconds_and_nanoseconds: fn(a) -> #(Int, Int),
) -> Int {
  let #(seconds, nanoseconds) = to_seconds_and_nanoseconds(kind)

  { seconds * usecs_per_sec } + { nanoseconds / nsecs_per_usec }
}

fn unix_seconds_before_postgres_epoch() -> duration.Duration {
  gs_to_unix_epoch
  |> int.subtract(postgres_gs_epoch)
  |> duration.seconds
}

const oid_max = 0xFFFFFFFF

const int2_min = -32_768

const int2_max = 0x7FFF

const int4_min = -2_147_483_648

const int4_max = 0x7FFFFFFF

const int8_max = 0x7FFFFFFFFFFFFFFF

const int8_min = -9_223_372_036_854_775_808

// Seconds between Jan 1, 0001 and Jan 1, 2000
const postgres_gs_epoch = 63_113_904_000

// Seconds between Jan 1, 0001 and Jan 1, 1970
const gs_to_unix_epoch = 62_167_219_200

// Days between Jan 1, 0001 and Jan 1, 2000
const postgres_gd_epoch = 730_485

const usecs_per_sec = 1_000_000

const nsecs_per_usec = 1000

@external(erlang, "calendar", "gregorian_days_to_date")
fn gregorian_days_to_date(days: Int) -> #(Int, Int, Int)

@external(erlang, "calendar", "date_to_gregorian_days")
fn date_to_gregorian_days(year: Int, month: Int, day: Int) -> Int
