///|
pub suberror ProtocolError {
  InvalidRequest(String)
} derive(@debug.Debug)

///|
pub extend ProtocolError with @debug.Debug::{to_repr}

///|
fn object(value : Json) -> Map[String, Json] raise ProtocolError {
  match value {
    Object(obj) => obj
    _ => raise InvalidRequest("expected object")
  }
}

///|
fn keys(
  obj : Map[String, Json],
  allowed : Array[String],
) -> Unit raise ProtocolError {
  for k, _ in obj {
    if !allowed.contains(k) {
      raise InvalidRequest("unknown field: \{k}")
    }
  }
}

///|
fn number(
  obj : Map[String, Json],
  key : String,
  default : Int,
) -> Int raise ProtocolError {
  match obj.get(key) {
    None => default
    Some(Number(n, ..)) => {
      if n < 0 || n > 1000000 || n != n.to_int().to_double() {
        raise InvalidRequest("invalid integer: \{key}")
      }
      n.to_int()
    }
    _ => raise InvalidRequest("expected number: \{key}")
  }
}

///|
fn flag(obj : Map[String, Json], key : String) -> Bool raise ProtocolError {
  match obj.get(key) {
    None => false
    Some(True) => true
    Some(False) => false
    _ => raise InvalidRequest("expected boolean: \{key}")
  }
}

///|
fn options(obj : Map[String, Json]) -> @lib.EncodeOptions raise ProtocolError {
  let shape = match obj.get("shape") {
    None | Some(String("square")) => @lib.Square
    Some(String("rectangle")) => @lib.Rectangle
    Some(String("any")) => @lib.Any
    Some(String("dmre")) => @lib.Dmre
    Some(String("all")) => @lib.WithDmre
    Some(String("fixed")) =>
      @lib.Fixed(number(obj, "width", 0), number(obj, "height", 0))
    _ => raise InvalidRequest("invalid shape")
  }
  { shape, }
}

///|
pub fn encode_request(value : Json) -> Array[@lib.Symbol] raise {
  let obj = object(value)
  keys(obj, [
    "segments", "gs1", "macro", "reader_programming", "append", "shape", "width",
    "height", "split", "text", "hex", "file_id1", "file_id2",
  ])
  let symbol = options(obj)
  if flag(obj, "split") {
    keys(obj, [
      "split", "text", "hex", "file_id1", "file_id2", "shape", "width", "height",
    ])
    let f1 = number(obj, "file_id1", 1)
    let f2 = number(obj, "file_id2", 1)
    return match (obj.get("text"), obj.get("hex")) {
      (Some(String(s)), None) =>
        @lib.encode_append_text(s, f1, f2, options=symbol)
      (None, Some(String(s))) =>
        @lib.encode_append_bytes(@lib.parse_hex(s), f1, f2, options=symbol)
      _ => raise InvalidRequest("split requires exactly one text or hex")
    }
  }
  for k in ["text", "hex", "file_id1", "file_id2"] {
    if obj.contains(k) {
      raise InvalidRequest("field requires split: \{k}")
    }
  }
  let append = match obj.get("append") {
    None => None
    Some(v) => {
      let a = object(v)
      keys(a, ["index", "count", "file_id1", "file_id2"])
      Some(@lib.AppendHeader::{
        index: number(a, "index", 0),
        count: number(a, "count", 0),
        file_id1: number(a, "file_id1", 0),
        file_id2: number(a, "file_id2", 0),
      })
    }
  }
  let inputs = match obj.get("segments") {
    Some(Array(a)) => a
    _ => raise InvalidRequest("missing segments array")
  }
  let segments : Array[@lib.MessageSegment] = []
  for value in inputs {
    let s = object(value)
    keys(s, ["text", "hex", "eci", "fnc1"])
    match (s.get("text"), s.get("hex"), s.get("fnc1")) {
      (Some(String(text)), None, None) =>
        segments.push(@lib.Text(text, number(s, "eci", 26)))
      (None, Some(String(hex)), None) => {
        if s.contains("eci") {
          segments.push(@lib.Eci(number(s, "eci", 0)))
        }
        segments.push(@lib.Data(@lib.parse_hex(hex)))
      }
      (None, None, Some(True)) => {
        if s.length() != 1 {
          raise InvalidRequest("fnc1 must be standalone")
        }
        segments.push(@lib.Fnc1)
      }
      (None, None, None) => {
        if s.length() != 1 || !s.contains("eci") {
          raise InvalidRequest("empty or invalid segment")
        }
        segments.push(@lib.Eci(number(s, "eci", 0)))
      }
      _ => raise InvalidRequest("segment requires one text, hex, eci or fnc1")
    }
  }
  [
    @lib.encode_message(
      segments,
      options=@lib.MessageOptions::new(
        symbol~,
        gs1=flag(obj, "gs1"),
        macro_kind=number(obj, "macro", 0),
        reader_programming=flag(obj, "reader_programming"),
        append~,
      ),
    ),
  ]
}

