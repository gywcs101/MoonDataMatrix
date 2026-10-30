///|
#borrow(a, b)
extern "C" fn publish(a : Bytes, b : Bytes) -> Int = "mdm_publish"

///|
#borrow(bytes)
extern "C" fn stderr(bytes : Bytes) -> Unit = "mdm_stderr"

///|
fn c_string(s : String) -> Bytes {
  @utf8.encode(s) + b"\x00"
}

///|
suberror CliError {
  CliError(Int, String)
}

///|
fn fail(code : Int, message : String) -> Unit raise CliError {
  raise CliError(code, message)
}

///|
fn read_bytes(path : String) -> Bytes raise CliError {
  if path.contains("\u0000") {
    raise CliError(2, "path contains NUL")
  }
  @fs.read_file_to_bytes(path) catch {
    _ => raise CliError(4, "cannot read file: \{path}")
  }
}

///|
fn text_decode(bytes : Bytes) -> String raise CliError {
  @utf8.decode(bytes, ignore_bom=false) catch {
    _ => raise CliError(3, "input is not valid UTF-8")
  }
}

///|
fn svg(
  input : String,
  hex : Bool,
  options : @lib.EncodeOptions,
) -> String raise CliError {
  try {
    let symbol = if hex {
      @lib.encode_bytes(@lib.parse_hex(input), options~)
    } else {
      @lib.encode_text(input, options~)
    }
    @lib.render_svg(symbol)
  } catch {
    e => raise CliError(3, @protocol.user_error(e))
  }
}

///|
fn clean_stage(stage : String) -> Unit {
  try {
    for name in @fs.read_dir(stage) {
      @fs.remove_file(stage + "/" + name) catch {
        _ => clean_stage(stage + "/" + name)
      }
    }
    @fs.remove_dir(stage)
  } catch {
    _ => ()
  }
}

///|
fn create_stage(target : String) -> String raise CliError {
  if target.contains("\u0000") {
    raise CliError(2, "path contains NUL")
  }
  if @fs.path_exists(target) {
    raise CliError(4, "output already exists: \{target}")
  }
  let stage = target + ".tmp-" + @env.now().to_string()
  @fs.create_dir(stage) catch {
    _ => raise CliError(4, "cannot create staging directory: \{stage}")
  }
  stage
}

///|
fn write_staged(path : String, content : String) -> Unit raise CliError {
  @fs.write_string_to_file(path, content) catch {
    _ => raise CliError(4, "cannot write file: \{path}")
  }
}

///|
fn write_single(target : String, content : String) -> Unit raise CliError {
  let stage = create_stage(target)
  errdefer clean_stage(stage)
  {
    let source = stage + "/output.svg"
    write_staged(source, content)
    if publish(c_string(source), c_string(target)) != 0 {
      fail(4, "cannot publish output (existing destination or I/O failure)")
    }
  }
  clean_stage(stage)
}

///|
fn valid_id(id : String) -> Bool {
  let bytes = @utf8.encode(id)
  if bytes.is_empty() || bytes.length() > 100 {
    return false
  }
  for c in bytes {
    if !((c >= b'A' && c <= b'Z') ||
      (c >= b'a' && c <= b'z') ||
      (c >= b'0' && c <= b'9') ||
      c == b'_' ||
      c == b'-') {
      return false
    }
  }
  // Windows device names must not become output filenames.
  let upper = id.to_upper()
  !(upper == "CON" ||
  upper == "PRN" ||
  upper == "AUX" ||
  upper == "NUL" ||
  (
    upper.length() == 4 &&
    (upper.has_prefix("COM") || upper.has_prefix("LPT")) &&
    upper[3] >= 49 &&
    upper[3] <= 57
  ))
}

