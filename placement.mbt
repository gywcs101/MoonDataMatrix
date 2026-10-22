// Adapted from datamatrix-rs placement.rs, IndexTraversal (MIT).

///|
fn place(data : Array[Int], s : Size) -> Symbol {
  let w = s.width - 2 * s.regions_x
  let h = s.height - 2 * s.regions_y
  let cells = Array::make(w * h, -1)
  let mut pos = 0
  fn write(points : Array[(Int, Int)]) {
    let value = data[pos]
    pos += 1
    for b in 0..<8 {
      let (r, c) = points[b]
      let mut r = r
      let mut c = c
      if r < 0 {
        r += h
        c += 4 - (h + 4) % 8
      }
      if c < 0 {
        c += w
        r += 4 - (w + 4) % 8
      }
      if r >= h {
        r -= h
      }
      cells[r * w + c] = (value >> (7 - b)) & 1
    }
  }
  fn utah(r : Int, c : Int) {
    write([
      (r - 2, c - 2),
      (r - 2, c - 1),
      (r - 1, c - 2),
      (r - 1, c - 1),
      (r - 1, c),
      (r, c - 2),
      (r, c - 1),
      (r, c),
    ])
  }
  let mut r = 4
  let mut c = 0
  while true {
    if r == h && c == 0 {
      write([
        (h - 1, 0),
        (h - 1, 1),
        (h - 1, 2),
        (0, w - 2),
        (0, w - 1),
        (1, w - 1),
        (2, w - 1),
        (3, w - 1),
      ])
    }
    if r == h - 2 && c == 0 && w % 4 != 0 {
      write([
        (h - 3, 0),
        (h - 2, 0),
        (h - 1, 0),
        (0, w - 4),
        (0, w - 3),
        (0, w - 2),
        (0, w - 1),
        (1, w - 1),
      ])
    }
    if r == h - 2 && c == 0 && w % 8 == 4 {
      write([
        (h - 3, 0),
        (h - 2, 0),
        (h - 1, 0),
        (0, w - 2),
        (0, w - 1),
        (1, w - 1),
        (2, w - 1),
        (3, w - 1),
      ])
    }
    if r == h + 4 && c == 2 && w % 8 == 0 {
      write([
        (h - 1, 0),
        (h - 1, w - 1),
        (0, w - 3),
        (0, w - 2),
        (0, w - 1),
        (1, w - 3),
        (1, w - 2),
        (1, w - 1),
      ])
    }
    while true {
      if r < h && c >= 0 && cells[r * w + c] < 0 {
        utah(r, c)
      }
      r -= 2
      c += 2
      if !(r >= 0 && c < w) {
        break
      }
    }
    r += 1
    c += 3
    while true {
      if r >= 0 && c < w && cells[r * w + c] < 0 {
        utah(r, c)
      }
      r += 2
      c -= 2
      if !(r < h && c >= 0) {
        break
      }
    }
    r += 3
    c += 1
    if !(r < h || c < w) {
      break
    }
  }
  if cells[w * h - 1] < 0 {
    cells[w * h - 1] = 1
    cells[(h - 2) * w + w - 2] = 1
  }
  let matrix = Array::make(s.width * s.height, false)
  let rw = w / s.regions_x
  let rh = h / s.regions_y
  for ry in 0..<s.regions_y {
    for rx in 0..<s.regions_x {
      let ox = rx * (rw + 2)
      let oy = ry * (rh + 2)
      for x in 0..<(rw + 2) {
        matrix[oy * s.width + ox + x] = x % 2 == 0
        matrix[(oy + rh + 1) * s.width + ox + x] = true
      }
      for y in 0..<rh {
        matrix[(oy + y + 1) * s.width + ox] = true
        matrix[(oy + y + 1) * s.width + ox + rw + 1] = y % 2 == 0
        for x in 0..<rw {
          matrix[(oy + y + 1) * s.width + ox + x + 1] = cells[(ry * rh + y) * w +
            rx * rw +
            x] ==
            1
        }
      }
    }
  }
  Symbol::{ w: s.width, h: s.height, cells: matrix, }
}

