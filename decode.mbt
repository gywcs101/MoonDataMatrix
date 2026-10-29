// Data decoding adapted from datamatrix-rs src/decodation (MIT).

///|
pub suberror DecodeError {
  InvalidMatrix(String)
  UnsupportedMatrixSize
  CorrectionFailed
  InvalidCodeword(String)
  InvalidText
} derive(@debug.Debug)

///|
pub extend DecodeError with @debug.Debug::{to_repr}

///|
pub struct DecodedMessage {
  priv payload : Bytes
  priv ecis : Array[(Int, Int)]
  gs1 : Bool
  macro_kind : Int
  reader_programming : Bool
  append : AppendHeader?
  priv separators : Array[Int]
  corrected_codewords : Int
}

///|
pub fn DecodedMessage::bytes(self : DecodedMessage) -> Bytes {
  self.payload
}

///|
pub fn DecodedMessage::eci_changes(self : DecodedMessage) -> Array[(Int, Int)] {
  self.ecis.copy()
}

///|
pub fn DecodedMessage::text(self : DecodedMessage) -> String raise DecodeError {
  let out = StringBuilder()
  fn chunk(start : Int, end : Int, eci : Int) -> Unit raise DecodeError {
    let mut pos = start
    for sep in self.separators {
      if sep < start || sep >= end {
        continue
      }
      if sep > pos {
        out.write_string(
          @charset.decode(
            Bytes::makei(sep - pos, fn(i) { self.payload[pos + i] }),
            eci,
          ) catch {
            _ => raise InvalidText
          },
        )
      }
      out.write_char('\u001d')
      pos = sep + 1
    }
    if end > pos {
      out.write_string(
        @charset.decode(
          Bytes::makei(end - pos, fn(i) { self.payload[pos + i] }),
          eci,
        ) catch {
          _ => raise InvalidText
        },
      )
    }
  }
  let mut start = 0
  let mut active = 3
  for (offset, eci) in self.ecis {
    chunk(start, offset, active)
    start = offset
    active = eci
  }
  chunk(
    start,
    self.payload.length() - (if self.macro_kind != 0 { 2 } else { 0 }),
    active,
  )
  if self.macro_kind != 0 {
    out.write_string("\u001e\u0004")
  }
  out.to_string()
}

///|
priv struct CodeReader {
  data : Array[Int]
  mut pos : Int
}

///|
fn CodeReader::take(self : CodeReader) -> Int raise DecodeError {
  if self.pos >= self.data.length() {
    raise InvalidCodeword("truncated data")
  }
  let value = self.data[self.pos]
  self.pos += 1
  value
}

///|
fn CodeReader::left(self : CodeReader) -> Int {
  self.data.length() - self.pos
}

///|
fn CodeReader::unrandom(self : CodeReader) -> Int raise DecodeError {
  let value = self.take() - (149 * self.pos % 255 + 1)
  if value < 0 {
    value + 256
  } else {
    value
  }
}