///|
fn batch(
  input : String,
  target : String,
  options : @lib.EncodeOptions,
) -> Unit raise CliError {
  let lines = text_decode(read_bytes(input)).split("\n").to_array()
  let results : Array[(String, String)] = []
  let ids : Map[String, Bool] = Map([])
  for index in 0..<lines.length() {
    let line = lines[index].to_owned()
    if index == lines.length() - 1 && line == "" {
      continue
    }
    let line_number = index + 1
    let mut id = "?"
    try {
      let value = @json.parse(line) catch {
        _ => raise CliError(3, "invalid JSON")
      }
      let obj = match value {
        Object(v) => v
        _ => raise CliError(3, "expected object")
      }
      id = match obj.get("id") {
        Some(String(s)) => s
        _ => raise CliError(3, "missing string id")
      }
      if !valid_id(id) {
        fail(3, "invalid id")
      }
      let key = id.to_lower()
      if ids.contains(key) {
        fail(3, "duplicate id (case-insensitive)")
      }
      ids[key] = true
      for key, _ in obj {
        if key != "id" && key != "text" && key != "hex" && key != "message" {
          fail(3, "unknown field: \{key}")
        }
      }
      if obj.length() != 2 {
        fail(3, "expected exactly one of text or hex")
      }
      if obj.get("message") is Some(message) {
        let symbols = @protocol.encode_request(message) catch {
          e => raise CliError(3, @protocol.user_error(e))
        }
        if symbols.length() == 1 {
          results.push(
            (
              id + ".svg",
              @lib.render_svg(symbols[0]) catch {
                e => raise CliError(3, @protocol.user_error(e))
              },
            ),
          )
        } else {
          for i in 0..<symbols.length() {
            let n = (i + 1).to_string()
            results.push(
              (
                id + "/part-" + (if i < 9 { "0" } else { "" }) + n + ".svg",
                @lib.render_svg(symbols[i]) catch {
                  e => raise CliError(3, @protocol.user_error(e))
                },
              ),
            )
          }
        }
        let matrices : Array[Json] = symbols.map(fn(s) {
          { "matrix": s.matrix(), "width": s.width(), "height": s.height() }
        })
        let data : Json = { "symbols": matrices }
        results.push(
          (
            if symbols.length() == 1 {
              id + ".json"
            } else {
              id + "/symbols.json"
            },
            data.stringify(),
          ),
        )
        continue
      }
      let content = match (obj.get("text"), obj.get("hex")) {
        (Some(String(s)), None) => svg(s, false, options)
        (None, Some(String(s))) => svg(s, true, options)
        _ => raise CliError(3, "text or hex must be a string")
      }
      results.push((id + ".svg", content))
    } catch {
      CliError(code, message) =>
        raise CliError(code, "line \{line_number}, id \{id}: \{message}")
    }
  }
  if results.is_empty() {
    fail(3, "batch contains no entries")
  }
  let stage = create_stage(target)
  errdefer clean_stage(stage)
  for (id, content) in results {
    let pieces = id.split("/").map(fn(s) { s.to_owned() }).to_array()
    if pieces.length() > 1 && !@fs.path_exists(stage + "/" + pieces[0]) {
      @fs.create_dir(stage + "/" + pieces[0]) catch {
        _ => raise CliError(4, "cannot create batch item directory")
      }
    }
    write_staged(stage + "/" + id, content)
  }
  if publish(c_string(stage), c_string(target)) != 0 {
    fail(4, "cannot publish batch directory")
  }
}

