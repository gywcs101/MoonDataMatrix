///|
test "charset mapping round trips and strict unicode" {
  for
    eci in [
      2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 15, 16, 17, 18, 20, 21, 22, 23, 24,
      27, 28, 29, 30, 31, 32,
    ] {
    let (dec, _) = tables(eci)
    for i in 0..<(dec.length() / 5) {
      let encoded = integer(dec, i * 5, 2)
      let out : Array[Byte] = []
      emit(out, encoded, if encoded < 256 { 1 } else { 2 }, false)
      let text = decode(Bytes::from_array(out), eci)
      assert_eq(decode(encode(text, eci), eci), text)
    }
  }
  for eci in [25, 26, 32, 33, 34, 35] {
    let text = "A中文🙂\u{feff}\u{10ffff}"
    assert_eq(decode(encode(text, eci), eci), text)
  }
  for
    (eci, data) in [
      (26, b"\xff"),
      (25, b"\xd8\x00"),
      (33, b"\x00\xdc"),
      (34, b"\xff\xff\xff\xff"),
      (32, b"\x81\x30\x81"),
      (29, b"\xff"),
      (27, b"\x80"),
    ] {
    let failed = try {
      ignore(decode(data, eci))
      false
    } catch {
      _ => true
    }
    assert_true(failed)
  }
  let failed = try {
    ignore(encode("🙂", 29))
    false
  } catch {
    _ => true
  }
  assert_true(failed)
}

///|
test "strict conversion rejects lossy JIS aliases" {
  for text in ["¥", "‾"] {
    let failed = try {
      ignore(encode(text, 20))
      false
    } catch {
      _ => true
    }
    assert_true(failed)
  }
}
