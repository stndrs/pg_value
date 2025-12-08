import gleam/time/calendar
import gleam/time/duration
import gleam/time/timestamp
import pgl/value

pub fn null_to_string_test() {
  let assert "NULL" = value.null |> value.to_string
}

pub fn bool_to_string_test() {
  let assert "TRUE" = value.bool(True) |> value.to_string
  let assert "FALSE" = value.bool(False) |> value.to_string
}

pub fn int_to_string_test() {
  let assert "42" = value.int(42) |> value.to_string
  let assert "0" = value.int(0) |> value.to_string
  let assert "-123" = value.int(-123) |> value.to_string
}

pub fn float_to_string_test() {
  let assert "3.14" = value.float(3.14) |> value.to_string
  let assert "0.0" = value.float(0.0) |> value.to_string
  let assert "-2.5" = value.float(-2.5) |> value.to_string
}

pub fn text_to_string_test() {
  let assert "'hello'" = value.text("hello") |> value.to_string
  let assert "''" = value.text("") |> value.to_string
  let assert "'It\\'s working'" = value.text("It's working") |> value.to_string
  let assert "'Say \\'hello\\''" = value.text("Say 'hello'") |> value.to_string
}

pub fn bytea_to_string_test() {
  let assert "'\\x48656C6C6F'" =
    value.bytea(<<"Hello":utf8>>) |> value.to_string
  let assert "'\\x'" = value.bytea(<<>>) |> value.to_string
  let assert "'\\xDEADBEEF'" =
    value.bytea(<<0xDE, 0xAD, 0xBE, 0xEF>>) |> value.to_string
}

pub fn time_to_string_test() {
  let assert "'14:30:45'" =
    value.time(calendar.TimeOfDay(14, 30, 45, 0)) |> value.to_string
  let assert "'00:00:00'" =
    value.time(calendar.TimeOfDay(0, 0, 0, 0)) |> value.to_string
  let assert "'23:59:59.123'" =
    value.time(calendar.TimeOfDay(23, 59, 59, 123_456_000))
    |> value.to_string
  let assert "'09:05:03'" =
    value.time(calendar.TimeOfDay(9, 5, 3, 0)) |> value.to_string
  let assert "'09:05:03.400'" =
    value.time(calendar.TimeOfDay(9, 5, 3, 400_000_000))
    |> value.to_string
  let assert "'09:05:03.012'" =
    value.time(calendar.TimeOfDay(9, 5, 3, 12_000_000)) |> value.to_string
  let assert "'09:05:03.007'" =
    value.time(calendar.TimeOfDay(9, 5, 3, 7_000_000)) |> value.to_string
}

pub fn date_to_string_test() {
  let assert "'2025-01-15'" =
    value.date(calendar.Date(2025, calendar.January, 15))
    |> value.to_string
  let assert "'1990-02-09'" =
    value.date(calendar.Date(1990, calendar.February, 9))
    |> value.to_string
  let assert "'2000-12-31'" =
    value.date(calendar.Date(2000, calendar.December, 31))
    |> value.to_string
}

pub fn timestamp_to_string_test() {
  let assert Ok(ts) = timestamp.parse_rfc3339("2025-01-15T14:30:45Z")
  let assert "'2025-01-15T14:30:45Z'" = value.timestamp(ts) |> value.to_string

  let assert Ok(ts2) = timestamp.parse_rfc3339("2000-12-31T23:59:59.123456789Z")
  let assert "'2000-12-31T23:59:59.123456789Z'" =
    value.timestamp(ts2) |> value.to_string
}

pub fn interval_to_string_test() {
  let assert "'PT1H30M'" =
    value.interval(duration.hours(1) |> duration.add(duration.minutes(30)))
    |> value.to_string

  let assert "'PT0S'" = value.interval(duration.seconds(0)) |> value.to_string

  let assert "'PT5M30S'" =
    value.interval(duration.minutes(5) |> duration.add(duration.seconds(30)))
    |> value.to_string
}
