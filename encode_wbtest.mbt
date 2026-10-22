///|
test "ASCII digits upper shift and UTF8 entry points" {
  assert_eq(ascii_codewords(b"12A\x00\xff"), [142, 66, 1, 235, 128])
  assert_eq(encode_bytes(b"").width(), 10)
  assert_eq(encode_text("Hello").width(), 14)
  assert_true(encode_text("中文🙂").width() > 10)
  let s = encode_bytes(b"123456")
  assert_eq(s.width(), 10)
  let copy = s.matrix()
  copy[0][0] = false
  assert_eq(s.module_at(0, 0), Some(true))
  assert_eq(s.module_at(-1, 0), None)
}
