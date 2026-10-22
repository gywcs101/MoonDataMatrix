// Adapted from datamatrix-rs encodation/base256.rs (MIT).

///|
fn randomized(value : Int, position : Int) -> Int {
  (value + 149 * position % 255 + 1) & 255
}
