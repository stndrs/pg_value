import gleam/bit_array
import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode
import gleam/function
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/time/calendar
import gleam/time/duration
import gleam/time/timestamp
import gleeunit
import pg_value as value
import pg_value/interval
import pg_value/type_info

pub fn main() -> Nil {
  gleeunit.main()
}

// Value tests

pub fn null_to_string_test() {
  assert "NULL" == value.null |> value.to_string
}

pub fn bool_to_string_test() {
  assert "TRUE" == value.bool(True) |> value.to_string
  assert "FALSE" == value.bool(False) |> value.to_string
}

pub fn int_to_string_test() {
  assert "42" == value.int(42) |> value.to_string
  assert "0" == value.int(0) |> value.to_string
  assert "-123" == value.int(-123) |> value.to_string
}

pub fn float_to_string_test() {
  assert "3.14" == value.float(3.14) |> value.to_string
  assert "0.0" == value.float(0.0) |> value.to_string
  assert "-2.5" == value.float(-2.5) |> value.to_string
}

pub fn text_to_string_test() {
  assert "'hello'" == value.text("hello") |> value.to_string
  assert "''" == value.text("") |> value.to_string
  assert "'It''s working'" == value.text("It's working") |> value.to_string
  assert "'Say ''hello'''" == value.text("Say 'hello'") |> value.to_string
}

pub fn bytea_to_string_test() {
  assert "'\\x48656C6C6F'" == value.bytea(<<"Hello":utf8>>) |> value.to_string
  assert "'\\x'" == value.bytea(<<>>) |> value.to_string
  assert "'\\xDEADBEEF'"
    == value.bytea(<<0xDE, 0xAD, 0xBE, 0xEF>>) |> value.to_string
}

pub fn uuid_v4_to_string_test() {
  let v4_uuid = 0x85eab1c37acc4d8288e45fc1a9daa9d8

  let uuid = value.uuid(<<v4_uuid:big-int-size(128)>>)

  assert "'85eab1c3-7acc-4d82-88e4-5fc1a9daa9d8'" == value.to_string(uuid)
}

pub fn uuid_v7_to_string_test() {
  let v7_uuid = 0x019c39ce0a5a7dcabfaf8d79ed0db096

  let uuid = value.uuid(<<v7_uuid:big-int-size(128)>>)

  assert "'019c39ce-0a5a-7dca-bfaf-8d79ed0db096'" == value.to_string(uuid)
}

pub fn hstore_to_string_test() {
  let hstore =
    dict.new()
    |> dict.insert("name", Some("Alice"))
    |> value.hstore

  assert "'\"name\"=>\"Alice\"'" == value.to_string(hstore)
}

pub fn hstore_to_string_null_test() {
  let hstore =
    dict.new()
    |> dict.insert("deleted", None)
    |> value.hstore

  assert "'\"deleted\"=>NULL'" == value.to_string(hstore)
}

pub fn hstore_quote_escape_test() {
  let single_quote =
    dict.new()
    |> dict.insert("single'", Some("'quote"))
    |> value.hstore

  assert "'\"single''\"=>\"''quote\"'" == value.to_string(single_quote)
}

pub fn hstore_backslash_escape_test() {
  let backslash =
    dict.new()
    |> dict.insert("back\\", Some("\\slash"))
    |> value.hstore

  assert "'\"back\\\\\"=>\"\\\\slash\"'" == value.to_string(backslash)
}

pub fn hstore_double_quote_escape_test() {
  let double_quote =
    dict.new()
    |> dict.insert("say", Some("he said \"hi\""))
    |> value.hstore

  assert "'\"say\"=>\"he said \\\"hi\\\"\"'" == value.to_string(double_quote)
}

pub fn time_to_string_test() {
  assert "'14:30:45'"
    == value.time(calendar.TimeOfDay(14, 30, 45, 0)) |> value.to_string
  assert "'00:00:00'"
    == value.time(calendar.TimeOfDay(0, 0, 0, 0)) |> value.to_string
  assert "'23:59:59.123456'"
    == value.time(calendar.TimeOfDay(23, 59, 59, 123_456_000))
    |> value.to_string
  assert "'09:05:03'"
    == value.time(calendar.TimeOfDay(9, 5, 3, 0)) |> value.to_string
  assert "'09:05:03.4'"
    == value.time(calendar.TimeOfDay(9, 5, 3, 400_000_000))
    |> value.to_string
  assert "'09:05:03.012'"
    == value.time(calendar.TimeOfDay(9, 5, 3, 12_000_000)) |> value.to_string
  assert "'09:05:03.007'"
    == value.time(calendar.TimeOfDay(9, 5, 3, 7_000_000)) |> value.to_string
  assert "'09:05:03.000123'"
    == value.time(calendar.TimeOfDay(9, 5, 3, 123_000)) |> value.to_string
}

pub fn date_to_string_test() {
  assert "'2025-01-15'"
    == value.date(calendar.Date(2025, calendar.January, 15))
    |> value.to_string
  assert "'1990-02-09'"
    == value.date(calendar.Date(1990, calendar.February, 9))
    |> value.to_string
  assert "'2000-12-31'"
    == value.date(calendar.Date(2000, calendar.December, 31))
    |> value.to_string
  assert "'0033-01-15'"
    == value.date(calendar.Date(33, calendar.January, 15))
    |> value.to_string
  assert "'0001-01-01'"
    == value.date(calendar.Date(1, calendar.January, 1))
    |> value.to_string
}

pub fn timestamp_to_string_test() {
  let assert Ok(ts) = timestamp.parse_rfc3339("2025-01-15T14:30:45Z")
  assert "'2025-01-15T14:30:45Z'" == value.timestamp(ts) |> value.to_string

  let assert Ok(ts2) = timestamp.parse_rfc3339("2000-12-31T23:59:59.123456789Z")
  assert "'2000-12-31T23:59:59.123456789Z'"
    == value.timestamp(ts2) |> value.to_string
}

