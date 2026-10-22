///|
test "Base256 length boundaries and absolute positions" {
  for n in [1, 249, 250, 1555] {
    let data = Bytes::make(n, 255)
    let out = [241, 27]
    append_base256(out, data, 0, n)
    assert_eq(out[2], 231)
    let length = (out[3] - (149 * 4 % 255 + 1) + 256) % 256
    assert_eq(length, if n <= 249 { n } else { n / 250 + 249 })
    assert_eq(out.length(), n + (if n <= 249 { 4 } else { 5 }))
  }
  assert_eq(encode_bytes(Bytes::make(1555, 255)).width(), 144)
}

///|
fn append_base256(
  out : Array[Int],
  data : Bytes,
  start : Int,
  end : Int,
) -> Unit {
  let count = end - start
  out.push(231)
  if count <= 249 {
    out.push(randomized(count, out.length() + 1))
  } else {
    out.push(randomized(count / 250 + 249, out.length() + 1))
    out.push(randomized(count % 250, out.length() + 1))
  }
  for i in start..<end {
    out.push(randomized(data[i].to_int(), out.length() + 1))
  }
}
