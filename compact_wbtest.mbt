///|
test "C40 Text shift tables and triplet vector" {
  assert_eq(c40_values(65, false), [14])
  assert_eq(c40_values(97, true), [14])
  assert_eq(c40_values(255, false), [1, 30, 2, 31])
  assert_eq(c40_values(0, true), [0, 0])
  assert_eq(compact_candidate(b"ABC", false), [230, 89, 233, 254])
  assert_eq(compact_candidate(b"abc", true), [239, 89, 233, 254])
  for n in 1..<20 {
    ignore(encode_bytes(Bytes::make(n, 65)))
  }
}
