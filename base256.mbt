// Adapted from datamatrix-rs encodation/base256.rs (MIT).

///|
fn randomized(value : Int32, position : Int32) -> Int32 {
  (value + 149 * position % 255 + 1) & 255
}
