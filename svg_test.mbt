///|
test "public validation and defensive copies" {
  let s = @MoonDataMatrix.encode_text("<script> & 中文")
  let svg = @MoonDataMatrix.render_svg(s)
  assert_true(svg.contains("viewBox"))
  assert_false(svg.contains("<script>"))
  for scale in [-1, 0, 1025, 2147483647] {
    let failed = try {
      ignore(@MoonDataMatrix.render_svg(s, scale~))
      false
    } catch {
      _ => true
    }
    assert_true(failed)
  }
  for quiet_zone in [-1, 0, 1025, 2147483647] {
    let failed = try {
      ignore(@MoonDataMatrix.render_svg(s, quiet_zone~))
      false
    } catch {
      _ => true
    }
    assert_true(failed)
  }
  for text in ["0", "GG", "00 ", "ＡＡ"] {
    let failed = try {
      ignore(@MoonDataMatrix.parse_hex(text))
      false
    } catch {
      _ => true
    }
    assert_true(failed)
  }
  assert_eq(@MoonDataMatrix.parse_hex("00fF"), b"\x00\xff")
  let failed = try {
    ignore(@MoonDataMatrix.encode_bytes(Bytes::make(3117, 65)))
    false
  } catch {
    _ => true
  }
  assert_true(failed)
  let invalid = try {
    ignore(@MoonDataMatrix.encode_text("a", options={ shape: Fixed(11, 11), }))
    false
  } catch {
    _ => true
  }
  assert_true(invalid)
}
