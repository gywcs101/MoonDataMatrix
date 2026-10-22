///|
test "X12 base alphabet and EDIFACT bit packing" {
  assert_eq(x12_value(13), Some(0))
  assert_eq(x12_value(97), None)
  let out = []
  append_edifact(out, [36, 54, 26, 1])
  assert_eq(out, [147, 102, 129])
}
