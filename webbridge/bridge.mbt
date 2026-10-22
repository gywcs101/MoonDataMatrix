///|
pub fn generate(
  input : String,
  hex : Bool,
  shape : String,
  width : Int,
  height : Int,
) -> String {
  try {
    let shape = match shape {
      "square" => @lib.Square
      "rectangle" => @lib.Rectangle
      "any" => @lib.Any
      "fixed" => @lib.Fixed(width, height)
      _ => @lib.Fixed(-1, -1)
    }
    let symbol = if hex {
      @lib.encode_bytes(@lib.parse_hex(input), options={ shape, })
    } else {
      @lib.encode_text(input, options={ shape, })
    }
    let result : Json = {
      "width": symbol.width(),
      "height": symbol.height(),
      "matrix": symbol.matrix(),
      "svg": @lib.render_svg(symbol),
    }
    result.stringify()
  } catch {
    e => {
      let result : Json = { "error": @debug.to_string(e) }
      result.stringify()
    }
  }
}
