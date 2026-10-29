// Port of datamatrix-rs GenericDataEncoder and six encodation implementations.
// Copyright 2021 Jannik Schürg, MIT; see THIRD_PARTY_NOTICES.md.

///|
priv struct Encoder {
  data : Bytes
  options : EncodeOptions
  out : Array[Int]
  mut pos : Int
  mut mode : Int
  mut pending : Int?
  mut switches : Array[(Int, Int)]
}

///|
fn Encoder::left(self : Encoder) -> Int {
  self.data.length() - self.pos
}

///|
fn Encoder::space(self : Encoder, extra : Int) -> Int raise EncodeError {
  match space_left(self.out.length() + extra, self.options) {
    Some(v) => v
    None => raise CapacityExceeded
  }
}

///|
fn Encoder::ascii_end(self : Encoder) -> Unit {
  self.mode = 0
  self.switches = [(0, 0)]
}

///|
fn Encoder::eat(self : Encoder) -> Int {
  let c = self.data[self.pos].to_int()
  self.pos += 1
  c
}

///|
fn Encoder::switch_mode(self : Encoder) -> Bool {
  let left = self.left()
  let mode = if left > 0 && left == self.switches[0].0 {
    let (_, mode) = self.switches.remove(0)
    mode
  } else {
    self.mode
  }
  if mode != self.mode {
    self.mode = mode
    if mode != 0 {
      self.pending = Some([0, 231, 240, 238, 230, 239][mode])
    }
    true
  } else {
    false
  }
}

///|
fn Encoder::two_digits(self : Encoder) -> Bool {
  self.left() >= 2 &&
  digit(self.data[self.pos]) &&
  digit(self.data[self.pos + 1])
}

///|
fn Encoder::ascii(self : Encoder) -> Unit {
  while true {
    if self.switch_mode() {
      return
    }
    if self.two_digits() {
      let a = self.eat()
      let b = self.eat()
      self.out.push((a - 48) * 10 + b - 48 + 130)
      continue
    }
    if self.left() == 0 {
      return
    }
    let c = self.eat()
    if c <= 127 {
      self.out.push(c + 1)
    } else {
      self.out.push(235)
      self.out.push(c - 127)
    }
  }
}

///|
fn Encoder::base256(self : Encoder) -> Unit raise EncodeError {
  let start = self.out.length()
  self.out.push(0)
  while true {
    if self.left() > 0 {
      self.out.push(self.eat())
    }
    if self.left() == 0 || self.switch_mode() {
      break
    }
  }
  let left = self.space(0)
  if self.left() > 0 || left > 0 {
    let count = self.out.length() - start - 1
    if count <= 249 {
      self.out[start] = count
    } else if count <= 1555 {
      self.out[start] = count / 250 + 249
      self.out.insert(start + 1, count % 250)
    } else {
      raise CapacityExceeded
    }
  }
  for i in start..<self.out.length() {
    self.out[i] = randomized(self.out[i], i + 1)
  }
  if self.left() == 0 {
    self.ascii_end()
  }
}

///|
fn Encoder::c40_end(
  self : Encoder,
  last : Int,
  buffer : Array[Int],
) -> Unit raise EncodeError {
  let switching = self.left() > 0
  if !switching {
    let size_left = self.space(buffer.length())
    let left = size_left + buffer.length()
    if left == 2 && buffer.length() == 2 {
      buffer.push(0)
      append_triplets(self.out, buffer)
      return
    }
    if left == 2 && buffer.length() == 1 {
      self.out.push(254)
      self.ascii_end()
      self.pos -= 1
      return
    }
    if left == 1 && buffer.length() == 1 && last <= 127 {
      self.ascii_end()
      self.pos -= 1
      return
    }
  }
  if !buffer.is_empty() {
    buffer.push(1)
    if buffer.length() == 2 {
      buffer.push(30)
    }
    append_triplets(self.out, buffer)
    if !switching {
      self.ascii_end()
    }
  }
  if self.left() > 0 {
    if self.left() == 2 && self.two_digits() {
      let space = self.space(1)
      self.ascii_end()
      if space >= 1 {
        self.out.push(254)
      }
      return
    }
    self.out.push(254)
  } else if self.space(0) > 0 {
    self.out.push(254)
    if !switching {
      self.ascii_end()
    }
  }
}

