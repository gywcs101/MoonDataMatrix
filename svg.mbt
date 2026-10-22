///|
/// Render with integer scaling and a quiet zone of at least one module.
/// Limits keep dimensions and memory use bounded across all backends.
pub fn render_svg(
  symbol : Symbol,
  scale? : Int = 4,
  quiet_zone? : Int = 2,
) -> String raise EncodeError {
  if scale < 1 || scale > 1024 || quiet_zone < 1 || quiet_zone > 1024 {
    raise InvalidOption("scale and quiet zone must be between 1 and 1024")
  }
  let w = symbol.width() + 2 * quiet_zone
  let h = symbol.height() + 2 * quiet_zone
  let pxw = w * scale
  let pxh = h * scale
  let parts = [
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"\{pxw}\" height=\"\{pxh}\" viewBox=\"0 0 \{w} \{h}\" shape-rendering=\"crispEdges\"><rect width=\"100%\" height=\"100%\" fill=\"white\"/><path fill=\"black\" d=\"",
  ]
  for y in 0..<symbol.height() {
    for x in 0..<symbol.width() {
      if symbol.module_at(x, y) == Some(true) {
        parts.push("M\{x+quiet_zone} \{y+quiet_zone}h1v1h-1z")
      }
    }
  }
  parts.push("\"/></svg>\n")
  parts.join("")
}

///|
/// Parse strict, even-length hexadecimal. Whitespace is not silently removed.
pub fn parse_hex(input : String) -> Bytes raise EncodeError {
  let bytes = @utf8.encode(input)
  if bytes.length() % 2 != 0 {
    raise InvalidOption("hex must contain an even number of digits")
  }
  fn digit(c : Byte) -> Int raise EncodeError {
    let n = c.to_int()
    if n >= 48 && n <= 57 {
      n - 48
    } else if n >= 65 && n <= 70 {
      n - 55
    } else if n >= 97 && n <= 102 {
      n - 87
    } else {
      raise InvalidOption("invalid hexadecimal digit")
    }
  }
  let out = Array::make(bytes.length() / 2, b'\x00')
  for i in 0..<out.length() {
    out[i] = (digit(bytes[2 * i]) * 16 + digit(bytes[2 * i + 1])).to_byte()
  }
  Bytes::from_array(out)
}
