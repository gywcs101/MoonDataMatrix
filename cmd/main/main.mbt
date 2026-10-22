///|
fn main raise {
  let symbol = @lib.encode_text("MoonDataMatrix")
  for row in symbol.matrix() {
    println(row.map(fn(v) { if v { "██" } else { "  " } }).join(""))
  }
}
