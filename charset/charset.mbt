///|
pub suberror CharsetError {
  UnsupportedEci(Int)
  InvalidSequence
  Unrepresentable(Int)
} derive(@debug.Debug)

///|
pub extend CharsetError with @debug.Debug::{to_repr}

///|
fn integer(data : Bytes, pos : Int, n : Int) -> Int {
  let mut out = 0
  for i in 0..<n {
    out = (out << 8) | data[pos + i].to_int()
  }
  out
}

///|
fn lookup(table : Bytes, key : Int, key_bytes : Int) -> Int? {
  let mut lo = 0
  let mut hi = table.length() / 5
  while lo < hi {
    let mid = (lo + hi) / 2
    let value = integer(table, mid * 5, key_bytes)
    if value < key {
      lo = mid + 1
    } else {
      hi = mid
    }
  }
  if lo * 5 < table.length() && integer(table, lo * 5, key_bytes) == key {
    Some(integer(table, lo * 5 + key_bytes, 5 - key_bytes))
  } else {
    None
  }
}

///|
fn emit(out : Array[Byte], value : Int, n : Int, little : Bool) -> Unit {
  for i in 0..<n {
    out.push(
      ((value >> (8 * (if little { i } else { n - 1 - i }))) & 255).to_byte(),
    )
  }
}

///|
pub fn encode(text : String, eci : Int) -> Bytes raise CharsetError {
  if eci == 26 {
    return @utf8.encode(text)
  }
  let out : Array[Byte] = []
  for ch in text.to_array() {
    let cp = ch.to_int()
    if eci == 25 || eci == 33 {
      if cp < 65536 {
        emit(out, cp, 2, eci == 33)
      } else {
        emit(out, 0xD800 + ((cp - 65536) >> 10), 2, eci == 33)
        emit(out, 0xDC00 + ((cp - 65536) & 1023), 2, eci == 33)
      }
    } else if eci == 34 || eci == 35 {
      emit(out, cp, 4, eci == 35)
    } else {
      let (_, enc) = tables(eci)
      match lookup(enc, cp, 3) {
        Some(v) => emit(out, v, if v < 256 { 1 } else { 2 }, false)
        None => {
          let mut found = false
          if eci == 32 {
            for (pointer, start, count) in gb_ranges {
              if cp >= start && cp < start + count {
                let n = pointer + cp - start
                out.push((n / 12600 + 129).to_byte())
                out.push((n / 1260 % 10 + 48).to_byte())
                out.push((n / 10 % 126 + 129).to_byte())
                out.push((n % 10 + 48).to_byte())
                found = true
                break
              }
            }
          }
          if !found {
            raise Unrepresentable(cp)
          }
        }
      }
    }
  }
  // Validate ECI even for an empty string.
  if eci != 25 && eci != 33 && eci != 34 && eci != 35 {
    ignore(tables(eci))
  }
  Bytes::from_array(out)
}

///|
pub fn decode(data : Bytes, eci : Int) -> String raise CharsetError {
  if eci == 26 {
    return @utf8.decode(data, ignore_bom=false) catch {
      _ => raise InvalidSequence
    }
  }
  let out = StringBuilder()
  let mut i = 0
  while i < data.length() {
    let mut cp = 0
    if eci == 25 || eci == 33 || eci == 34 || eci == 35 {
      let n = if eci == 25 || eci == 33 { 2 } else { 4 }
      let little = eci == 33 || eci == 35
      if i + n > data.length() {
        raise InvalidSequence
      }
      for j in 0..<n {
        cp = (cp << 8) | data[i + (if little { n - 1 - j } else { j })].to_int()
      }
      i += n
      if n == 2 && cp >= 0xD800 && cp <= 0xDBFF {
        if i + 2 > data.length() {
          raise InvalidSequence
        }
        let low = if little {
          data[i].to_int() | (data[i + 1].to_int() << 8)
        } else {
          integer(data, i, 2)
        }
        if low < 0xDC00 || low > 0xDFFF {
          raise InvalidSequence
        }
        cp = 65536 + ((cp - 0xD800) << 10) + low - 0xDC00
        i += 2
      }
    } else {
      let (dec, _) = tables(eci)
      let a = data[i].to_int()
      match lookup(dec, a, 2) {
        Some(v) => {
          cp = v
          i += 1
        }
        None => {
          if i + 1 >= data.length() {
            raise InvalidSequence
          }
          let b = data[i + 1].to_int()
          if eci == 32 && a >= 129 && a <= 254 && b >= 48 && b <= 57 {
            if i + 3 >= data.length() {
              raise InvalidSequence
            }
            let c = data[i + 2].to_int()
            let d = data[i + 3].to_int()
            if c < 129 || c > 254 || d < 48 || d > 57 {
              raise InvalidSequence
            }
            let pointer = (((a - 129) * 10 + b - 48) * 126 + c - 129) * 10 +
              d -
              48
            let mut found = false
            for (start, base, count) in gb_ranges {
              if pointer >= start && pointer < start + count {
                cp = base + pointer - start
                found = true
                break
              }
            }
            if !found {
              raise InvalidSequence
            }
            i += 4
          } else {
            match lookup(dec, a * 256 + b, 2) {
              Some(v) => cp = v
              None => raise InvalidSequence
            }
            i += 2
          }
        }
      }
    }
    match cp.to_char() {
      Some(ch) => out.write_char(ch)
      None => raise InvalidSequence
    }
  }
  if eci != 25 && eci != 33 && eci != 34 && eci != 35 {
    ignore(tables(eci))
  }
  out.to_string()
}

///|
fn join_bytes(chunks : Array[Bytes]) -> Bytes {
  let out : Array[Byte] = []
  for chunk in chunks {
    for byte in chunk {
      out.push(byte)
    }
  }
  Bytes::from_array(out)
}