///|
fn run(args : Array[String]) -> Unit raise CliError {
  if args.length() < 2 || args[1] == "--help" {
    println(
      "MoonDataMatrix\nencode (--text TEXT | --text-file PATH | --binary-file PATH | --hex HEX) [--output FILE]\nbatch --input JSONL --output NEW_DIRECTORY\ndecode|assemble|message --input JSON [--output JSON]\nOptions: --shape square|rectangle|any|dmre|all | --size WIDTHxHEIGHT; encode --format svg|json; --message-file JSON",
    )
    return
  }
  let command = args[1]
  if command == "decode" || command == "assemble" || command == "message" {
    run_protocol(command, args)
    return
  }
  if command != "encode" && command != "batch" {
    fail(2, "unknown command")
  }
  let values : Map[String, String] = Map([])
  let allowed = if command == "encode" {
    [
      "--text", "--text-file", "--binary-file", "--hex", "--output", "--shape", "--size",
      "--format", "--message-file",
    ]
  } else {
    ["--input", "--output", "--shape", "--size"]
  }
  let mut i = 2
  while i < args.length() {
    let key = args[i]
    if !allowed.contains(key) || values.contains(key) || i + 1 >= args.length() {
      fail(2, "invalid or duplicate option: \{key}")
    }
    values[key] = args[i + 1]
    i += 2
  }
  if values.contains("--shape") && values.contains("--size") {
    fail(2, "shape and size are mutually exclusive")
  }
  let shape = match values.get("--size") {
    Some(size) => {
      let parts = size.split("x").to_array()
      if parts.length() != 2 {
        fail(2, "size must be WIDTHxHEIGHT")
      }
      let w = @string.parse_int(parts[0]) catch {
        _ => raise CliError(2, "invalid width")
      }
      let h = @string.parse_int(parts[1]) catch {
        _ => raise CliError(2, "invalid height")
      }
      @lib.Fixed(w, h)
    }
    None =>
      match values.get("--shape") {
        None | Some("square") => @lib.Square
        Some("rectangle") => @lib.Rectangle
        Some("any") => @lib.Any
        Some("dmre") => @lib.Dmre
        Some("all") => @lib.WithDmre
        _ => raise CliError(2, "invalid shape")
      }
  }
  let options : @lib.EncodeOptions = { shape, }
  ignore(@lib.dimensions_for_codewords(0, options~)) catch {
    _ => raise CliError(2, "unsupported size")
  }
  if command == "batch" {
    let input = match values.get("--input") {
      Some(v) => v
      None => raise CliError(2, "missing input")
    }
    let output = match values.get("--output") {
      Some(v) => v
      None => raise CliError(2, "missing output")
    }
    batch(input, output, options)
  } else {
    let inputs = [
      "--text", "--text-file", "--binary-file", "--hex", "--message-file",
    ].filter(fn(k) { values.contains(k) })
    if inputs.length() != 1 {
      fail(2, "select exactly one input")
    }
    let key = inputs[0]
    let input = values[key]
    let format = values.get("--format").unwrap_or("svg")
    if format != "svg" && format != "json" {
      fail(2, "format must be svg or json")
    }
    let content = try {
      if key == "--message-file" {
        if values.contains("--shape") || values.contains("--size") {
          fail(2, "message file contains its own size options")
        }
        let source = text_decode(read_bytes(input))
        if format == "json" {
          @protocol.process("encode", source)
        } else {
          let symbols = @protocol.encode_request(@json.parse(source))
          if symbols.length() != 1 {
            fail(2, "multiple symbols require --format json")
          }
          @lib.render_svg(symbols[0])
        }
      } else {
        let symbol = match key {
          "--text" => @lib.encode_text(input, options~)
          "--hex" => @lib.encode_bytes(@lib.parse_hex(input), options~)
          "--text-file" =>
            @lib.encode_text(text_decode(read_bytes(input)), options~)
          _ => @lib.encode_bytes(read_bytes(input), options~)
        }
        if format == "json" {
          @protocol.symbol_json(symbol).stringify()
        } else {
          @lib.render_svg(symbol)
        }
      }
    } catch {
      CliError(code, message) => raise CliError(code, message)
      e => raise CliError(3, @protocol.user_error(e))
    }
    match values.get("--output") {
      Some(path) => write_single(path, content)
      None => println(content)
    }
  }
}

///|
fn main {
  run(cli_args()) catch {
    CliError(code, message) => {
      stderr(c_string(message))
      @sys.exit(code)
    }
  }
}

///|
#cfg(platform="windows")
extern "C" fn windows_args() -> FixedArray[String] = "mdm_windows_args"

///|
#cfg(platform="windows")
fn cli_args() -> Array[String] {
  [
    for arg in windows_args() => arg
  ]
}

///|
#cfg(not(platform="windows"))
fn cli_args() -> Array[String] {
  @env.args()
}

///|
fn run_protocol(command : String, args : Array[String]) -> Unit raise CliError {
  let values : Map[String, String] = Map([])
  let mut i = 2
  while i < args.length() {
    let key = args[i]
    if (key != "--input" && key != "--output") ||
      values.contains(key) ||
      i + 1 >= args.length() {
      fail(2, "expected --input and optional --output")
    }
    values[key] = args[i + 1]
    i += 2
  }
  let path = match values.get("--input") {
    Some(p) => p
    None => raise CliError(2, "missing input")
  }
  let input = text_decode(read_bytes(path))
  let result = @protocol.process(
    if command == "message" {
      "encode"
    } else {
      command
    },
    input,
  ) catch {
    e => raise CliError(3, @protocol.user_error(e))
  }
  match values.get("--output") {
    Some(p) => write_single(p, result)
    None => println(result)
  }
}
