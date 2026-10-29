///|
test "decode all modes sizes and correction" {
  for
    bytes in [
      b"",
      b"Hello, World!",
      b"ABCDEFGHIJKLMNOPQRSTUVWXYZABCDEFGHIJKLMNOPQRSTUVWXYZ",
      b"abcdefghijklmnopqrstuvwxyzabcdefghijklmnopqrstuvwxyz",
      b"ABC>ABC>ABC>ABC>ABC>ABC>",
      b"^@?^@?^@?^@?^@?^@?",
      Bytes::makei(256, fn(i) { i.to_byte() }),
    ] {
    let symbol = encode_bytes(bytes)
    assert_eq(decode_matrix(symbol.matrix()).bytes(), bytes)
  }
  let text = "中文🙂é\n"
  assert_eq(decode_matrix(encode_text(text).matrix()).text(), text)
  for size in sizes {
    let data = b"12"
    let matrix = encode_bytes(data, options={
      shape: Fixed(size.width, size.height),
    }).matrix()
    assert_eq(decode_matrix(matrix).bytes(), data)
    matrix[1][1] = !matrix[1][1]
    let decoded = decode_matrix(matrix)
    assert_eq(decoded.bytes(), data)
    assert_eq(decoded.corrected_codewords, 1)
  }
  for size in sizes {
    let data = Array::makei(size.capacity, fn(i) { i % 256 })
    let full = data.copy()
    for x in error_code(data, size) {
      full.push(x)
    }
    for block in 0..<size.blocks {
      for n in 0..<(size.ecc / 2) {
        let pos = block + n * size.blocks
        full[pos] = full[pos] ^ (n + 1)
      }
    }
    assert_eq(correct_codewords(full, size), size.blocks * (size.ecc / 2))
    for i in 0..<data.length() {
      assert_eq(full[i], data[i])
    }
  }
}

///|
test "decode rejects malformed matrix and invalid data" {
  for
    matrix in [
      [],
      [[true]],
      [[true], []],
      Array::makei(10, fn(_) { Array::make(10, false) }),
    ] {
    let failed = try {
      ignore(decode_matrix(matrix))
      false
    } catch {
      _ => true
    }
    assert_true(failed)
  }
  for data in [[0], [235], [235, 0], [241, 0], [231], [231, 1], [230, 0, 0]] {
    let failed = try {
      ignore(decode_data(data, 0))
      false
    } catch {
      _ => true
    }
    assert_true(failed)
  }
}
