// Adapted from datamatrix-rs errorcode/mod.rs and galois.rs (MIT).

///|
fn gf_mul(a : Int, b : Int) -> Int {
  let mut x = a
  let mut y = b
  let mut r = 0
  while y != 0 {
    if (y & 1) != 0 {
      r = r ^ x
    }
    y = y >> 1
    x = x << 1
    if (x & 256) != 0 {
      x = x ^ 301
    }
  }
  r
}

///|
fn generator(n : Int) -> Array[Int] {
  let mut g = [1]
  let mut root = 1
  for _ in 0..<n {
    root = gf_mul(root, 2)
    let next = Array::make(g.length() + 1, 0)
    for j in 0..<g.length() {
      next[j] = next[j] ^ g[j]
      next[j + 1] = next[j + 1] ^ gf_mul(g[j], root)
    }
    g = next
  }
  g
}

///|
fn error_code(data : Array[Int], s : Size) -> Array[Int] {
  let g = generator(s.ecc)
  let result = Array::make(s.blocks * s.ecc, 0)
  for block in 0..<s.blocks {
    let ecc = Array::make(s.ecc + 1, 0)
    for i = block; i < data.length(); i = i + s.blocks {
      let k = data[i] ^ ecc[0]
      for j in 0..<s.ecc {
        ecc[j] = ecc[j + 1] ^ gf_mul(k, g[j + 1])
      }
    }
    for j in 0..<s.ecc {
      result[block + j * s.blocks] = ecc[j]
    }
  }
  result
}
