///|
test "mixed message append restores text bytes and controls" {
  let segments = [
    Text("中文中文中文中文中文中文", 29),
    Text("日本語日本語日本語", 20),
    Text("🙂🙂🙂🙂", 26),
    Fnc1,
    Data(b"\x00\xff"),
  ]
  let whole = decode_matrix(encode_message(segments).matrix())
  let parts = encode_append_message(
    segments,
    12,
    34,
    options=MessageOptions::new(symbol={ shape: Fixed(26, 26), }),
  )
  assert_true(parts.length() > 1)
  let decoded = parts.map(fn(s) raise { decode_matrix(s.matrix()) })
  let result = assemble(decoded)
  assert_eq(result.bytes(), whole.bytes())
  assert_eq(result.fnc1_positions(), whole.fnc1_positions())
  let textparts = encode_append_message(
    [
      Text("中文中文中文中文中文中文", 29),
      Text("日本語日本語日本語", 20),
      Text("🙂🙂🙂🙂", 26),
    ],
    1,
    2,
    options=MessageOptions::new(symbol={ shape: Fixed(26, 26), }),
  )
  assert_eq(
    assemble(textparts.map(fn(s) raise { decode_matrix(s.matrix()) })).text(),
    "中文中文中文中文中文中文日本語日本語日本語🙂🙂🙂🙂",
  )
}

///|
test "published control codeword assignments independent of encoder" {
  // Data Matrix control assignments: Zint manual 6.6.1, original vectors.
  let reader = decode_data([234, 66], 0)
  assert_true(reader.reader_programming)
  assert_eq(reader.bytes(), b"A")
  let envelope = decode_data([237, 66], 0)
  assert_eq(envelope.macro_kind, 6)
  assert_eq(envelope.bytes(), b"[)>\x1e06\x1dA\x1e\x04")
  let append = decode_data([233, 15, 1, 2, 66], 0)
  assert_true(
    append.append == Some({ index: 1, count: 2, file_id1: 1, file_id2: 2, }),
  )
  assert_eq(append.bytes(), b"A")
}

///|
test "segmented append ECI state GS1 and invalid options" {
  let opts = MessageOptions::new(symbol={ shape: Fixed(26, 26), })
  let data = Bytes::make(100, 255)
  let parts = encode_append_message([Eci(899), Data(data)], 1, 2, options=opts)
  assert_eq(
    assemble(parts.map(fn(s) raise { decode_matrix(s.matrix()) })).bytes(),
    data,
  )
  let gs = encode_append_message(
    [
      Text("010123456789012810ABCDEFGHIJKLMNOPQRSTUVWXYZ", 3),
      Fnc1,
      Text("21SERIALABCDEFGHIJKLMNOPQRSTUVWXYZ", 3),
    ],
    1,
    2,
    options=MessageOptions::new(symbol={ shape: Fixed(26, 26), }, gs1=true),
  )
  assert_true(gs.length() > 1)
  for s in gs {
    assert_true(decode_matrix(s.matrix()).gs1)
  }
  let utf = encode_append_message(
    [Text("中文🙂中文🙂中文🙂中文🙂中文🙂中文🙂", 25)],
    1,
    2,
    options=opts,
  )
  assert_eq(
    assemble(utf.map(fn(s) raise { decode_matrix(s.matrix()) })).text(),
    "中文🙂中文🙂中文🙂中文🙂中文🙂中文🙂",
  )
  for
    o in [
      MessageOptions::new(symbol={ shape: Fixed(10, 10), }),
      MessageOptions::new(
        append=Some({ index: 1, count: 2, file_id1: 1, file_id2: 2, }),
      ),
    ] {
    let failed = try {
      ignore(encode_append_message([Data(data)], 1, 2, options=o))
      false
    } catch {
      _ => true
    }
    assert_true(failed)
  }
}