pub fn timestamptz_to_string_test() {
  let assert Ok(ts) = timestamp.parse_rfc3339("2025-01-15T14:30:45Z")
  let offset = duration.seconds(0)

  assert "'2025-01-15T14:30:45Z'"
    == value.timestamptz(ts, offset) |> value.to_string

  let assert Ok(ts2) = timestamp.parse_rfc3339("2000-12-31T23:59:59.123456789Z")
  let offset = duration.seconds(0)

  assert "'2000-12-31T23:59:59.123456789Z'"
    == value.timestamptz(ts2, offset) |> value.to_string
}

pub fn timestamptz_with_positive_offset_to_string_test() {
  let assert Ok(ts) = timestamp.parse_rfc3339("2025-01-15T14:30:45Z")
  let offset =
    duration.hours(10)
    |> duration.add(duration.minutes(30))

  assert "'2025-01-15T04:00:45Z'"
    == value.timestamptz(ts, offset) |> value.to_string
}

pub fn timestamptz_with_negative_offset_to_string_test() {
  let assert Ok(ts) = timestamp.parse_rfc3339("2025-01-15T14:30:45Z")
  let offset =
    duration.hours(-6)
    |> duration.add(duration.minutes(-30))

  assert "'2025-01-15T21:00:45Z'"
    == value.timestamptz(ts, offset) |> value.to_string
}

pub fn interval_to_string_test() {
  assert "'P1DT300S'"
    == interval.Interval(months: 0, days: 1, seconds: 300, microseconds: 0)
    |> value.interval
    |> value.to_string

  assert "'PT0S'"
    == interval.seconds(0)
    |> value.interval
    |> value.to_string

  assert "'P5MT30S'"
    == interval.months(5)
    |> interval.add(interval.seconds(30))
    |> value.interval
    |> value.to_string
}

pub fn enum_to_string_test() {
  assert "'active'" == value.enum("active") |> value.to_string
  assert "'pending'" == value.enum("pending") |> value.to_string
  assert "'it''s'" == value.enum("it's") |> value.to_string
}

