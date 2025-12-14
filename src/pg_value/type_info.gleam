//// This module provides a TypeInfo record and builder functions intended
//// for use by PostgreSQL client libraries. Applications should not have to
//// use anything in this module and instead use the `pg_value` module.

import gleam/option.{type Option, None}

/// Information about a PostgreSQL type. Needed for encoding and decoding Values.
pub type TypeInfo {
  TypeInfo(
    oid: Int,
    name: String,
    typesend: String,
    typereceive: String,
    typelen: Int,
    output: String,
    input: String,
    elem_oid: Int,
    elem_type: Option(TypeInfo),
    base_oid: Int,
    comp_oids: List(Int),
    comp_types: Option(List(TypeInfo)),
  )
}

/// Returns a TypeInfo record with the provided oid Int, with
/// all other values empty.
pub fn new(oid: Int) -> TypeInfo {
  TypeInfo(
    oid:,
    name: "",
    typesend: "",
    typereceive: "",
    typelen: 0,
    output: "",
    input: "",
    elem_oid: 0,
    elem_type: None,
    base_oid: 0,
    comp_oids: [],
    comp_types: None,
  )
}

/// Sets the name of a TypeInfo record.
pub fn name(ti: TypeInfo, name: String) -> TypeInfo {
  TypeInfo(..ti, name:)
}

/// Sets the typesend value of a TypeInfo record.
pub fn typesend(ti: TypeInfo, typesend: String) -> TypeInfo {
  TypeInfo(..ti, typesend:)
}

/// Sets the typereceive value of a TypeInfo record.
pub fn typereceive(ti: TypeInfo, typereceive: String) -> TypeInfo {
  TypeInfo(..ti, typereceive:)
}

/// Sets the typelen value of a TypeInfo record.
pub fn typelen(ti: TypeInfo, typelen: Int) -> TypeInfo {
  TypeInfo(..ti, typelen:)
}

/// Sets the output value of a TypeInfo record.
pub fn output(ti: TypeInfo, output: String) -> TypeInfo {
  TypeInfo(..ti, output:)
}

/// Sets the input value of a TypeInfo record.
pub fn input(ti: TypeInfo, input: String) -> TypeInfo {
  TypeInfo(..ti, input:)
}

/// Sets the elem_oid value of a TypeInfo record.
pub fn elem_oid(ti: TypeInfo, elem_oid: Int) -> TypeInfo {
  TypeInfo(..ti, elem_oid:)
}

/// Sets the base_oid value of a TypeInfo record.
pub fn base_oid(ti: TypeInfo, base_oid: Int) -> TypeInfo {
  TypeInfo(..ti, base_oid:)
}

/// Sets the comp_oids value of a TypeInfo record.
pub fn comp_oids(ti: TypeInfo, comp_oids: List(Int)) -> TypeInfo {
  TypeInfo(..ti, comp_oids:)
}

/// Sets the elem_type value of a TypeInfo record.
pub fn elem_type(ti: TypeInfo, elem_type: Option(TypeInfo)) -> TypeInfo {
  TypeInfo(..ti, elem_type:)
}

/// Sets the comp_types value of a TypeInfo record.
pub fn comp_types(ti: TypeInfo, comp_types: Option(List(TypeInfo))) -> TypeInfo {
  TypeInfo(..ti, comp_types:)
}
