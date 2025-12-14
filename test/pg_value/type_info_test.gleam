import gleam/option.{None, Some}
import pg_value/type_info

pub fn new_test() {
  let info = type_info.new(23)

  let assert 23 = info.oid
  let assert "" = info.name
  let assert "" = info.typesend
  let assert "" = info.typereceive
  let assert 0 = info.typelen
  let assert "" = info.output
  let assert "" = info.input
  let assert 0 = info.elem_oid
  let assert None = info.elem_type
  let assert 0 = info.base_oid
  let assert [] = info.comp_oids
  let assert None = info.comp_types
}

pub fn type_info_test() {
  let int4_info =
    type_info.new(23)
    |> type_info.name("int4")
    |> type_info.typesend("int4send")
    |> type_info.typereceive("int4recv")
    |> type_info.typelen(4)
    |> type_info.output("int4out")
    |> type_info.input("int4in")

  let assert 23 = int4_info.oid
  let assert "int4" = int4_info.name
  let assert "int4send" = int4_info.typesend
  let assert "int4recv" = int4_info.typereceive
  let assert 4 = int4_info.typelen
  let assert "int4out" = int4_info.output
  let assert "int4in" = int4_info.input
  let assert 0 = int4_info.elem_oid
  let assert None = int4_info.elem_type
  let assert 0 = int4_info.base_oid
  let assert [] = int4_info.comp_oids
  let assert None = int4_info.comp_types

  let array_info =
    type_info.new(1007)
    |> type_info.name("_int4")
    |> type_info.typesend("array_send")
    |> type_info.typereceive("array_recv")
    |> type_info.typelen(-1)
    |> type_info.output("array_out")
    |> type_info.input("array_in")
    |> type_info.elem_oid(23)
    |> type_info.elem_type(Some(int4_info))

  let assert 1007 = array_info.oid
  let assert "_int4" = array_info.name
  let assert "array_send" = array_info.typesend
  let assert "array_recv" = array_info.typereceive
  let assert -1 = array_info.typelen
  let assert "array_out" = array_info.output
  let assert "array_in" = array_info.input
  let assert 23 = array_info.elem_oid
  let assert Some(_int4) = array_info.elem_type
  let assert 0 = array_info.base_oid
  let assert [] = array_info.comp_oids
  let assert None = array_info.comp_types
}