pub fn json_to_string_test() {
  let val = json.object([#("key", json.string("value"))]) |> value.json
  assert "'{\"key\":\"value\"}'" == val |> value.to_string

  let val = json.null() |> value.json
  assert "'null'" == val |> value.to_string

  let val = json.array([1, 2, 3], of: json.int) |> value.json
  assert "'[1,2,3]'" == val |> value.to_string

  let val = json.object([#("name", json.string("O'Brien"))]) |> value.json
  assert "'{\"name\":\"O''Brien\"}'" == val |> value.to_string
}

pub fn array_to_string_test() {
  assert "ARRAY[1, 2, 3]"
    == value.array([1, 2, 3], of: value.int) |> value.to_string
  assert "ARRAY[42]" == value.array([42], of: value.int) |> value.to_string
  assert "'{}'" == value.array([], of: value.int) |> value.to_string
}

pub fn nullable_test() {
  assert value.Int(10) == value.nullable(value.int, Some(10))
  assert value.Null == value.nullable(value.int, None)
}

// Decode tests

const postgres_gs_epoch = 63_113_904_000

const gs_to_unix_epoch = 62_167_219_200

const int8_max = 0x7FFFFFFFFFFFFFFF

const int8_min = 0x8000000000000000

const usecs_per_sec = 1_000_000

const nsecs_per_usec = 1000

pub fn decode_timestamp_test() {
  let ts_value = { 1 - postgres_gs_epoch + gs_to_unix_epoch } * 1_000_000

  let in = <<ts_value:big-int-size(64)>>
  let out = dynamic.int(1_000_000)

  let assert Ok(ts) = value.decode(in, timestamp())
  assert out == ts

  let assert Ok(ts) = decode.run(ts, value.timestamp_decoder())

  assert timestamp.from_unix_seconds(1) == ts
}

pub fn decode_timestamp_pos_infinity_test() {
  let in = <<int8_max:big-int-size(64)>>
  let out = dynamic.string("infinity")

  let assert Ok(ts) = value.decode(in, timestamp())

  assert out == ts

  let assert Ok("infinity") = decode.run(ts, decode.string)
}

pub fn decode_timestamp_neg_infinity_test() {
  let in = <<-int8_min:big-int-size(64)>>
  let out = dynamic.string("-infinity")

  let assert Ok(ts) = value.decode(in, timestamp())

  assert out == ts

  let assert Ok("-infinity") = decode.run(ts, decode.string)
}

pub fn decode_oid_test() {
  use valid <- list.map([23, 1042, 0])

  let in = <<valid:big-int-size(32)>>
  let out = dynamic.int(valid)

  let assert Ok(result) = value.decode(in, oid())

  assert out == result
}

pub fn decode_oid_alias_test() {
  use typereceive <- list.map([
    "oidrecv", "regprocrecv", "regprocedurerecv", "regoperrecv",
    "regoperatorrecv", "regclassrecv", "regtyperecv", "xidrecv", "cidrecv",
  ])

  let ti =
    type_info.new(26)
    |> type_info.typereceive(typereceive)
  let in = <<1042:big-int-size(32)>>

  let assert Ok(result) = value.decode(in, ti)
  let assert Ok(1042) = decode.run(result, decode.int)

  Nil
}

pub fn decode_bool_test() {
  use #(byte, expected) <- list.map([#(1, True), #(0, False)])

  let in = <<byte:big-int-size(8)>>
  let out = dynamic.bool(expected)

  let assert Ok(result) = value.decode(in, bool())

  assert out == result
}

pub fn decode_int2_test() {
  use valid <- list.map([32_767, 0, -32_768])

  let in = <<valid:big-int-size(16)>>
  let out = dynamic.int(valid)

  let assert Ok(result) = value.decode(in, int2())

  assert out == result
}

pub fn decode_int2_error_test() {
  let in = <<1:big-int-size(8)>>
  let assert Error(value.InvalidInt2) = value.decode(in, int2())
}

pub fn decode_int4_test() {
  use valid <- list.map([2_147_483_647, 0, -2_147_483_648])

  let in = <<valid:big-int-size(32)>>
  let out = dynamic.int(valid)

  let assert Ok(result) = value.decode(in, int4())

  assert out == result
}

pub fn decode_int4_error_test() {
  let in = <<1:big-int-size(16)>>
  let assert Error(value.InvalidInt4) = value.decode(in, int4())
}

pub fn decode_int8_test() {
  use valid <- list.map([
    9_223_372_036_854_775_807,
    0,
    -9_223_372_036_854_775_808,
  ])

  let in = <<valid:big-int-size(64)>>
  let out = dynamic.int(valid)

  let assert Ok(result) = value.decode(in, int8())

  assert out == result
}

pub fn decode_int8_error_test() {
  let in = <<1:big-int-size(32)>>
  let assert Error(value.InvalidInt8) = value.decode(in, int8())
}

pub fn decode_float4_test() {
  use valid <- list.map([0.0, 3.14, -42.5])

  let in = <<valid:big-float-size(32)>>
  let assert <<expected:big-float-size(32)>> = in
  let out = dynamic.float(expected)

  let assert Ok(result) = value.decode(in, float4())

  assert out == result
}

pub fn decode_float4_error_test() {
  let in = <<1:big-int-size(16)>>
  let assert Error(value.InvalidFloat4) = value.decode(in, float4())
}

pub fn decode_float8_test() {
  use valid <- list.map([0.0, 3.14159, -42.989283])

  let in = <<valid:big-float-size(64)>>
  let out = dynamic.float(valid)

  let assert Ok(result) = value.decode(in, float8())

  assert out == result
}

pub fn decode_float8_error_test() {
  let in = <<1:big-int-size(32)>>
  let assert Error(value.InvalidFloat8) = value.decode(in, float8())
}

pub fn decode_varchar_test() {
  use valid <- list.map(["hello", "", "PostgreSQL"])

  let in = <<valid:utf8>>
  let out = dynamic.string(valid)

  let assert Ok(result) = value.decode(in, varchar())

  assert out == result
}

pub fn decode_varchar_error_test() {
  let in = <<255, 255, 255, 255>>
  let assert Error(value.InvalidVarchar) = value.decode(in, varchar())
}

pub fn decode_text_test() {
  use valid <- list.map(["hello world", "", "PostgreSQL Database"])

  let in = <<valid:utf8>>
  let out = dynamic.string(valid)

  let assert Ok(result) = value.decode(in, text())

  assert out == result
}

pub fn decode_text_error_test() {
  let in = <<255, 255, 255, 255>>
  let assert Error(value.InvalidText) = value.decode(in, text())
}

pub fn decode_bytea_test() {
  use valid <- list.map([<<1, 2, 3, 4, 5>>, <<>>, <<255, 0, 128>>])

  let in = valid
  let out = dynamic.bit_array(valid)

  let assert Ok(result) = value.decode(in, bytea())

  assert out == result
}

pub fn decode_char_test() {
  use valid <- list.map(["A", "x"])

  let in = <<valid:utf8>>
  let out = dynamic.string(valid)

  let assert Ok(result) = value.decode(in, char())

  assert out == result
}

pub fn decode_bpchar_test() {
  use valid <- list.map(["A", "padded   ", ""])

  let in = <<valid:utf8>>
  let out = dynamic.string(valid)

  let assert Ok(result) = value.decode(in, bpchar())

  assert out == result
}

pub fn encode_bpchar_test() {
  let in = value.text("abc")
  let expected = <<3:big-int-size(32), "abc":utf8>>

  let assert Ok(out) = value.encode(in, bpchar())

  assert expected == out
}

pub fn decode_name_test() {
  use valid <- list.map(["table_name", "", "column_name"])

  let in = <<valid:utf8>>
  let out = dynamic.string(valid)

  let assert Ok(result) = value.decode(in, name())

  assert out == result
}

pub fn decode_uuid_test() {
  let v4_uuid = 0x85eab1c37acc4d8288e45fc1a9daa9d8

  let in = <<v4_uuid:big-int-size(128)>>
  let out = dynamic.bit_array(in)

  let assert Ok(result) = value.decode(in, uuid())

  assert out == result
}

pub fn decode_hstore_test() {
  let data =
    dict.new()
    |> dict.insert("first", Some("foo"))
    |> dict.insert("second", Some("bar"))
    |> dict.insert("third", None)

  let value = value.hstore(data)

  let assert Ok(<<50:big-int-size(32), rest:bits>>) =
    value.encode(value, hstore())

  let assert Ok(out) = value.decode(rest, hstore())

  let assert Ok(decoded) =
    decode.run(out, decode.dict(decode.string, decode.optional(decode.string)))

  assert data == decoded
}

pub fn decode_hstore_malformed_test() {
  // Declared count 0 but trailing bytes present.
  let in = <<0:big-int-size(32), 1, 2, 3>>

  let assert Error(value.InvalidHstore) = value.decode(in, hstore())
}

pub fn decode_enum_test() {
  use label <- list.each(["active", "pending", "archived"])

  let in = <<label:utf8>>
  let out = dynamic.string(label)

  let assert Ok(result) = value.decode(in, enum_type())
  assert out == result
}

pub fn decode_enum_error_test() {
  let in = <<0xFF>>
  let assert Error(value.InvalidEnum) = value.decode(in, enum_type())
}

pub fn decode_json_test() {
  let json_str = "{\"key\":\"value\"}"
  let in = <<json_str:utf8>>
  let out = dynamic.string(json_str)

  let assert Ok(result) = value.decode(in, json_type())
  assert out == result
}

pub fn decode_json_error_test() {
  let in = <<0xFF>>
  let assert Error(value.InvalidJson) = value.decode(in, json_type())
}

pub fn decode_jsonb_test() {
  let json_str = "{\"key\":\"value\"}"
  let in = <<1:int-size(8), json_str:utf8>>
  let out = dynamic.string(json_str)

  let assert Ok(result) = value.decode(in, jsonb_type())
  assert out == result
}

pub fn decode_jsonb_error_test() {
  // Wrong version byte
  let in = <<2:int-size(8), "{}":utf8>>
  let assert Error(value.InvalidJsonb) = value.decode(in, jsonb_type())
}

pub fn decode_jsonb_empty_error_test() {
  let in = <<>>
  let assert Error(value.InvalidJsonb) = value.decode(in, jsonb_type())
}

pub fn decode_time_test() {
  use #(microseconds, expected_dynamic, expected_time) <- list.map([
    #(
      79_000_000,
      dynamic.array([
        dynamic.int(0),
        dynamic.int(1),
        dynamic.int(19),
        dynamic.int(0),
      ]),
      calendar.TimeOfDay(0, 1, 19, 0),
    ),
    #(
      0,
      dynamic.array([
        dynamic.int(0),
        dynamic.int(0),
        dynamic.int(0),
        dynamic.int(0),
      ]),
      calendar.TimeOfDay(0, 0, 0, 0),
    ),
    #(
      86_399_000_000,
      dynamic.array([
        dynamic.int(23),
        dynamic.int(59),
        dynamic.int(59),
        dynamic.int(0),
      ]),
      calendar.TimeOfDay(23, 59, 59, 0),
    ),
  ])

  let in = <<microseconds:big-int-size(64)>>

  let assert Ok(result) = value.decode(in, time())

  assert expected_dynamic == result

  let assert Ok(time) = decode.run(result, value.time_decoder())

  assert expected_time == time
}

