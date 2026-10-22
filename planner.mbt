// Port of datamatrix-rs encodation/planner/{ascii,base256,c40,text,x12,edifact,
// generic,shortest_path,frac}.rs at af189538. MIT, copyright Jannik Schürg.
// Fractions use the upstream fixed denominator 12. Mode indices follow index().

///|
priv struct Plan {
  mode : Int
  data : Bytes
  options : EncodeOptions
  mut pos : Int
  mut written : Int
  mut cost : Int
  extra : Int
  mut values : Int
  mut ahead : Int
  mut last : Int
  mut tail : Int
  mut two_digits : Bool
  switches : Array[(Int, Int)]
}

///|
fn new_plan(
  mode : Int,
  data : Bytes,
  options : EncodeOptions,
  pos : Int,
  written : Int,
  extra : Int,
  switches : Array[(Int, Int)],
) -> Plan {
  {
    mode,
    data,
    options,
    pos,
    written: written + (if mode == 1 { 1 } else { 0 }),
    cost: if mode == 1 {
      12
    } else {
      0
    },
    extra,
    values: 0,
    ahead: 0,
    last: 0,
    tail: 0,
    two_digits: false,
    switches,
  }
}

///|
fn Plan::copy(self : Plan) -> Plan {
  { ..self, switches: self.switches.copy(), }
}

///|
fn space_left(written : Int, options : EncodeOptions) -> Int? {
  Some(select_size(written, options).capacity - written) catch {
    _ => None
  }
}

///|
fn Plan::space(self : Plan, extra : Int) -> Int? {
  space_left(self.written + extra, self.options)
}

///|
fn ceil_cost(cost : Int) -> Int {
  (cost + 11) / 12 * 12
}

///|
fn digit(c : Byte) -> Bool {
  c >= b'0' && c <= b'9'
}

///|
fn ascii_size(data : Bytes, start : Int) -> Int {
  ascii_codewords(data[start:].to_owned()).length()
}

///|
fn Plan::switch_cost(self : Plan) -> Int? {
  let cost = self.cost + self.extra
  match self.mode {
    0 => Some(ceil_cost(cost))
    1 => Some(cost + (if self.values >= 250 { 12 } else { 0 }))
    2 => Some(ceil_cost(cost + (if self.values == 3 { 0 } else { 9 })))
    3 => if self.values == 0 { Some(cost + 12) } else { None }
    _ => Some(cost + (if self.values == 0 { 12 } else { 36 }))
  }
}

///|
fn Plan::total_cost(self : Plan) -> Int {
  let cost = self.cost + self.extra
  let end = self.pos == self.data.length()
  match self.mode {
    0 => cost
    1 =>
      cost +
      (if end && self.space(0).unwrap_or(1) > 0 && self.values >= 250 {
        12
      } else {
        0
      })
    2 => {
      if !end || self.tail > 0 {
        return cost
      }
      let w = self.values
      let space = self.space(w).unwrap_or(0)
      let trailing = if w == 0 {
        if space > 2 {
          1
        } else {
          0
        }
      } else {
        let n = if space > 0 || w == 3 { w + 1 } else { w }
        if n < 3 {
          n
        } else {
          3
        }
      }
      cost - 9 * w + 12 * trailing
    }
    3 =>
      cost +
      (if end &&
        self.tail == 0 &&
        self.values == 0 &&
        self.space(0).unwrap_or(0) > 0 {
        12
      } else {
        0
      })
    _ => {
      if !end {
        return cost + 8 * self.values
      }
      if self.two_digits {
        return cost + 12 * self.tail
      }
      let extra = if self.values == 2 {
        if self.space(2).unwrap_or(0) == 0 {
          2
        } else {
          3
        }
      } else if self.values == 1 {
        let left = self.space(1).unwrap_or(0)
        let ascii = if self.last <= 127 { 1 } else { 2 }
        if left == 0 {
          if ascii == 1 {
            1
          } else {
            1 + ascii
          }
        } else if left == 1 {
          1 + ascii
        } else {
          3
        }
      } else if self.space(0).unwrap_or(0) > 0 {
        1
      } else {
        0
      }
      cost + 12 * extra
    }
  }
}

///|
fn Plan::unlatch_written(self : Plan) -> Int {
  self.written +
  (match self.mode {
    0 => 0
    1 => if self.values >= 250 { 1 } else { 0 }
    2 => if self.values + 1 < 3 { self.values + 1 } else { 3 }
    3 => 1
    _ => if self.values > 0 { 3 } else { 1 }
  })
}

