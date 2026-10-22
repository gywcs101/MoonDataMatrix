// Adapted from datamatrix-rs encodation/base256.rs (MIT).

///|
fn randomized(value : Int, position : Int) -> Int {
  (value + 149 * position % 255 + 1) & 255
}

///|
fn append_base256(
  out : Array[Int],
  data : Bytes,
  start : Int,
  end : Int,
) -> Unit {
  let count = end - start
  out.push(231)
  if count <= 249 {
    out.push(randomized(count, out.length() + 1))
  } else {
    out.push(randomized(count / 250 + 249, out.length() + 1))
    out.push(randomized(count % 250, out.length() + 1))
  }
  for i in start..<end {
    out.push(randomized(data[i].to_int(), out.length() + 1))
  }
}