///|
pub fn matrix(value : Json) -> Array[Array[Bool]] raise ProtocolError {
  let value = match value {
    Object(obj) =>
      match obj.get("matrix") {
        Some(v) => v
        None => raise InvalidRequest("missing matrix")
      }
    _ => value
  }
  let rows = match value {
    Array(a) => a
    _ => raise InvalidRequest("expected matrix array")
  }
  if rows.length() > 144 {
    raise InvalidRequest("matrix too tall")
  }
  let result = []
  for row in rows {
    let cols = match row {
      Array(a) => a
      _ => raise InvalidRequest("expected matrix row")
    }
    if cols.length() > 144 {
      raise InvalidRequest("matrix too wide")
    }
    let cells = []
    for cell in cols {
      match cell {
        True => cells.push(true)
        False => cells.push(false)
        _ => raise InvalidRequest("modules must be boolean")
      }
    }
    result.push(cells)
  }
  result
}

///|
pub fn decoded_json(value : @lib.DecodedMessage) -> Json {
  let hex = StringBuilder()
  let digits = "0123456789abcdef".to_array()
  for b in value.bytes() {
    let v = b.to_int()
    hex.write_char(digits[v / 16])
    hex.write_char(digits[v % 16])
  }
  let text : Json = Json::string(value.text()) catch { _ => Json::null() }
  let changes : Array[Json] = value
    .eci_changes()
    .map(fn(e) { { "offset": e.0, "eci": e.1 } })
  let append : Json = match value.append {
    Some(a) =>
      {
        "index": a.index,
        "count": a.count,
        "file_id1": a.file_id1,
        "file_id2": a.file_id2,
      }
    None => Json::null()
  }
  {
    "hex": hex.to_string(),
    "text": text,
    "eci": changes,
    "gs1": value.gs1,
    "fnc1_positions": value.fnc1_positions(),
    "macro": value.macro_kind,
    "reader_programming": value.reader_programming,
    "append": append,
    "corrected_codewords": value.corrected_codewords,
  }
}

///|
pub fn symbol_json(symbol : @lib.Symbol) -> Json raise {
  {
    "width": symbol.width(),
    "height": symbol.height(),
    "matrix": symbol.matrix(),
    "svg": @lib.render_svg(symbol),
    "decoded": decoded_json(@lib.decode_matrix(symbol.matrix())),
  }
}

///|
pub fn process(operation : String, input : String) -> String raise {
  let value = @json.parse(input)
  let result : Json = match operation {
    "encode" => {
      let symbols = encode_request(value)
      let outputs : Array[Json] = []
      for symbol in symbols {
        outputs.push(symbol_json(symbol))
      }
      { "symbols": outputs }
    }
    "decode" => decoded_json(@lib.decode_matrix(matrix(value)))
    "assemble" => {
      let list = match value {
        Array(a) => a
        Object(obj) =>
          match obj.get("symbols") {
            Some(Array(a)) => a
            _ => raise InvalidRequest("missing symbols")
          }
        _ => raise InvalidRequest("expected symbols array")
      }
      let parts = []
      for item in list {
        parts.push(@lib.decode_matrix(matrix(item)))
      }
      decoded_json(@lib.assemble(parts))
    }
    _ => raise InvalidRequest("unknown operation")
  }
  result.stringify()
}
