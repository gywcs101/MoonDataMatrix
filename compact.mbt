// Character maps and packing adapted from datamatrix-rs encodation (MIT).

///|
fn c40_values(byte : Int, text : Bool) -> Array[Int] {
  let out = []
  let mut c = byte
  if c >= 128 {
    out.push(1)
    out.push(30)
    c -= 128
  }
  if text {
    if c >= 65 && c <= 90 {
      c += 32
    } else if c >= 97 && c <= 122 {
      c -= 32
    }
  }
  if c == 32 {
    out.push(3)
  } else if c >= 48 && c <= 57 {
    out.push(c - 44)
  } else if c >= 65 && c <= 90 {
    out.push(c - 51)
  } else if c <= 31 {
    out.push(0)
    out.push(c)
  } else if c <= 47 {
    out.push(1)
    out.push(c - 33)
  } else if c <= 64 {
    out.push(1)
    out.push(c - 43)
  } else if c <= 95 {
    out.push(1)
    out.push(c - 69)
  } else {
    out.push(2)
    out.push(c - 96)
  }
  out
}

///|
fn append_triplets(out : Array[Int], values : Array[Int]) -> Unit {
  for i = 0; i < values.length(); i = i + 3 {
    let v = 1600 * values[i] + 40 * values[i + 1] + values[i + 2] + 1
    out.push(v >> 8)
    out.push(v & 255)
  }
}
