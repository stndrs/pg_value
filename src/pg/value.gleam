import gleam/bit_array
import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import gleam/time/calendar
import gleam/time/duration
import gleam/time/timestamp

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
  Interval(duration.Duration)
  Array(List(Value))
}

pub const null = Null

pub const true = Bool(True)

pub const false = Bool(False)

pub fn bool(val: Bool) -> Value {
  Bool(val)
}

pub fn int(val: Int) -> Value {
  Int(val)
}

pub fn float(val: Float) -> Value {
  Float(val)
}

pub fn text(val: String) -> Value {
  Text(val)
}

pub fn bytea(val: BitArray) -> Value {
  Bytea(val)
}

pub fn time(val: calendar.TimeOfDay) -> Value {
  Time(val)
}

pub fn date(val: calendar.Date) -> Value {
  Date(val)
}

pub fn timestamp(ts: timestamp.Timestamp) -> Value {
  Timestamp(ts)
}

pub fn interval(val: duration.Duration) -> Value {
  Interval(val)
}

pub fn array(vals: List(a), of kind: fn(a) -> Value) -> Value {
  vals
  |> list.map(kind)
  |> Array
}

pub fn nullable(inner_type: fn(a) -> Value, value: Option(a)) -> Value {
  case value {
    Some(term) -> inner_type(term)
    None -> Null
  }
}

pub fn to_string(val: Value) -> String {
  case val {
    Null -> "NULL"
    Bool(val) -> bool_to_string(val)
    Int(val) -> int.to_string(val)
    Float(val) -> float.to_string(val)
    Text(val) -> text_to_string(val)
    Bytea(val) -> bytea_to_string(val)
    Time(val) -> time_to_string(val)
    Date(val) -> date_to_string(val)
    Timestamp(val) -> timestamp_to_string(val)
    Interval(val) -> duration_to_string(val)
    Array(vals) -> array_to_string(vals)
  }
}

fn text_to_string(val: String) -> String {
  let val = string.replace(in: val, each: "'", with: "\\'")

  single_quote(val)
}

// https://www.postgresql.org/docs/current/arrays.html#ARRAYS-INPUT
fn array_to_string(val: List(Value)) -> String {
  let elems = case val {
    [] -> ""
    [val] -> to_string(val)
    vals -> {
      vals
      |> list.map(to_string)
      |> string.join(", ")
    }
  }

  "ARRAY[" <> elems <> "]"
}

// https://www.postgresql.org/docs/current/datatype-boolean.html#DATATYPE-BOOLEAN
fn bool_to_string(val: Bool) -> String {
  case val {
    True -> "TRUE"
    False -> "FALSE"
  }
}

// https://www.postgresql.org/docs/current/datatype-binary.html#DATATYPE-BINARY-BYTEA-HEX-FORMAT
fn bytea_to_string(val: BitArray) -> String {
  let val = "\\x" <> bit_array.base16_encode(val)

  single_quote(val)
}

fn date_to_string(date: calendar.Date) -> String {
  let year = int.to_string(date.year)
  let month = calendar.month_to_int(date.month) |> pad_zero
  let day = pad_zero(date.day)

  let date = year <> "-" <> month <> "-" <> day

  single_quote(date)
}

fn time_to_string(tod: calendar.TimeOfDay) -> String {
  let hours = pad_zero(tod.hours)
  let minutes = pad_zero(tod.minutes)
  let seconds = pad_zero(tod.seconds)
  let milliseconds = tod.nanoseconds / 1_000_000

  let msecs = case milliseconds < 100 {
    True if milliseconds == 0 -> ""
    True if milliseconds < 10 -> ".00" <> int.to_string(milliseconds)
    True -> ".0" <> int.to_string(milliseconds)
    False -> "." <> int.to_string(milliseconds)
  }

  let time = hours <> ":" <> minutes <> ":" <> seconds <> msecs

  single_quote(time)
}

fn timestamp_to_string(ts: timestamp.Timestamp) -> String {
  timestamp.to_rfc3339(ts, calendar.utc_offset)
  |> single_quote
}

fn duration_to_string(dur: duration.Duration) -> String {
  duration.to_iso8601_string(dur)
  |> single_quote
}

fn single_quote(val: String) -> String {
  "'" <> val <> "'"
}

fn pad_zero(n: Int) -> String {
  case n < 10 {
    True -> "0" <> int.to_string(n)
    False -> int.to_string(n)
  }
}