///|
fn base_set(c : Byte, text : Bool) -> Bool {
  c == b' ' ||
  digit(c) ||
  (if text { c >= b'a' && c <= b'z' } else { c >= b'A' && c <= b'Z' })
}

///|
fn unbeatable_strike(data : Bytes, pos : Int, text : Bool) -> Int {
  let mut count = 0
  let mut digits = 0
  for i in pos..<data.length() {
    let c = data[i]
    if !base_set(c, text) {
      break
    }
    count += 1
    if digit(c) {
      digits += 1
      if digits == 7 {
        count -= digits
        break
      }
    } else {
      digits = 0
    }
  }
  count / 3 * 3
}

///|
// Return (end, unbeatable), or None if this mode cannot consume the next byte.
fn Plan::step(self : Plan) -> (Bool, Bool)? {
  let n = self.data.length()
  match self.mode {
    0 => {
      if self.ahead == 0 {
        let mut count = 0
        for i in self.pos..<n {
          if !digit(self.data[i]) {
            break
          }
          count += 1
        }
        self.ahead = count / 2 * 2
        self.written += self.ahead / 2
      }
      let unbeatable = self.ahead > 0
      let end = self.pos == n
      if !end {
        let c = self.data[self.pos].to_int()
        self.pos += 1
        if self.ahead > 0 {
          self.ahead -= 1
          self.cost += 6
        } else {
          let count = if c <= 127 { 1 } else { 2 }
          self.cost += count * 12
          self.written += count
        }
      }
      Some((end, unbeatable))
    }
    1 => {
      let end = self.pos == n
      if !end {
        self.pos += 1
        self.values += 1
        self.cost += 12
        self.written += 1
        if self.values == 1556 {
          return None
        }
      }
      Some((end, false))
    }
    2 => {
      let end = self.pos == n
      if !end {
        if self.values == 0 && n - self.pos <= 4 && self.tail == 0 {
          let size = ascii_size(self.data, self.pos)
          if size <= 2 {
            let left = match self.space(size) {
              Some(v) => v
              None => return None
            }
            if left + size <= 2 {
              self.tail = size * 12 / (n - self.pos)
            }
          }
        }
        let c = self.data[self.pos].to_int()
        if self.tail == 0 && !(c >= 32 && c <= 94) {
          return None
        }
        self.pos += 1
        if self.tail > 0 {
          self.cost += self.tail
        } else {
          self.cost += 9
          self.values = (self.values + 1) % 4
          if self.values == 0 {
            self.written += 3
          }
        }
      }
      Some((end, self.tail > 0))
    }
    3 => {
      let end = self.pos == n
      if !end {
        if self.values == 0 && n - self.pos <= 2 && self.tail == 0 {
          let size = ascii_size(self.data, self.pos)
          if size == 1 {
            let left = match self.space(size) {
              Some(v) => v
              None => return None
            }
            if left <= 1 {
              if left == 1 {
                self.cost += 12
              }
              self.tail = size * 12 / (n - self.pos)
            }
          }
          if self.tail == 0 {
            self.cost += 12
            self.tail = size * 12 / (n - self.pos)
          }
        }
        if self.tail == 0 && x12_value(self.data[self.pos].to_int()) == None {
          return None
        }
        self.pos += 1
        if self.tail > 0 {
          self.cost += self.tail
        } else {
          self.cost += 8
          self.values = (self.values + 1) % 3
          if self.values == 0 {
            self.written += 2
          }
        }
      }
      Some((end, self.tail > 0))
    }
    _ => {
      if self.values == 0 && self.ahead == 0 {
        if n - self.pos == 2 &&
          digit(self.data[self.pos]) &&
          digit(self.data[self.pos + 1]) {
          let left = match self.space(1) {
            Some(v) => v
            None => return None
          }
          self.two_digits = true
          self.ahead = 2
          self.tail = if left >= 1 { 2 } else { 1 }
          self.written += self.tail
        }
        if !self.two_digits {
          self.ahead = unbeatable_strike(self.data, self.pos, self.mode == 5)
          self.written += self.ahead / 3 * 2
        }
      }
      let unbeatable = self.ahead > 0
      let end = self.pos == n
      if !end {
        self.last = self.data[self.pos].to_int()
        self.pos += 1
        if self.ahead > 0 {
          if !self.two_digits || self.values == 0 {
            self.values += 1
          }
          self.ahead -= 1
        } else {
          self.values += c40_values(self.last, self.mode == 5).length()
        }
        while self.values >= 3 {
          self.cost += 24
          if !unbeatable {
            self.written += 2
          }
          self.values -= 3
        }
      }
      Some((end, unbeatable))
    }
  }
}

