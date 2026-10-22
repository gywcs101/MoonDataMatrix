// ASCII and padding rules adapted from datamatrix-rs encodation (MIT).

///|
fn ascii_codewords(data : Bytes) -> Array[Int] {
  let out = []
  let mut i = 0
  while i < data.length() {
    let a = data[i].to_int()
    if i + 1 < data.length() &&
      a >= 48 &&
      a <= 57 &&
      data[i + 1] >= b'0' &&
      data[i + 1] <= b'9' {
      out.push(130 + (a - 48) * 10 + data[i + 1].to_int() - 48)
      i += 2
    } else {
      if a >= 128 {
        out.push(235)
        out.push(a - 127)
      } else {
        out.push(a + 1)
      }
      i += 1
    }
  }
  out
}

///|
fn finish(
  codewords : Array[Int],
  options : EncodeOptions,
) -> Symbol raise EncodeError {
  let s = select_size(codewords.length(), options)
  if codewords.length() < s.capacity {
    codewords.push(129)
  }
  while codewords.length() < s.capacity {
    let value = 129 + 149 * (codewords.length() + 1) % 253 + 1
    codewords.push(if value > 254 { value - 254 } else { value })
  }
  let ecc = error_code(codewords, s)
  for b in ecc {
    codewords.push(b)
  }
  place(codewords, s)
}

///|
/// Encode raw bytes without ECI or any transformation.
pub fn encode_bytes(
  data : Bytes,
  options? : EncodeOptions = { shape: Square, },
) -> Symbol raise EncodeError {
  if data.length() > 3116 {
    raise CapacityExceeded
  }
  finish(planned_codewords(data, false), options)
}

///|
/// Encode UTF-8 text with ECI 26, preserving all whitespace and zero bytes.
pub fn encode_text(
  text : String,
  options? : EncodeOptions = { shape: Square, },
) -> Symbol raise EncodeError {
  let data = @utf8.encode(text)
  if data.length() > 3116 {
    raise CapacityExceeded
  }
  finish(planned_codewords(data, true), options)
}
