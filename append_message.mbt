///|
fn append_segment(out : Array[MessageSegment], item : MessageSegment) -> Unit {
  if !out.is_empty() {
    let i = out.length() - 1
    match (out[i], item) {
      (Text(a, e), Text(b, f)) if e == f => {
        out[i] = Text(a + b, e)
        return
      }
      (Data(a), Data(b)) => {
        out[i] = Data(a + b)
        return
      }
      _ => ()
    }
  }
  out.push(item)
}

///|
/// Split a segmented message, preserving text character boundaries and ECI state.
pub fn encode_append_message(
  segments : Array[MessageSegment],
  file_id1 : Int,
  file_id2 : Int,
  options? : MessageOptions = MessageOptions::new(),
) -> Array[Symbol] raise EncodeError {
  if options.append is Some(_) ||
    !valid_append({ index: 1, count: 2, file_id1, file_id2, }) {
    raise InvalidOption("invalid automatic append header")
  }
  let single = Some(encode_message(segments, options~)) catch {
    CapacityExceeded => None
    e => raise e
  }
  if single is Some(s) {
    return [s]
  }
  if options.macro_kind != 0 || options.reader_programming {
    raise InvalidOption("control message must fit one symbol")
  }
  let atoms : Array[(MessageSegment, Int)] = []
  let mut active = 3
  for s in segments {
    match s {
      Text(t, e) =>
        for c in t {
          atoms.push((Text(c.to_string(), e), active))
          active = e
        }
      Data(b) =>
        for v in b {
          atoms.push((Data(Bytes::from_array([v])), active))
        }
      Eci(e) => {
        atoms.push((s, active))
        active = e
      }
      Fnc1 => atoms.push((s, active))
    }
  }
  let parts : Array[Array[MessageSegment]] = []
  let mut offset = 0
  while offset < atoms.length() {
    if parts.length() >= 16 {
      raise CapacityExceeded
    }
    let mut lo = 1
    let mut hi = atoms.length() - offset
    let mut best : Array[MessageSegment] = []
    let mut count = 0
    while lo <= hi {
      let n = (lo + hi) / 2
      let candidate : Array[MessageSegment] = []
      if !options.gs1 && offset > 0 {
        candidate.push(Eci(atoms[offset].1))
      }
      for j in offset..<(offset + n) {
        append_segment(candidate, atoms[j].0)
      }
      let fits = try {
        ignore(
          encode_message(
            candidate,
            options=MessageOptions::new(
              symbol=options.symbol,
              gs1=options.gs1,
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
        best = candidate
        count = n
        lo = n + 1
      } else {
        hi = n - 1
      }
    }
    if count == 0 {
      raise CapacityExceeded
    }
    parts.push(best)
    offset += count
  }
  let result = []
  for i in 0..<parts.length() {
    result.push(
      encode_message(
        parts[i],
        options=MessageOptions::new(
          symbol=options.symbol,
          gs1=options.gs1,
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
