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

///|
fn compact_candidate(data : Bytes, text : Bool) -> Array[Int] {
  let values = []
  let mut boundary = 0
  let mut value_boundary = 0
  for i in 0..<data.length() {
    for v in c40_values(data[i].to_int(), text) {
      values.push(v)
    }
    if values.length() % 3 == 0 {
      boundary = i + 1
      value_boundary = values.length()
    }
  }
  let out = [if text { 239 } else { 230 }]
  append_triplets(out, Array::makei(value_boundary, fn(i) { values[i] }))
  out.push(254)
  for v in ascii_codewords(data[boundary:].to_owned()) {
    out.push(v)
  }
  out
}
