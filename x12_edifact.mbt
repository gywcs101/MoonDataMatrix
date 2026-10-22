// Adapted from datamatrix-rs X12 and EDIFACT packing rules (MIT).

///|
fn x12_value(c : Int) -> Int? {
  if c == 13 {
    Some(0)
  } else if c == 42 {
    Some(1)
  } else if c == 62 {
    Some(2)
  } else if c == 32 {
    Some(3)
  } else if c >= 48 && c <= 57 {
    Some(c - 44)
  } else if c >= 65 && c <= 90 {
    Some(c - 51)
  } else {
    None
  }
}

///|
fn append_edifact(out : Array[Int], values : Array[Int]) -> Unit {
  for i = 0; i < values.length(); i = i + 4 {
    let n = values.length() - i
    let a = values[i] & 63
    let b = if n > 1 { values[i + 1] & 63 } else { 0 }
    let c = if n > 2 { values[i + 2] & 63 } else { 0 }
    let d = if n > 3 { values[i + 3] & 63 } else { 0 }
    out.push((a << 2) | (b >> 4))
    if n > 1 {
      out.push(((b << 4) | (c >> 2)) & 255)
    }
    if n > 2 {
      out.push(((c << 6) | d) & 255)
    }
  }
}
