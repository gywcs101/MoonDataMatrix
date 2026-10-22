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

///|
fn data_codewords(data : Bytes, eci : Bool) -> Array[Int] {
  let out = if eci { [241, 27] } else { [] }
  let ascii = ascii_codewords(data)
  let n = data.length()
  if n > 0 && n <= 1555 && n + (if n <= 249 { 2 } else { 3 }) < ascii.length() {
    append_base256(out, data, 0, n)
  } else {
    for b in ascii {
      out.push(b)
    }
  }
  out
}