///|
fn decode_data(
  data : Array[Int],
  corrected : Int,
) -> DecodedMessage raise DecodeError {
  let r = CodeReader::{ data, pos: 0, }
  let out : Array[Byte] = []
  let ecis = []
  let separators = []
  let mut gs1 = false
  let mut macro_kind = 0
  let mut reader_programming = false
  let mut append : AppendHeader? = None
  while r.left() > 0 {
    let cw = r.take()
    if cw >= 1 && cw <= 128 {
      out.push((cw - 1).to_byte())
      continue
    }
    if cw >= 130 && cw <= 229 {
      out.push((48 + (cw - 130) / 10).to_byte())
      out.push((48 + (cw - 130) % 10).to_byte())
      continue
    }
    match cw {
      232 =>
        if r.pos == 1 || (r.pos == 5 && append is Some(_)) {
          gs1 = true
        } else {
          separators.push(out.length())
          out.push(b'\x1d')
        }
      233 => {
        if r.pos != 1 {
          raise InvalidCodeword("structured append position")
        }
        let sequence = r.take()
        let a : AppendHeader = {
          index: (sequence >> 4) + 1,
          count: 17 - (sequence & 15),
          file_id1: r.take(),
          file_id2: r.take(),
        }
        if !valid_append(a) {
          raise InvalidCodeword("structured append header")
        }
        append = Some(a)
      }
      234 => {
        if r.pos != 1 {
          raise InvalidCodeword("reader programming position")
        }
        reader_programming = true
      }
      236 | 237 => {
        if r.pos != 1 {
          raise InvalidCodeword("macro position")
        }
        macro_kind = cw - 231
        for b in b"[)>\x1e0" {
          out.push(b)
        }
        out.push((48 + macro_kind).to_byte())
        out.push(b'\x1d')
      }
      129 =>
        while r.left() > 0 {
          let value = r.take()
          let pad = 129 + (149 * r.pos % 253 + 1)
          if value != (if pad > 254 { pad - 254 } else { pad }) {
            raise InvalidCodeword("padding")
          }
        }
      235 => {
        let x = r.take()
        if x < 1 || x > 128 {
          raise InvalidCodeword("upper shift")
        }
        out.push((x + 127).to_byte())
      }
      241 => {
        let a = r.take()
        let eci = if a >= 1 && a <= 127 {
          a - 1
        } else if a >= 128 && a <= 191 {
          let b = r.take()
          if b < 1 || b > 254 {
            raise InvalidCodeword("ECI")
          }
          (a - 128) * 254 + b + 126
        } else if a >= 192 && a <= 207 {
          let b = r.take()
          let c = r.take()
          if b < 1 || b > 254 || c < 1 || c > 254 {
            raise InvalidCodeword("ECI")
          }
          (a - 192) * 64516 + (b - 1) * 254 + c + 16382
        } else {
          raise InvalidCodeword("ECI")
        }
        if eci > 999999 {
          raise InvalidCodeword("ECI range")
        }
        ecis.push((out.length(), eci))
      }
      231 => {
        let a = r.unrandom()
        let n = if a == 0 {
          r.left()
        } else if a < 250 {
          a
        } else {
          (a - 249) * 250 + r.unrandom()
        }
        for _ in 0..<n {
          out.push(r.unrandom().to_byte())
        }
      }
      230 | 239 | 238 => {
        let mut shift = 0
        let mut upper = false
        while r.left() > 0 {
          if r.data[r.pos] == 254 {
            ignore(r.take())
            break
          }
          if r.left() == 1 {
            break
          }
          let full = r.take() * 256 + r.take() - 1
          if full < 0 || full > 63999 {
            raise InvalidCodeword("triplet")
          }
          for v in [full / 1600, full / 40 % 40, full % 40] {
            if cw == 238 {
              let x = match v {
                0 => 13
                1 => 42
                2 => 62
                3 => 32
                _ => if v < 14 { v + 44 } else { v + 51 }
              }
              out.push(x.to_byte())
              continue
            }
            if shift == 0 && v < 3 {
              shift = v + 1
              continue
            }
            let x = if shift == 0 {
              if v == 3 {
                32
              } else if v < 14 {
                v + 44
              } else {
                v + (if cw == 230 { 51 } else { 83 })
              }
            } else if shift == 1 {
              if v > 31 {
                raise InvalidCodeword("shift1")
              }
              v
            } else if shift == 2 {
              if v == 30 {
                upper = true
                shift = 0
                continue
              }
              if v == 27 {
                separators.push(out.length())
                out.push(b'\x1d')
                shift = 0
                continue
              }
              if v > 26 {
                raise InvalidCodeword("shift2")
              }
              if v < 15 {
                v + 33
              } else if v < 22 {
                v + 43
              } else {
                v + 69
              }
            } else {
              if v > 31 {
                raise InvalidCodeword("shift3")
              }
              if cw == 230 {
                v + 96
              } else if v == 0 {
                96
              } else if v < 27 {
                v + 64
              } else {
                v + 96
              }
            }
            out.push((x + (if upper { 128 } else { 0 })).to_byte())
            shift = 0
            upper = false
          }
        }
        if upper {
          raise InvalidCodeword("unfinished upper shift")
        }
      }
      240 => {
        let mut ended = false
        while r.left() > 2 && !ended {
          let start = r.pos
          let bits = r.data[start] * 65536 +
            r.data[start + 1] * 256 +
            r.data[start + 2]
          for i in 0..<4 {
            let v = (bits >> (18 - 6 * i)) & 63
            if v == 31 {
              r.pos = start + ((i + 1) * 6 + 7) / 8
              ended = true
              break
            }
            out.push((if v < 32 { v + 64 } else { v }).to_byte())
          }
          if !ended {
            r.pos += 3
          }
        }
      }
      254 => if r.left() != 0 { raise InvalidCodeword("unexpected unlatch") }
      _ => raise InvalidCodeword("unsupported control or invalid codeword")
    }
  }
  if macro_kind != 0 {
    out.push(b'\x1e')
    out.push(b'\x04')
  }
  {
    payload: Bytes::from_array(out),
    ecis,
    separators,
    gs1,
    macro_kind,
    reader_programming,
    append,
    corrected_codewords: corrected,
  }
}

///|
/// Decode a canonical matrix including finder borders, one boolean per module.
pub fn decode_matrix(
  matrix : Array[Array[Bool]],
) -> DecodedMessage raise DecodeError {
  let h = matrix.length()
  if h == 0 {
    raise InvalidMatrix("empty matrix")
  }
  let w = matrix[0].length()
  if matrix.iter().any(fn(row) { row.length() != w }) {
    raise InvalidMatrix("ragged matrix")
  }
  let matches = (sizes + dmre_sizes).filter(fn(s) {
    s.width == w && s.height == h
  })
  if matches.is_empty() {
    raise UnsupportedMatrixSize
  }
  let size = matches[0]
  let rw = w / size.regions_x - 2
  let rh = h / size.regions_y - 2
  for ry in 0..<size.regions_y {
    for rx in 0..<size.regions_x {
      let ox = rx * (rw + 2)
      let oy = ry * (rh + 2)
      for x in 0..<(rw + 2) {
        if matrix[oy][ox + x] != (x % 2 == 0) || !matrix[oy + rh + 1][ox + x] {
          raise InvalidMatrix("finder border")
        }
      }
      for y in 0..<rh {
        if !matrix[oy + y + 1][ox] ||
          matrix[oy + y + 1][ox + rw + 1] != (y % 2 == 0) {
          raise InvalidMatrix("finder border")
        }
      }
    }
  }
  let dw = w - 2 * size.regions_x
  let map = placement_indices(size)
  let words = Array::make(size.capacity + size.blocks * size.ecc, 0)
  for i in 0..<map.length() {
    let bit = map[i]
    if bit < 0 {
      continue
    }
    let x = i % dw
    let y = i / dw
    if matrix[y + 1 + 2 * (y / rh)][x + 1 + 2 * (x / rw)] {
      words[bit / 8] = words[bit / 8] | (1 << (7 - bit % 8))
    }
  }
  let corrected = correct_codewords(words, size)
  decode_data(Array::makei(size.capacity, fn(i) { words[i] }), corrected)
}

///|
pub fn DecodedMessage::fnc1_positions(self : DecodedMessage) -> Array[Int] {
  self.separators.copy()
}
