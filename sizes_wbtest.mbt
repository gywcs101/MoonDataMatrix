///|
test "classic sizes and block capacity invariants" {
  assert_eq(sizes.length(), 30)
  for s in sizes {
    let area = (s.width - 2 * s.regions_x) * (s.height - 2 * s.regions_y)
    let bits = (s.capacity + s.blocks * s.ecc) * 8
    assert_true(area == bits || area == bits + 4)
  }
  assert_eq(select_size(3, { shape: Square, }).width, 10)
  assert_eq(select_size(1558, { shape: Square, }).width, 144)
  assert_eq(select_size(5, { shape: Rectangle, }).width, 18)
}
