///|
pub(all) enum Shape {
  Square
  Rectangle
  Any
  WithDmre
  Dmre
  Fixed(Int, Int)
} derive(Eq)

///|
pub(all) struct EncodeOptions {
  shape : Shape
} derive(Eq)

///|
pub suberror EncodeError {
  UnsupportedSize
  CapacityExceeded
  InvalidOption(String)
} derive(Debug)

///|
pub extend EncodeError with @moonbitlang/core/debug.Debug::{to_repr}

///|
pub extend Shape with Eq::{equal, not_equal}

///|
pub extend EncodeOptions with Eq::{equal, not_equal}

///|
/// Return the dimensions selected for a data-codeword count (not byte length).
pub fn dimensions_for_codewords(
  count : Int,
  options? : EncodeOptions = { shape: Square, },
) -> (Int, Int) raise EncodeError {
  let s = select_size(count, options)
  (s.width, s.height)
}
