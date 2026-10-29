// GF(256) decoding: Berlekamp–Massey locator and syndrome linear solve.

///|
fn gf_pow(a : Int, n : Int) -> Int {
  let mut out = 1
  for _ in 0..<n {
    out = gf_mul(out, a)
  }
  out
}

///|
fn gf_div(a : Int, b : Int) -> Int {
  gf_mul(a, gf_pow(b, 254))
}

///|
fn syndromes(data : Array[Int], count : Int) -> Array[Int] {
  Array::makei(count, fn(i) {
    let x = gf_pow(2, i + 1)
    let mut y = 0
    for v in data {
      y = gf_mul(y, x) ^ v
    }
    y
  })
}

///|
fn correct_block(data : Array[Int], ecc : Int) -> Int raise DecodeError {
  let syn = syndromes(data, ecc)
  if syn.iter().all(fn(v) { v == 0 }) {
    return 0
  }
  let c = Array::make(ecc + 1, 0)
  let mut b = Array::make(ecc + 1, 0)
  c[0] = 1
  b[0] = 1
  let mut degree = 0
  let mut distance = 1
  let mut previous = 1
  for n in 0..<ecc {
    let mut discrepancy = syn[n]
    for i in 1..<(degree + 1) {
      discrepancy = discrepancy ^ gf_mul(c[i], syn[n - i])
    }
    if discrepancy == 0 {
      distance += 1
      continue
    }
    let old = c.copy()
    let factor = gf_div(discrepancy, previous)
    for j in 0..<(ecc + 1 - distance) {
      c[j + distance] = c[j + distance] ^ gf_mul(factor, b[j])
    }
    if 2 * degree <= n {
      degree = n + 1 - degree
      b = old
      previous = discrepancy
      distance = 1
    } else {
      distance += 1
    }
  }
  if degree == 0 || 2 * degree > ecc {
    raise CorrectionFailed
  }
  let positions = []
  let roots = []
  for pos in 0..<data.length() {
    let x = gf_pow(2, data.length() - 1 - pos)
    let inverse = gf_div(1, x)
    let mut value = 0
    for j = degree; j >= 0; j = j - 1 {
      value = gf_mul(value, inverse) ^ c[j]
    }
    if value == 0 {
      positions.push(pos)
      roots.push(x)
    }
  }
  if positions.length() != degree {
    raise CorrectionFailed
  }
  let rows = Array::makei(degree, fn(i) {
    let row = roots.map(fn(x) { gf_pow(x, i + 1) })
    row.push(syn[i])
    row
  })
  for col in 0..<degree {
    let mut pivot = col
    while pivot < degree && rows[pivot][col] == 0 {
      pivot += 1
    }
    if pivot == degree {
      raise CorrectionFailed
    }
    let tmp = rows[col]
    rows[col] = rows[pivot]
    rows[pivot] = tmp
    let divisor = rows[col][col]
    for j in col..<(degree + 1) {
      rows[col][j] = gf_div(rows[col][j], divisor)
    }
    for i in 0..<degree {
      if i == col {
        continue
      }
      let factor = rows[i][col]
      for j in col..<(degree + 1) {
        rows[i][j] = rows[i][j] ^ gf_mul(factor, rows[col][j])
      }
    }
  }
  for i in 0..<degree {
    data[positions[i]] = data[positions[i]] ^ rows[i][degree]
  }
  if !syndromes(data, ecc).iter().all(fn(v) { v == 0 }) {
    raise CorrectionFailed
  }
  degree
}

///|
fn correct_codewords(words : Array[Int], size : Size) -> Int raise DecodeError {
  let mut corrected = 0
  for block in 0..<size.blocks {
    let indices = []
    for i = block; i < size.capacity; i = i + size.blocks {
      indices.push(i)
    }
    for j in 0..<size.ecc {
      indices.push(size.capacity + j * size.blocks + block)
    }
    let data = indices.map(fn(i) { words[i] })
    corrected += correct_block(data, size.ecc)
    for i in 0..<indices.length() {
      words[indices[i]] = data[i]
    }
  }
  corrected
}
