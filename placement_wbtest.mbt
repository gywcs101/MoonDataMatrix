///|
test "all thirty placement maps include finder borders" {
  for s in sizes {
    let symbol = place(Array::make(s.capacity + s.blocks * s.ecc, 0), s)
    assert_eq(symbol.width(), s.width)
    assert_eq(symbol.height(), s.height)
    for x in 0..<s.width {
      assert_eq(symbol.module_at(x, s.height - 1), Some(true))
    }
    for y in 1..<s.height {
      assert_eq(symbol.module_at(0, y), Some(true))
    }
  }
}