///|
fn Plan::add_switches(
  self : Plan,
  list : Array[Plan],
  remaining : Int,
  as_start : Bool,
) -> Unit {
  let cost = match self.switch_cost() {
    Some(v) => v
    None => return
  }
  let written = self.unlatch_written()
  // Order exactly matches GenericPlan::add_switches (Text before C40).
  for mode in [0, 1, 2, 3, 5, 4] {
    if mode == self.mode {
      continue
    }
    let switches = if as_start { [] } else { self.switches.copy() }
    switches.push((remaining, mode))
    let latch = if mode == 0 { 0 } else { 1 }
    let next = new_plan(
      mode,
      self.data,
      self.options,
      self.pos,
      written + latch,
      cost + 12 * latch,
      switches,
    )
    if next.step() != None {
      list.push(next)
    }
  }
}

///|
fn prune_plans(list : Array[Plan]) -> Array[Plan] {
  // Rust's unstable equal-cost order is unspecified. Use the upstream final
  // tie preferences here as well, then retain insertion order for exact ties.
  // At most 36 candidate classes survive each iteration.
  for i in 1..<list.length() {
    let value = list[i]
    let mut j = i
    while j > 0 && plan_sort_key(list[j - 1]) > plan_sort_key(value) {
      list[j] = list[j - 1]
      j -= 1
    }
    list[j] = value
  }
  let seen = Array::make(36, false)
  let kept = []
  for p in list {
    let index = p.switches[0].1 * 6 + p.mode
    if !seen[index] {
      seen[index] = true
      kept.push(p)
    }
  }
  let mut start = 0
  while start + 1 < kept.length() {
    let first = kept[start]
    let mut i = start + 1
    let mut uncomparable = false
    while i < kept.length() {
      let second = kept[i]
      let cost = if first.mode == second.mode {
        Some(first.total_cost())
      } else {
        first
        .switch_cost()
        .map(fn(c) {
          c +
          (if second.mode == 0 {
            0
          } else if second.mode == 1 {
            24
          } else {
            12
          })
        })
      }
      match cost {
        None => {
          uncomparable = true
          break
        }
        Some(c) =>
          if c < second.total_cost() {
            ignore(kept.remove(i))
          } else {
            i += 1
          }
      }
    }
    if uncomparable {
      start += 1
    } else {
      break
    }
  }
  kept
}

///|
fn optimize(
  data : Bytes,
  written : Int,
  options : EncodeOptions,
) -> Array[(Int, Int)] raise EncodeError {
  let mut plans = [
    new_plan(0, data, options, 0, written, 0, [(data.length(), 0)]),
  ]
  for iteration in 0..<(data.length() + 1) {
    let next = []
    let mut at_end = false
    for p in plans {
      let before = p.copy()
      match p.step() {
        None =>
          before.add_switches(next, data.length() - iteration, iteration == 0)
        Some((end, unbeatable)) => {
          next.push(p)
          if !unbeatable && !end {
            before.add_switches(next, data.length() - iteration, iteration == 0)
          }
          if end {
            at_end = true
          }
        }
      }
    }
    plans = prune_plans(next)
    if plans.is_empty() {
      raise CapacityExceeded
    }
    if at_end {
      fn key(p : Plan) -> (Int, Int, Int) {
        let mut max_mode = 0
        for (_, mode) in p.switches {
          if mode > max_mode {
            max_mode = mode
          }
        }
        (ceil_cost(p.total_cost()), max_mode, p.switches.length())
      }
      let mut best = plans[0]
      for p in plans {
        if key(p) < key(best) {
          best = p
        }
      }
      let switches = best.switches.copy()
      switches.push((0, best.mode))
      if written == 0 && switches[0] == (data.length(), 0) {
        ignore(switches.remove(0))
      }
      return switches
    }
  }
  raise CapacityExceeded
}

///|
fn plan_sort_key(p : Plan) -> (Int, Int, Int) {
  let mut mode = 0
  for (_, m) in p.switches {
    if m > mode {
      mode = m
    }
  }
  (p.total_cost(), mode, p.switches.length())
}