pub fn decode_time_max_test() {
  let in = <<86_400_000_000:big-int-size(64)>>

  let assert Ok(result) = value.decode(in, time())

  let assert Ok(time) = decode.run(result, value.time_decoder())

  assert calendar.TimeOfDay(24, 0, 0, 0) == time
}

pub fn decode_time_error_test() {
  let in = <<1:big-int-size(32)>>
  let assert Error(value.InvalidTime) = value.decode(in, time())
}

pub fn decode_date_test() {
  use #(days, expected_list, expected_date) <- list.map([
    #(-10_957, [1970, 1, 1], calendar.Date(1970, calendar.January, 1)),
    #(0, [2000, 1, 1], calendar.Date(2000, calendar.January, 1)),
    #(366, [2001, 1, 1], calendar.Date(2001, calendar.January, 1)),
  ])

  let in = <<days:big-int-size(32)>>
  let out = dynamic.array(list.map(expected_list, dynamic.int))

  let assert Ok(result) = value.decode(in, date())

  assert out == result

  let assert Ok(date) = decode.run(result, value.date_decoder())

  assert expected_date == date
}

pub fn decode_date_error_test() {
  let in = <<1:big-int-size(16)>>
  let assert Error(value.InvalidDate) = value.decode(in, date())
}

pub fn array_error_test() {
  let in = <<1:big-int-size(16)>>
  let assert Error(value.InvalidArray) = value.decode(in, array(int2()))
}

pub fn decode_array_test() {
  let in = <<
    1:big-int-size(32), 0:big-int-size(32), 23:big-int-size(32),
    2:big-int-size(32), 1:big-int-size(32), 4:big-int-size(32),
    10:big-int-size(32), 4:big-int-size(32), 20:big-int-size(32),
  >>

  let assert Ok(result) = value.decode(in, array(int4()))

  let decoder = decode.list(decode.int)
  let assert Ok([10, 20]) = decode.run(result, decoder)
}

// Encode tests //

pub fn encode_null_test() {
  let assert Ok(encoded) = value.encode(value.null, int2())

  assert <<-1:int-size(32)>> == encoded
}

