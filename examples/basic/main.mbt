///|
fn main raise {
  let symbol = @datamatrix.encode_text("样本编号：LAB-2026-001")
  println(@datamatrix.render_svg(symbol))
}
