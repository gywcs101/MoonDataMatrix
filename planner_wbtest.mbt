// End-of-data vectors ported from datamatrix-rs planner tests (MIT).

///|
test "upstream C40 and X12 end cost" {
  for mode in [3, 4] {
    let p = new_plan(mode, b"DEABCFG", { shape: Square, }, 0, 0, 0, [(7, mode)])
    for _ in 0..<7 {
      assert_true(p.step() != None)
    }
    assert_eq(p.total_cost(), 60)
  }
  let p = new_plan(3, b"AIMAIMAIMAIMAI", { shape: Square, }, 0, 0, 0, [(14, 3)])
  for _ in 0..<12 {
    assert_true(p.step() != None)
  }
  assert_eq(p.total_cost(), 96)
  ignore(p.step())
  assert_eq(p.total_cost(), 120)
  ignore(p.step())
  assert_eq(p.total_cost(), 132)
}

///|
test "upstream shortest path chooses X12 for trailing digits" {
  let plan = optimize(b"*********00", 0, { shape: Square, })
  assert_eq(plan[0].1, 3)
}

///|
test "fractional cost and ECI tie regression" {
  assert_eq(ceil_cost(1), 12)
  assert_eq(ceil_cost(12), 12)
  assert_eq(ceil_cost(13), 24)
  let words = planned_codewords(b"Hello, World!", true, { shape: Square, })
  assert_eq(words, [
    241, 27, 73, 102, 109, 109, 112, 45, 33, 88, 112, 115, 109, 101, 34,
  ])
}

///|
test "capacity terminal cases and full numeric capacity" {
  let raw = encode_bytes(Bytes::make(3116, b'1'))
  assert_eq(raw.width(), 144)
  for n in 1..<30 {
    for byte in [b'A', b'a', b'*', b'^', b'0', b'\xff'] {
      let data = Bytes::make(n, byte)
      let words = planned_codewords(data, false, { shape: Square, })
      let s = pad_data(words, { shape: Square, })
      assert_eq(words.length(), s.capacity)
    }
  }
}
