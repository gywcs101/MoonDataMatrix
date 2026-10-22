///|
test "upstream Reed Solomon vector and generator" {
  assert_eq(generator(5), [1, 62, 111, 15, 48, 228])
  assert_eq(error_code([23, 40, 11], sizes[0]), [255, 207, 37, 244, 81])
  for a in 1..<256 {
    let mut p = 1
    for _ in 0..<255 {
      p = gf_mul(p, a)
    }
    assert_eq(p, 1)
  }
}
