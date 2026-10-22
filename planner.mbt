// Conservative segment planner. Packing maps are adapted from datamatrix-rs.
// This planner is original; it does not yet reproduce upstream end-of-symbol optimizations.

///|
fn planned_codewords(data : Bytes, eci : Bool) -> Array[Int] {
  let n = data.length()
  let cost = Array::make(n + 1, 100000)
  let previous = Array::make(n + 1, 0)
  let modes = Array::make(n + 1, 0)
  cost[0] = 0
  fn relax(start : Int, end : Int, mode : Int, length : Int) {
    if cost[start] + length < cost[end] {
      cost[end] = cost[start] + length
      previous[end] = start
      modes[end] = mode
    }
  }
  for i in 0..<n {
    relax(i, i + 1, 0, if data[i].to_int() < 128 { 1 } else { 2 })
    if i + 1 < n &&
      data[i] >= b'0' &&
      data[i] <= b'9' &&
      data[i + 1] >= b'0' &&
      data[i + 1] <= b'9' {
      relax(i, i + 2, 0, 1)
    }
    let mut c40 = 0
    let mut text = 0
    let mut x12 = true
    let mut edi = true
    for j in i..<n {
      let c = data[j].to_int()
      let len = j - i + 1
      if len <= 1555 {
        relax(i, j + 1, 2, len + (if len <= 249 { 2 } else { 3 }))
      }
      c40 += c40_values(c, false).length()
      text += c40_values(c, true).length()
      if c40 % 3 == 0 {
        relax(i, j + 1, 3, 2 + c40 / 3 * 2)
      }
      if text % 3 == 0 {
        relax(i, j + 1, 4, 2 + text / 3 * 2)
      }
      x12 = x12 && x12_value(c) != None
      edi = edi && c >= 32 && c <= 94
      if x12 && len % 3 == 0 {
        relax(i, j + 1, 5, 2 + len / 3 * 2)
      }
      // Ending a complete packed group with 31 avoids ambiguous <=2-word tails.
      if edi && len % 4 == 3 {
        relax(i, j + 1, 6, 1 + (len + 1) / 4 * 3)
      }
    }
  }
  let segments = []
  let mut end = n
  while end > 0 {
    let start = previous[end]
    segments.push((start, end, modes[end]))
    end = start
  }
  let out = if eci { [241, 27] } else { [] }
  for k = segments.length() - 1; k >= 0; k = k - 1 {
    let (start, end, mode) = segments[k]
    match mode {
      0 =>
        for b in ascii_codewords(data[start:end].to_owned()) {
          out.push(b)
        }
      2 => append_base256(out, data, start, end)
      3 | 4 | 5 => {
        out.push(if mode == 3 { 230 } else if mode == 4 { 239 } else { 238 })
        let values = []
        for j in start..<end {
          if mode == 5 {
            values.push(x12_value(data[j].to_int()).unwrap())
          } else {
            for v in c40_values(data[j].to_int(), mode == 4) {
              values.push(v)
            }
          }
        }
        append_triplets(out, values)
        out.push(254)
      }
      _ => {
        out.push(240)
        let values = Array::makei(end - start, fn(j) {
          data[start + j].to_int()
        })
        values.push(31)
        append_edifact(out, values)
      }
    }
  }
  out
}
