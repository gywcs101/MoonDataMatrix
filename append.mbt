///|
/// Split raw bytes into independently decodable symbols with a shared file ID.
pub fn encode_append_bytes(
  data : Bytes,
  file_id1 : Int,
  file_id2 : Int,
  options? : EncodeOptions = { shape: Square, },
  eci? : Int? = None,
) -> Array[Symbol] raise EncodeError {
  let parts : Array[Bytes] = []
  let mut offset = 0
  while offset < data.length() || parts.is_empty() {
    if parts.length() >= 16 {
      raise CapacityExceeded
    }
    let mut lo = 0
    let mut hi = data.length() - offset
    if hi > 3116 {
      hi = 3116
    }
    let mut best = -1
    while lo <= hi {
      let n = (lo + hi) / 2
      let bytes = Bytes::makei(n, fn(i) { data[offset + i] })
      let segments = match eci {
        Some(e) => [Eci(e), Data(bytes)]
        None => [Data(bytes)]
      }
      let fits = try {
        ignore(
          encode_message(
            segments,
            options=MessageOptions::new(
              symbol=options,
              append=Some({ index: 1, count: 16, file_id1, file_id2, }),
            ),
          ),
        )
        true
      } catch {
        CapacityExceeded => false
        e => raise e
      }
      if fits {
        best = n
        lo = n + 1
      } else {
        hi = n - 1
      }
    }
    if best < 0 || (best == 0 && offset < data.length()) {
      raise CapacityExceeded
    }
    parts.push(Bytes::makei(best, fn(i) { data[offset + i] }))
    offset += best
  }
  if parts.length() == 1 {
    let segments = match eci {
      Some(e) => [Eci(e), Data(parts[0])]
      None => [Data(parts[0])]
    }
    return [
      encode_message(segments, options=MessageOptions::new(symbol=options)),
    ]
  }
  let result = []
  for i in 0..<parts.length() {
    let segments = match eci {
      Some(e) => [Eci(e), Data(parts[i])]
      None => [Data(parts[i])]
    }
    result.push(
      encode_message(
        segments,
        options=MessageOptions::new(
          symbol=options,
          append=Some({
            index: i + 1,
            count: parts.length(),
            file_id1,
            file_id2,
          }),
        ),
      ),
    )
  }
  result
}

///|
/// Split UTF-8 text only between complete Unicode characters.
pub fn encode_append_text(
  text : String,
  file_id1 : Int,
  file_id2 : Int,
  options? : EncodeOptions = { shape: Square, },
) -> Array[Symbol] raise EncodeError {
  let chars = text.to_array()
  let parts : Array[String] = []
  let mut offset = 0
  while offset < chars.length() || parts.is_empty() {
    if parts.length() >= 16 {
      raise CapacityExceeded
    }
    let mut lo = 0
    let mut hi = chars.length() - offset
    if hi > 3116 {
      hi = 3116
    }
    let mut best = -1
    let mut chosen = ""
    while lo <= hi {
      let n = (lo + hi) / 2
      let builder = StringBuilder()
      for i in 0..<n {
        builder.write_char(chars[offset + i])
      }
      let part = builder.to_string()
      let fits = try {
        ignore(
          encode_message(
            [Text(part, 26)],
            options=MessageOptions::new(
              symbol=options,
              append=Some({ index: 1, count: 16, file_id1, file_id2, }),
            ),
          ),
        )
        true
      } catch {
        CapacityExceeded => false
        e => raise e
      }
      if fits {
        best = n
        chosen = part
        lo = n + 1
      } else {
        hi = n - 1
      }
    }
    if best < 0 || (best == 0 && offset < chars.length()) {
      raise CapacityExceeded
    }
    parts.push(chosen)
    offset += best
  }
  if parts.length() == 1 {
    return [encode_text(parts[0], options~)]
  }
  let result = []
  for i in 0..<parts.length() {
    result.push(
      encode_message(
        [Text(parts[i], 26)],
        options=MessageOptions::new(
          symbol=options,
          append=Some({
            index: i + 1,
            count: parts.length(),
            file_id1,
            file_id2,
          }),
        ),
      ),
    )
  }
  result
}

///|
/// Reassemble an unordered set. Duplicate indices and incomplete sets are errors.
pub fn assemble(
  parts : Array[DecodedMessage],
) -> DecodedMessage raise DecodeError {
  if parts.is_empty() {
    raise InvalidCodeword("empty append set")
  }
  let first = match parts[0].append {
    Some(a) => a
    None => {
      if parts.length() == 1 {
        return parts[0]
      }
      raise InvalidCodeword("missing append header")
    }
  }
  if parts.length() != first.count {
    raise InvalidCodeword("missing or excess append parts")
  }
  let slots : Array[DecodedMessage?] = Array::make(first.count, None)
  for p in parts {
    let a = match p.append {
      Some(a) => a
      None => raise InvalidCodeword("missing append header")
    }
    if a.count != first.count ||
      a.file_id1 != first.file_id1 ||
      a.file_id2 != first.file_id2 ||
      p.gs1 != parts[0].gs1 ||
      p.macro_kind != 0 ||
      p.reader_programming {
      raise InvalidCodeword("inconsistent append metadata")
    }
    if slots[a.index - 1] is Some(_) {
      raise InvalidCodeword("duplicate append index")
    }
    slots[a.index - 1] = Some(p)
  }
  let payload : Array[Byte] = []
  let ecis = []
  let separators = []
  let mut corrected = 0
  for slot in slots {
    let p = match slot {
      Some(p) => p
      None => raise InvalidCodeword("missing append part")
    }
    let offset = payload.length()
    ecis.push((offset, 3))
    for (pos, eci) in p.ecis {
      ecis.push((offset + pos, eci))
    }
    for pos in p.separators {
      separators.push(offset + pos)
    }
    for byte in p.payload {
      payload.push(byte)
    }
    corrected += p.corrected_codewords
  }
  {
    payload: Bytes::from_array(payload),
    ecis,
    separators,
    gs1: parts[0].gs1,
    macro_kind: 0,
    reader_programming: false,
    append: None,
    corrected_codewords: corrected,
  }
}