pub fn encode_bool_test() {
  use valid <- list.map([#(value.true, 1), #(value.false, 0)])

  let in = valid.0
  let expected = <<1:big-int-size(32), valid.1:big-int-size(8)>>

  let assert Ok(out) = value.encode(in, bool())

  assert expected == out
}

pub fn encode_bool_validation_error_test() {
  let assert Error(msg) = value.encode(value.true, int2())

  assert msg == value.TypeMismatch("boolsend", "int2send")
}

pub fn encode_int2_test() {
  use valid <- list.map([32_767, 0, -32_768])

  let in = value.int(valid)
  let expected = <<2:big-int-size(32), valid:big-int-size(16)>>

  let assert Ok(out) = value.encode(in, int2())

  assert expected == out
}

pub fn encode_int2_error_test() {
  use invalid <- list.map([-100_000, 100_000, 32_768, -32_769])

  let in = value.int(invalid)

  let assert Error(value.Int2OutOfRange(num)) = value.encode(in, int2())
  assert num == invalid
}

pub fn encode_int_validation_error_test() {
  let assert Error(msg) = value.encode(value.int(33), float4())

  assert msg == value.IncompatibleValue(value.Int(33), "float4send")
}

pub fn encode_int4_test() {
  use valid <- list.map([2_147_483_647, 0, -2_147_483_648])

  let in = value.int(valid)
  let expected = <<4:big-int-size(32), valid:big-int-size(32)>>

  let assert Ok(out) = value.encode(in, int4())

  assert expected == out
}

pub fn encode_int4_error_test() {
  use invalid <- list.map([2_147_483_648, -2_147_483_649])

  let in = value.int(invalid)

  let assert Error(value.Int4OutOfRange(num)) = value.encode(in, int4())
  assert num == invalid
}

pub fn encode_int8_test() {
  use valid <- list.map([
    9_223_372_036_854_775_807,
    0,
    -9_223_372_036_854_775_808,
  ])

  let in = value.int(valid)
  let expected = <<8:big-int-size(32), valid:big-int-size(64)>>

  let assert Ok(out) = value.encode(in, int8())

  assert expected == out
}

pub fn encode_int8_error_test() {
  use invalid <- list.map([
    9_223_372_036_854_775_807 + 1,
    -9_223_372_036_854_775_808 - 1,
  ])

  let in = value.int(invalid)

  let assert Error(value.Int8OutOfRange(num)) = value.encode(in, int8())
  assert num == invalid
}

pub fn encode_float4_test() {
  use valid <- list.map([0.0, 1.0, -1.0, 3.14, -42.5, 1.23e38])

  let in = value.float(valid)
  let expected = <<4:big-int-size(32), valid:float-size(32)>>

  let assert Ok(out) = value.encode(in, float4())

  assert expected == out
}

pub fn encode_float8_test() {
  use valid <- list.map([0.0, 1.0, -1.0, 3.14, -42.5, 1.23e308])

  let in = value.float(valid)
  let expected = <<8:big-int-size(32), valid:float-size(64)>>

  let assert Ok(out) = value.encode(in, float8())

  assert expected == out
}

pub fn encode_float_validation_error_test() {
  let assert Error(msg) = value.encode(value.float(33.5), varchar())

  assert msg == value.IncompatibleValue(value.Float(33.5), "varcharsend")
}

pub fn encode_oid_test() {
  use valid <- list.map([0, 1042, 4_294_967_295])

  let in = value.int(valid)
  let expected = <<4:big-int-size(32), valid:big-int-size(32)>>

  let assert Ok(out) = value.encode(in, oid())

  assert expected == out
}

pub fn encode_oid_alias_test() {
  // The object-identifier types share the oid wire format.
  use typesend <- list.map([
    "oidsend", "regprocsend", "regproceduresend", "regopersend",
    "regoperatorsend", "regclasssend", "regtypesend", "xidsend", "cidsend",
  ])

  let ti =
    type_info.new(26)
    |> type_info.typesend(typesend)
  let in = value.int(1042)
  let expected = <<4:big-int-size(32), 1042:big-int-size(32)>>

  let assert Ok(out) = value.encode(in, ti)

  assert expected == out
}

pub fn encode_oid_error_test() {
  use invalid <- list.map([-1, 4_294_967_296])

  let in = value.int(invalid)

  let assert Error(value.OidOutOfRange(num)) = value.encode(in, oid())
  assert num == invalid
}

pub fn encode_varchar_test() {
  use valid <- list.map([#("hello", 5), #("", 0), #("PostgreSQL", 10)])

  let in = value.text(valid.0)
  let expected = <<valid.1:big-int-size(32), valid.0:utf8>>

  let assert Ok(out) = value.encode(in, varchar())

  assert expected == out
}

pub fn encode_text_validation_error_test() {
  let assert Error(msg) = value.encode(value.text("some text"), float4())

  assert msg == value.IncompatibleValue(value.Text("some text"), "float4send")
}

pub fn encode_uuid_test() {
  let v4_uuid = 0x85eab1c37acc4d8288e45fc1a9daa9d8

  let value = value.uuid(<<v4_uuid:big-int-size(128)>>)
  let expected = <<16:big-int-size(32), v4_uuid:big-int-size(128)>>

  let assert Ok(encoded) = value.encode(value, uuid())

  assert expected == encoded
}

pub fn encode_uuid_error_test() {
  let value = value.uuid(<<"invalid":utf8>>)

  let assert Error(value.InvalidUuidSize) = value.encode(value, uuid())
}

pub fn encode_hstore_test() {
  let value =
    dict.new()
    |> dict.insert("name", Some("Alice"))
    |> value.hstore

  let expected = <<
    21:big-int-size(32),
    1:big-int-size(32),
    4:big-int-size(32),
    "name":utf8,
    5:big-int-size(32),
    "Alice":utf8,
  >>

  let assert Ok(encoded) = value.encode(value, hstore())

  assert expected == encoded
}

pub fn encode_hstore_null_value_test() {
  let value =
    dict.new()
    |> dict.insert("gone", None)
    |> value.hstore

  let expected = <<
    16:big-int-size(32),
    1:big-int-size(32),
    4:big-int-size(32),
    "gone":utf8,
    -1:big-int-size(32),
  >>

  let assert Ok(encoded) = value.encode(value, hstore())

  assert expected == encoded
}

pub fn encode_date_test() {
  let assert Ok(#(in, _tod)) =
    timestamp.parse_rfc3339("1970-01-01T00:00:00Z")
    |> result.map(timestamp.to_calendar(_, calendar.utc_offset))

  let expected = <<4:big-int-size(32), -10_957:big-int-size(32)>>

  let assert Ok(out) = value.encode(value.date(in), date())

  assert expected == out
}

pub fn encode_date_invalid_test() {
  use invalid <- list.map([
    calendar.Date(2025, calendar.February, 30),
    calendar.Date(2025, calendar.January, 0),
    calendar.Date(2023, calendar.February, 29),
  ])

  let assert Error(value.InvalidCalendarDate) =
    value.encode(value.date(invalid), date())
}

pub fn encode_date_validation_error_test() {
  let assert Error(msg) =
    value.date(calendar.Date(2025, calendar.January, 10))
    |> value.encode(float4())

  assert msg == value.TypeMismatch("date_send", "float4send")
}

pub fn encode_time_test() {
  let tod =
    calendar.TimeOfDay(hours: 0, minutes: 1, seconds: 19, nanoseconds: 0)

  let in = value.time(tod)
  let expected = <<8:big-int-size(32), 79_000_000:big-int-size(64)>>

  let assert Ok(out) = value.encode(in, time())

  assert expected == out
}

pub fn encode_time_validation_error_test() {
  let assert Error(msg) =
    value.encode(value.time(calendar.TimeOfDay(20, 10, 30, 0)), float4())

  assert msg == value.TypeMismatch("time_send", "float4send")
}

pub fn encode_timestamp_test() {
  let ts = timestamp.from_unix_seconds(1)

  let in = value.timestamp(ts)
  let expected = <<8:big-int-size(32), -946_684_799_000_000:big-int-size(64)>>

  let assert Ok(out) = value.encode(in, timestamp())

  assert expected == out
}

pub fn encode_timestamp_validation_error_test() {
  let assert Error(msg) =
    value.encode(value.timestamp(timestamp.system_time()), float4())

  assert msg == value.TypeMismatch("timestamp_send", "float4send")
}

fn to_microseconds(
  kind: a,
  to_seconds_and_nanoseconds: fn(a) -> #(Int, Int),
) -> Int {
  let #(seconds, nanoseconds) = to_seconds_and_nanoseconds(kind)

  { seconds * usecs_per_sec } + { nanoseconds / nsecs_per_usec }
}

pub fn encode_interval_test() {
  let val =
    interval.days(14)
    |> interval.add(interval.microseconds(79_000))
    |> value.interval

  let expected = <<
    16:big-int-size(32),
    79_000:big-int-size(64),
    14:big-int-size(32),
    0:big-int-size(32),
  >>

  let assert Ok(out) = value.encode(val, interval())

  assert expected == out
}

pub fn encode_interval_validation_error_test() {
  let val = interval.days(7) |> value.interval

  let assert Error(msg) = value.encode(val, float4())

  assert msg == value.TypeMismatch("interval_send", "float4send")
}

pub fn encode_enum_test() {
  let label = "active"
  let val = value.enum(label)

  let bits = <<label:utf8>>
  let len = 6
  let expected = <<len:big-int-size(32), bits:bits>>

  let assert Ok(out) = value.encode(val, enum_type())

  assert expected == out
}

pub fn encode_enum_validation_error_test() {
  let assert Error(msg) = value.encode(value.enum("active"), float4())

  assert msg == value.TypeMismatch("enum_send", "float4send")
}

pub fn encode_json_test() {
  let json_val = json.object([#("a", json.int(1))])
  let val = value.json(json_val)
  let json_str = "{\"a\":1}"
  let json_bits = <<json_str:utf8>>
  let len = bit_array.byte_size(json_bits)
  let expected = <<len:big-int-size(32), json_bits:bits>>

  let assert Ok(out) = value.encode(val, json_type())

  assert expected == out
}

pub fn encode_jsonb_test() {
  let json_val = json.object([#("a", json.int(1))])
  let val = value.json(json_val)
  let json_str = "{\"a\":1}"
  let json_bits = <<json_str:utf8>>
  let len = bit_array.byte_size(json_bits) + 1
  let expected = <<len:big-int-size(32), 1:int-size(8), json_bits:bits>>

  let assert Ok(out) = value.encode(val, jsonb_type())

  assert expected == out
}

pub fn encode_json_validation_error_test() {
  let val = json.null() |> value.json

  let assert Error(msg) = value.encode(val, float4())

  assert msg == value.IncompatibleValue(value.Json(json.null()), "float4send")
}

pub fn encode_timestamptz_test() {
  let expected_utc_int = -946_684_799_000_000
  let ts = timestamp.from_unix_seconds(1)
  let offset = duration.seconds(0)

  let expected = <<
    8:big-int-size(32),
    expected_utc_int:big-int-size(64),
  >>

  let in = value.timestamptz(ts, offset)

  let assert Ok(out) = value.encode(in, timestamptz())

  assert expected == out
}

pub fn encode_positive_offset_timestamptz_test() {
  let expected_utc_int = -946_684_800_000_000
  let ts = timestamp.from_unix_seconds(1)

  let offset = duration.hours(10)

  let dur =
    int.multiply(10, 60)
    |> int.negate
    |> duration.minutes

  let ten_hours =
    timestamp.add(ts, dur)
    |> to_microseconds(timestamp.to_unix_seconds_and_nanoseconds)
    |> int.add(expected_utc_int)

  let expected = <<
    8:big-int-size(32),
    ten_hours:big-int-size(64),
  >>

  let in = value.timestamptz(ts, offset)

  let assert Ok(out) = value.encode(in, timestamptz())

  assert expected == out
}

pub fn encode_negative_offset_timestamptz_test() {
  let expected_utc_int = -946_684_800_000_000
  let ts = timestamp.from_unix_seconds(1)
  let offset =
    duration.hours(-2)
    |> duration.add(duration.minutes(-30))

  let dur =
    int.multiply(2, 60)
    |> int.add(30)
    |> duration.minutes

  let minus_two_thirty =
    timestamp.add(ts, dur)
    |> to_microseconds(timestamp.to_unix_seconds_and_nanoseconds)
    |> int.add(expected_utc_int)

  let expected = <<
    8:big-int-size(32),
    minus_two_thirty:big-int-size(64),
  >>

  let in = value.timestamptz(ts, offset)

  let assert Ok(out) = value.encode(in, timestamptz())

  assert expected == out
}

pub fn encode_timestamptz_validation_error_test() {
  let assert Error(msg) =
    value.timestamptz(timestamp.system_time(), duration.hours(8))
    |> value.encode(float4())

  assert msg == value.TypeMismatch("timestamptz_send", "float4send")
}

pub fn empty_array_test() {
  let expected = <<
    12:big-int-size(32), 0:big-int-size(32), 0:big-int-size(32),
    21:big-int-size(32),
  >>

  let assert Ok(out) =
    value.encode(value.array([], of: value.int), array(int2()))

  assert expected == out
}

pub fn string_array_test() {
  let in = value.array(["hello", "world"], of: value.text)

  let expected = <<
    38:big-int-size(32), 1:big-int-size(32), 0:big-int-size(32),
    25:big-int-size(32), 2:big-int-size(32), 1:big-int-size(32),
    5:big-int-size(32), "hello":utf8, 5:big-int-size(32), "world":utf8,
  >>

  let assert Ok(out) = value.encode(in, array(text()))

  assert expected == out
}

pub fn int_array_test() {
  let in = value.array([42], of: value.int)
  let expected = <<
    28:big-int-size(32), 1:big-int-size(32), 0:big-int-size(32),
    23:big-int-size(32), 1:big-int-size(32), 1:big-int-size(32),
    4:big-int-size(32), 42:big-int-size(32),
  >>

  let assert Ok(out) = value.encode(in, array(int4()))

  assert expected == out
}

pub fn null_array_test() {
  let in = value.array([value.null], of: function.identity)

  let expected = <<
    24:big-int-size(32), 1:big-int-size(32), 1:big-int-size(32),
    23:big-int-size(32), 1:big-int-size(32), 1:big-int-size(32),
    -1:big-int-size(32),
  >>

  let assert Ok(out) = value.encode(in, array(int4()))

  assert expected == out
}

pub fn nested_array_test() {
  let in = value.Array([value.array([12, 23], of: value.int)])

  let expected = <<
    // total size of encoded array
    44:big-int-size(32),
    // number of dimensions
    2:big-int-size(32),
    // flags (has_nulls)
    0:big-int-size(32),
    // scalar element OID (int4)
    23:big-int-size(32),
    // size of first dimension
    1:big-int-size(32),
    // lower bound
    1:big-int-size(32),
    // size of second dimension
    2:big-int-size(32),
    // lower bound
    1:big-int-size(32),
    // flat elements (int4) in row-major order
    // size of element
    4:big-int-size(32),
    // element
    12:big-int-size(32),
    // size of element
    4:big-int-size(32),
    // element
    23:big-int-size(32),
  >>

  let assert Ok(out) = value.encode(in, array(array(int4())))

  assert expected == out
}

pub fn ragged_array_test() {
  let in =
    value.Array([
      value.array([1, 2], of: value.int),
      value.array([3], of: value.int),
    ])

  let assert Error(value.ArrayNotRectangular) =
    value.encode(in, array(array(int4())))
}

pub fn encode_array_validation_error_test() {
  let assert Error(msg) =
    value.encode(value.array([10, 12], of: value.int), float4())

  assert msg == value.TypeMismatch("array_send", "float4send")
}

pub fn encode_bytea_test() {
  let data = <<1, 2, 3, 4, 5>>
  let expected = <<5:big-int-size(32), 1, 2, 3, 4, 5>>

  let assert Ok(out) = value.encode(value.bytea(data), bytea())

  assert expected == out
}

pub fn encode_bytea_empty_test() {
  let expected = <<0:big-int-size(32)>>

  let assert Ok(out) = value.encode(value.bytea(<<>>), bytea())

  assert expected == out
}

// TypeInfo helpers

fn oid() {
  type_info.new(26)
  |> type_info.typesend("oidsend")
  |> type_info.typereceive("oidrecv")
}

fn bool() {
  type_info.new(16)
  |> type_info.typesend("boolsend")
  |> type_info.typereceive("boolrecv")
}

fn int2() {
  type_info.new(21)
  |> type_info.typesend("int2send")
  |> type_info.typereceive("int2recv")
}

fn int4() {
  type_info.new(23)
  |> type_info.typesend("int4send")
  |> type_info.typereceive("int4recv")
}

fn int8() {
  type_info.new(20)
  |> type_info.typesend("int8send")
  |> type_info.typereceive("int8recv")
}

fn float4() {
  type_info.new(700)
  |> type_info.typesend("float4send")
  |> type_info.typereceive("float4recv")
}

fn float8() {
  type_info.new(701)
  |> type_info.typesend("float8send")
  |> type_info.typereceive("float8recv")
}

fn varchar() {
  type_info.new(1043)
  |> type_info.typesend("varcharsend")
  |> type_info.typereceive("varcharrecv")
}

fn text() {
  type_info.new(25)
  |> type_info.typesend("textsend")
  |> type_info.typereceive("textrecv")
}

fn bytea() {
  type_info.new(17)
  |> type_info.typesend("byteasend")
  |> type_info.typereceive("bytearecv")
}

fn char() {
  type_info.new(18)
  |> type_info.typesend("charsend")
  |> type_info.typereceive("charrecv")
}

fn bpchar() {
  type_info.new(1042)
  |> type_info.typesend("bpcharsend")
  |> type_info.typereceive("bpcharrecv")
}

fn name() {
  type_info.new(19)
  |> type_info.typesend("namesend")
  |> type_info.typereceive("namerecv")
}

fn uuid() {
  type_info.new(2950)
  |> type_info.typesend("uuid_send")
  |> type_info.typereceive("uuid_recv")
}

fn hstore() {
  type_info.new(18_600)
  |> type_info.typesend("hstore_send")
  |> type_info.typereceive("hstore_recv")
}

fn time() {
  type_info.new(1083)
  |> type_info.typesend("time_send")
  |> type_info.typereceive("time_recv")
}

fn date() {
  type_info.new(1082)
  |> type_info.typesend("date_send")
  |> type_info.typereceive("date_recv")
}

fn timestamp() {
  type_info.new(1114)
  |> type_info.typesend("timestamp_send")
  |> type_info.typereceive("timestamp_recv")
}

fn timestamptz() {
  type_info.new(1184)
  |> type_info.typesend("timestamptz_send")
  |> type_info.typereceive("timestamptz_recv")
}

fn interval() {
  type_info.new(1186)
  |> type_info.typesend("interval_send")
  |> type_info.typereceive("interval_recv")
}

fn enum_type() {
  type_info.new(0)
  |> type_info.typesend("enum_send")
  |> type_info.typereceive("enum_recv")
}

fn array(ti: type_info.TypeInfo) -> type_info.TypeInfo {
  type_info.new(143)
  |> type_info.typesend("array_send")
  |> type_info.typereceive("array_recv")
  |> type_info.elem_type(Some(ti))
}

fn json_type() {
  type_info.new(114)
  |> type_info.typesend("json_send")
  |> type_info.typereceive("json_recv")
}

fn jsonb_type() {
  type_info.new(3802)
  |> type_info.typesend("jsonb_send")
  |> type_info.typereceive("jsonb_recv")
}

fn tid() {
  type_info.new(27)
  |> type_info.typesend("tidsend")
  |> type_info.typereceive("tidrecv")
}

fn macaddr() {
  type_info.new(829)
  |> type_info.typesend("macaddr_send")
  |> type_info.typereceive("macaddr_recv")
}

fn point() {
  type_info.new(600)
  |> type_info.typesend("point_send")
  |> type_info.typereceive("point_recv")
}

fn line() {
  type_info.new(628)
  |> type_info.typesend("line_send")
  |> type_info.typereceive("line_recv")
}

fn lseg() {
  type_info.new(601)
  |> type_info.typesend("lseg_send")
  |> type_info.typereceive("lseg_recv")
}

fn circle() {
  type_info.new(718)
  |> type_info.typesend("circle_send")
  |> type_info.typereceive("circle_recv")
}

// Tier 2: tid, macaddr, and geometry types

pub fn encode_tid_test() {
  let expected = <<6:big-int-size(32), 42:big-int-size(32), 7:big-int-size(16)>>

  let assert Ok(out) = value.encode(value.tid(42, 7), tid())

  assert expected == out
}

pub fn tid_to_string_test() {
  assert "'(42,7)'" == value.to_string(value.tid(42, 7))
}

pub fn encode_tid_error_test() {
  use #(block, tuple_index) <- list.map([
    #(-1, 0),
    #(4_294_967_296, 0),
    #(0, 65_536),
  ])

  let assert Error(value.TidOutOfRange(b, t)) =
    value.encode(value.tid(block, tuple_index), tid())
  assert b == block
  assert t == tuple_index
}

pub fn encode_tid_type_mismatch_test() {
  let assert Error(value.TypeMismatch("tidsend", "oidsend")) =
    value.encode(value.tid(42, 7), oid())
}

pub fn decode_tid_test() {
  let in = <<42:big-int-size(32), 7:big-int-size(16)>>

  let assert Ok(result) = value.decode(in, tid())
  let assert Ok("(42,7)") = decode.run(result, decode.string)
}

pub fn decode_tid_error_test() {
  let assert Error(value.InvalidTid) = value.decode(<<1, 2>>, tid())
}

pub fn encode_macaddr_test() {
  let mac = <<0x08, 0x00, 0x2b, 0x01, 0x02, 0x03>>
  let expected = <<
    6:big-int-size(32),
    0x08,
    0x00,
    0x2b,
    0x01,
    0x02,
    0x03,
  >>

  let assert Ok(out) = value.encode(value.macaddr(mac), macaddr())

  assert expected == out
}

pub fn encode_macaddr_error_test() {
  let assert Error(value.IncompatibleValue(
    value.Macaddr(<<1, 2>>),
    "macaddr_send",
  )) = value.encode(value.macaddr(<<1, 2>>), macaddr())
}

pub fn decode_macaddr_test() {
  let in = <<0x08, 0x00, 0x2b, 0x01, 0x02, 0x03>>

  let assert Ok(result) = value.decode(in, macaddr())
  let assert Ok("08:00:2b:01:02:03") = decode.run(result, decode.string)
}

pub fn decode_macaddr_error_test() {
  let assert Error(value.InvalidMacaddr) = value.decode(<<1, 2>>, macaddr())
}

pub fn encode_point_test() {
  let expected = <<
    16:big-int-size(32),
    1.5:big-float-size(64),
    2.0:big-float-size(64),
  >>

  let assert Ok(out) = value.encode(value.point(1.5, 2.0), point())

  assert expected == out
}

pub fn decode_point_test() {
  let in = <<1.5:big-float-size(64), 2.0:big-float-size(64)>>

  let assert Ok(result) = value.decode(in, point())
  let assert Ok("(1.5,2)") = decode.run(result, decode.string)
}

pub fn decode_point_error_test() {
  let assert Error(value.InvalidPoint) = value.decode(<<1, 2>>, point())
}

pub fn point_to_string_test() {
  assert "'(1.5,2)'" == value.to_string(value.point(1.5, 2.0))
  assert "'(2,3)'" == value.to_string(value.point(2.0, 3.0))
}

pub fn encode_line_test() {
  let expected = <<
    24:big-int-size(32),
    1.0:big-float-size(64),
    2.0:big-float-size(64),
    3.0:big-float-size(64),
  >>

  let assert Ok(out) = value.encode(value.line(1.0, 2.0, 3.0), line())

  assert expected == out
}

pub fn decode_line_test() {
  let in = <<
    1.0:big-float-size(64),
    2.0:big-float-size(64),
    3.0:big-float-size(64),
  >>

  let assert Ok(result) = value.decode(in, line())
  let assert Ok("{1,2,3}") = decode.run(result, decode.string)
}

pub fn line_to_string_test() {
  assert "'{1,2,3}'" == value.to_string(value.line(1.0, 2.0, 3.0))
}

pub fn encode_line_segment_test() {
  let expected = <<
    32:big-int-size(32),
    1.0:big-float-size(64),
    2.0:big-float-size(64),
    3.0:big-float-size(64),
    4.0:big-float-size(64),
  >>

  let assert Ok(out) =
    value.encode(value.line_segment(1.0, 2.0, 3.0, 4.0), lseg())

  assert expected == out
}

pub fn decode_line_segment_test() {
  let in = <<
    1.0:big-float-size(64),
    2.0:big-float-size(64),
    3.0:big-float-size(64),
    4.0:big-float-size(64),
  >>

  let assert Ok(result) = value.decode(in, lseg())
  let assert Ok("[(1,2),(3,4)]") = decode.run(result, decode.string)
}

pub fn line_segment_to_string_test() {
  assert "'[(1,2),(3,4)]'"
    == value.to_string(value.line_segment(1.0, 2.0, 3.0, 4.0))
}

pub fn encode_circle_test() {
  let expected = <<
    24:big-int-size(32),
    1.0:big-float-size(64),
    2.0:big-float-size(64),
    3.5:big-float-size(64),
  >>

  let assert Ok(out) = value.encode(value.circle(1.0, 2.0, 3.5), circle())

  assert expected == out
}

pub fn decode_circle_test() {
  let in = <<
    1.0:big-float-size(64),
    2.0:big-float-size(64),
    3.5:big-float-size(64),
  >>

  let assert Ok(result) = value.decode(in, circle())
  let assert Ok("<(1,2),3.5>") = decode.run(result, decode.string)
}

pub fn circle_to_string_test() {
  assert "'<(1,2),3.5>'" == value.to_string(value.circle(1.0, 2.0, 3.5))
}
