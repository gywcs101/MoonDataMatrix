///|
pub(all) enum MessageSegment {
  Data(Bytes)
  Text(String, Int)
  Eci(Int)
  Fnc1
}

///|
pub(all) struct AppendHeader {
  index : Int
  count : Int
  file_id1 : Int
  file_id2 : Int
} derive(Eq)

///|
pub extend AppendHeader with Eq::{equal, not_equal}

///|
pub(all) struct MessageOptions {
  symbol : EncodeOptions
  gs1 : Bool
  macro_kind : Int
  reader_programming : Bool
  append : AppendHeader?
}

///|
pub fn MessageOptions::new(
  symbol? : EncodeOptions = { shape: Square, },
  gs1? : Bool = false,
  macro_kind? : Int = 0,
  reader_programming? : Bool = false,
  append? : AppendHeader? = None,
) -> MessageOptions {
  { symbol, gs1, macro_kind, reader_programming, append, }
}

///|
fn valid_append(a : AppendHeader) -> Bool {
  a.count >= 2 &&
  a.count <= 16 &&
  a.index >= 1 &&
  a.index <= a.count &&
  a.file_id1 >= 1 &&
  a.file_id1 <= 254 &&
  a.file_id2 >= 1 &&
  a.file_id2 <= 254
}

///|
fn append_eci(out : Array[Int], eci : Int) -> Unit raise EncodeError {
  if eci < 0 || eci > 999999 {
    raise InvalidOption("ECI must be 0..999999")
  }
  out.push(241)
  if eci <= 126 {
    out.push(eci + 1)
  } else if eci <= 16382 {
    out.push((eci - 127) / 254 + 128)
    out.push((eci - 127) % 254 + 1)
  } else {
    out.push((eci - 16383) / 64516 + 192)
    out.push((eci - 16383) / 254 % 254 + 1)
    out.push((eci - 16383) % 254 + 1)
  }
}

///|
/// Encode explicit protocol segments. Data segments use the active ECI as supplied.
pub fn encode_message(
  segments : Array[MessageSegment],
  options? : MessageOptions = MessageOptions::new(),
) -> Symbol raise EncodeError {
  let normalized = []
  for segment in segments {
    match segment {
      Text(text, eci) => {
        let bytes = @charset.encode(text, eci) catch {
          _ => raise InvalidOption("charset conversion failed")
        }
        if options.gs1 {
          if eci != 3 {
            raise InvalidOption("GS1 text requires Latin-1")
          }
        } else {
          normalized.push(Eci(eci))
        }
        normalized.push(Data(bytes))
      }
      _ => normalized.push(segment)
    }
  }
  let segments = normalized
  if options.macro_kind != 0 &&
    options.macro_kind != 5 &&
    options.macro_kind != 6 {
    raise InvalidOption("macro must be 0, 5 or 6")
  }
  if options.reader_programming &&
    (options.gs1 || options.append is Some(_) || options.macro_kind != 0) {
    raise InvalidOption("incompatible reader programming header")
  }
  if options.macro_kind != 0 && (options.gs1 || options.append is Some(_)) {
    raise InvalidOption("incompatible macro header")
  }
  let out = []
  match options.append {
    Some(a) => {
      if !valid_append(a) {
        raise InvalidOption("invalid structured append header")
      }
      out.push(233)
      out.push(((a.index - 1) << 4) | (17 - a.count))
      out.push(a.file_id1)
      out.push(a.file_id2)
    }
    None => ()
  }
  if options.gs1 {
    out.push(232)
  }
  if options.reader_programming {
    out.push(234)
  }
  if options.macro_kind != 0 {
    out.push(231 + options.macro_kind)
  }
  let mut length = 0
  for segment in segments {
    if segment is Data(b) {
      length += b.length()
      if length > 3116 {
        raise CapacityExceeded
      }
    }
  }
  for i in 0..<segments.length() {
    match segments[i] {
      Text(_, _) => raise InvalidOption("internal text normalization")
      Eci(n) => {
        if options.gs1 {
          raise InvalidOption("GS1 uses its element-string character set")
        }
        append_eci(out, n)
      }
      Fnc1 => {
        if options.reader_programming || options.macro_kind != 0 {
          raise InvalidOption("FNC1 with control header")
        }
        out.push(232)
      }
      Data(bytes) =>
        if i == segments.length() - 1 {
          ignore(planned_with_prefix(bytes, out, options.symbol))
        } else {
          let ascii = ascii_codewords(bytes)
          let overhead = if bytes.length() <= 249 { 2 } else { 3 }
          if ascii.length() <= bytes.length() + overhead {
            for cw in ascii {
              out.push(cw)
            }
          } else {
            out.push(231)
            if bytes.length() <= 249 {
              out.push(randomized(bytes.length(), out.length() + 1))
            } else {
              out.push(randomized(bytes.length() / 250 + 249, out.length() + 1))
              out.push(randomized(bytes.length() % 250, out.length() + 1))
            }
            for byte in bytes {
              out.push(randomized(byte.to_int(), out.length() + 1))
            }
          }
        }
    }
  }
  finish(out, options.symbol)
}

///|
/// Encode a GS1 element string with ASCII GS (29) separating variable-length fields.
pub fn encode_gs1(
  elements : Bytes,
  options? : EncodeOptions = { shape: Square, },
) -> Symbol raise EncodeError {
  let segments = []
  let chunk : Array[Byte] = []
  for b in elements {
    if b == b'\x1d' {
      segments.push(Data(Bytes::from_array(chunk)))
      chunk.clear()
      segments.push(Fnc1)
    } else {
      chunk.push(b)
    }
  }
  segments.push(Data(Bytes::from_array(chunk)))
  encode_message(
    segments,
    options=MessageOptions::new(symbol=options, gs1=true),
  )
}

///|
/// Recognize a Macro 05/06 envelope and encode its body with a macro header.
pub fn encode_macro(
  envelope : Bytes,
  options? : EncodeOptions = { shape: Square, },
) -> Symbol raise EncodeError {
  let n = envelope.length()
  if n < 9 ||
    envelope[0] != b'[' ||
    envelope[1] != b')' ||
    envelope[2] != b'>' ||
    envelope[3] != b'\x1e' ||
    envelope[4] != b'0' ||
    (envelope[5] != b'5' && envelope[5] != b'6') ||
    envelope[6] != b'\x1d' ||
    envelope[n - 2] != b'\x1e' ||
    envelope[n - 1] != b'\x04' {
    raise InvalidOption("invalid Macro 05/06 envelope")
  }
  let body = Bytes::makei(n - 9, fn(i) { envelope[i + 7] })
  encode_message(
    [Data(body)],
    options=MessageOptions::new(
      symbol=options,
      macro_kind=envelope[5].to_int() - 48,
    ),
  )
}
