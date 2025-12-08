import gleam/int
import gleam/time/duration

pub const oid_max = 0xFFFFFFFF

pub const int2_min = 0x8000

pub const int2_max = 0x7FFF

pub const int4_min = 0x80000000

pub const int4_max = 0x7FFFFFFF

pub const int8_max = 0x7FFFFFFFFFFFFFFF

pub const int8_min = 0x8000000000000000

// Seconds between Jan 1, 0001 and Dec 31, 1999
pub const postgres_gs_epoch = 63_113_904_000

// Seconds between Jan 1, 0001 and Jan 1, 1970
pub const gs_to_unix_epoch = 62_167_219_200

// Days between Jan 1, 0001 and Dec 31, 1999
pub const postgres_gd_epoch = 730_485

pub const usecs_per_sec = 1_000_000

pub const nsecs_per_usec = 1000

pub fn to_microseconds(
  kind: a,
  to_seconds_and_nanoseconds: fn(a) -> #(Int, Int),
) -> Int {
  let #(seconds, nanoseconds) = to_seconds_and_nanoseconds(kind)

  { seconds * usecs_per_sec } + { nanoseconds / nsecs_per_usec }
}

pub fn unix_seconds_before_postgres_epoch() -> duration.Duration {
  gs_to_unix_epoch
  |> int.subtract(postgres_gs_epoch)
  |> duration.seconds
}

// FFI

@external(erlang, "calendar", "gregorian_days_to_date")
pub fn gregorian_days_to_date(days: Int) -> #(Int, Int, Int)

@external(erlang, "calendar", "seconds_to_time")
pub fn seconds_to_time(seconds: Int) -> #(Int, Int, Int)

@external(erlang, "calendar", "date_to_gregorian_days")
pub fn date_to_gregorian_days(year: Int, month: Int, day: Int) -> Int