///|
fn Encoder::c40(self : Encoder, text : Bool) -> Unit raise EncodeError {
  let buffer = []
  let mut last = 0
  while self.left() > 0 {
    let c = self.eat()
    if buffer.is_empty() &&
      c >= 48 &&
      c <= 57 &&
      self.left() == 1 &&
      digit(self.data[self.pos]) {
      self.pos -= 1
      break
    }
    for v in c40_values(c, text) {
      buffer.push(v)
    }
    last = c
    while buffer.length() >= 3 {
      append_triplets(self.out, [buffer[0], buffer[1], buffer[2]])
      for _ in 0..<3 {
        ignore(buffer.remove(0))
      }
    }
    if self.switch_mode() {
      break
    }
  }
  self.c40_end(last, buffer)
}

///|
fn Encoder::x12(self : Encoder) -> Unit raise EncodeError {
  let mut switched = false
  while self.left() >= 3 {
    let values = []
    for _ in 0..<3 {
      match x12_value(self.eat()) {
        Some(v) => values.push(v)
        None => raise InvalidOption("internal X12 planning mismatch")
      }
    }
    append_triplets(self.out, values)
    if self.switch_mode() {
      switched = true
      break
    }
  }
  let one = self.left() <= 2 && ascii_size(self.data, self.pos) == 1
  if one && self.space(1) == 0 {
    self.ascii_end()
    return
  }
  if self.left() > 0 || self.space(0) > 0 {
    if !switched {
      self.ascii_end()
    }
    self.out.push(254)
  }
}

///|
fn Encoder::edifact_end(
  self : Encoder,
  symbols : Array[Int],
) -> Unit raise EncodeError {
  if symbols.length() + self.left() <= 4 {
    let rest = Array::makei(symbols.length() + self.left(), fn(i) {
      if i < symbols.length() {
        symbols[i].to_byte()
      } else {
        self.data[self.pos + i - symbols.length()]
      }
    })
    let size = ascii_size(Bytes::from_array(rest), 0)
    if size <= 2 {
      match space_left(self.out.length() + size, self.options) {
        Some(space) =>
          if space + size <= 2 && size <= space + size {
            self.pos -= symbols.length()
            self.ascii_end()
            return
          }
        None => ()
      }
    }
  }
  if symbols.is_empty() {
    if self.left() == 0 {
      if self.space(0) > 0 {
        self.out.push(124)
        self.ascii_end()
      }
    } else {
      self.out.push(124)
    }
  } else {
    if self.left() == 0 {
      if self.space(symbols.length()) > 0 || symbols.length() == 3 {
        symbols.push(31)
        self.ascii_end()
      }
    } else {
      symbols.push(31)
    }
    append_edifact(self.out, symbols)
  }
}

///|
fn Encoder::edifact(self : Encoder) -> Unit raise EncodeError {
  let symbols = []
  while self.left() > 0 {
    symbols.push(self.eat())
    if symbols.length() == 4 {
      append_edifact(self.out, symbols)
      symbols.clear()
      if self.switch_mode() {
        break
      }
    } else if self.switch_mode() {
      break
    }
  }
  self.edifact_end(symbols)
}

///|
fn planned_codewords(
  data : Bytes,
  eci : Bool,
  options : EncodeOptions,
) -> Array[Int] raise EncodeError {
  planned_with_prefix(data, if eci { [241, 27] } else { [] }, options)
}

///|
fn planned_with_prefix(
  data : Bytes,
  out : Array[Int],
  options : EncodeOptions,
) -> Array[Int] raise EncodeError {
  ignore(select_size(0, options))
  let enc : Encoder = {
    data,
    options,
    out,
    pos: 0,
    mode: 0,
    pending: None,
    switches: optimize(data, out.length(), options),
  }
  let mut stalled = 0
  while enc.left() > 0 {
    match enc.pending {
      Some(v) => {
        out.push(v)
        enc.pending = None
      }
      None => ()
    }
    let before = out.length()
    match enc.mode {
      0 => enc.ascii()
      1 => enc.base256()
      2 => enc.edifact()
      3 => enc.x12()
      4 => enc.c40(false)
      _ => enc.c40(true)
    }
    if out.length() - before <= 1 {
      stalled += 1
      if stalled > 5 {
        raise InvalidOption("internal encoder failed to make progress")
      }
    } else {
      stalled = 0
    }
  }
  let s = select_size(out.length(), options)
  if s.capacity > out.length() && enc.mode != 0 {
    out.push(254)
  }
  out
}
