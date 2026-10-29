///|
test "protocol control round trips" {
  for eci in [0, 26, 126, 127, 16382, 16383, 999999] {
    let d = decode_matrix(
      encode_message([Eci(eci), Data(b"ABC"), Eci(26), Data(b"xyz")]).matrix(),
    )
    assert_eq(d.bytes(), b"ABCxyz")
    assert_eq(d.eci_changes(), [(0, eci), (3, 26)])
  }
  let gs = decode_matrix(
    encode_gs1(b"010123456789012810BATCH\x1d21SERIAL").matrix(),
  )
  assert_true(gs.gs1)
  assert_eq(gs.bytes(), b"010123456789012810BATCH\x1d21SERIAL")
  assert_eq(gs.fnc1_positions(), [23])
  for envelope in [b"[)>\x1e05\x1dABC\x1e\x04", b"[)>\x1e06\x1dXYZ\x1e\x04"] {
    assert_eq(decode_matrix(encode_macro(envelope).matrix()).bytes(), envelope)
  }
  let rp = decode_matrix(
    encode_message(
      [Data(b"CFG")],
      options=MessageOptions::new(reader_programming=true),
    ).matrix(),
  )
  assert_true(rp.reader_programming)
  assert_eq(rp.bytes(), b"CFG")
  let sa : AppendHeader = { index: 2, count: 16, file_id1: 254, file_id2: 1, }
  let d = decode_matrix(
    encode_message(
      [Data(b"part")],
      options=MessageOptions::new(append=Some(sa)),
    ).matrix(),
  )
  assert_true(d.append == Some(sa))
}

///|
test "multilingual ECI text segments" {
  let symbol = encode_message([
    Text("中文", 29),
    Text("日本語", 20),
    Text("🙂", 32),
    Text("é", 3),
  ])
  assert_eq(decode_matrix(symbol.matrix()).text(), "中文日本語🙂é")
  assert_eq(decode_matrix(encode_bytes(b"\xe9").matrix()).text(), "é")
}

///|
test "append split and reassembly" {
  let text = "中文🙂".repeat(12)
  let symbols = encode_append_text(text, 1, 254, options={
    shape: Fixed(26, 26),
  })
  assert_true(symbols.length() > 1)
  let parts = symbols.map(s => decode_matrix(s.matrix()))
  for i in 0..<(parts.length() / 2) {
    let j = parts.length() - 1 - i
    let a = parts[i]
    parts[i] = parts[j]
    parts[j] = a
  }
  assert_eq(assemble(parts).text(), text)
  let bytes = Bytes::makei(220, fn(i) { i.to_byte() })
  let binary = encode_append_bytes(bytes, 2, 3, options={
    shape: Fixed(26, 26),
  }).map(s => decode_matrix(s.matrix()))
  assert_eq(assemble(binary).bytes(), bytes)
  let sixteen = []
  for i in 1..<17 {
    sixteen.push(
      decode_matrix(
        encode_message(
          [Data(b"A")],
          options=MessageOptions::new(
            append=Some({ index: i, count: 16, file_id1: 1, file_id2: 2, }),
          ),
        ).matrix(),
      ),
    )
  }
  assert_eq(assemble(sixteen).bytes(), Bytes::make(16, 65))
  sixteen[1] = sixteen[0]
  let failed = try {
    ignore(assemble(sixteen))
    false
  } catch {
    _ => true
  }
  assert_true(failed)
}

///|
test "control known vectors and incompatible options" {
  for
    (eci, expected) in [
      (126, [241, 127]),
      (127, [241, 128, 1]),
      (16382, [241, 191, 254]),
      (16383, [241, 192, 1, 1]),
      (999999, [241, 207, 63, 129]),
    ] {
    let out = []
    append_eci(out, eci)
    assert_eq(out, expected)
  }
  let c40 = decode_data([230, 10, 121, 254], 0)
  assert_eq(c40.bytes(), b"\x1d")
  assert_eq(c40.fnc1_positions(), [0])
  for
    opts in [
      MessageOptions::new(gs1=true, reader_programming=true),
      MessageOptions::new(gs1=true, macro_kind=5),
      MessageOptions::new(macro_kind=4),
      MessageOptions::new(
        append=Some({ index: 0, count: 2, file_id1: 1, file_id2: 1, }),
      ),
    ] {
    let failed = try {
      ignore(encode_message([Data(b"A")], options=opts))
      false
    } catch {
      _ => true
    }
    assert_true(failed)
  }
  for
    data in [
      [233, 1, 0, 1],
      [234, 234],
      [236, 236],
      [241, 208],
      [241, 192, 0, 1],
    ] {
    let failed = try {
      ignore(decode_data(data, 0))
      false
    } catch {
      _ => true
    }
    assert_true(failed)
  }
}

///|
test "text controls preserve charset boundaries and small append inputs" {
  assert_eq(
    decode_matrix(
      encode_message([Text("中", 25), Fnc1, Text("文", 25)]).matrix(),
    ).text(),
    "中\u001d文",
  )
  assert_eq(
    encode_append_bytes(b"A", 1, 1, options={ shape: Fixed(10, 10), }).length(),
    1,
  )
  assert_eq(
    decode_matrix(
      encode_message(
        [Text("中文", 25)],
        options=MessageOptions::new(macro_kind=5),
      ).matrix(),
    ).text(),
    "[)>\u001e05\u001d中文\u001e\u0004",
  )
}
