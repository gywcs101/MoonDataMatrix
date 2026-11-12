///|
/// Immutable symbol. Exported matrices are defensive copies.
pub struct Symbol {
  priv w : Int32
  priv h : Int32
  priv cells : Array[Bool]
}

///|
pub fn Symbol::width(self : Symbol) -> Int32 {
  self.w
}

///|
pub fn Symbol::height(self : Symbol) -> Int32 {
  self.h
}

///|
pub fn Symbol::module_at(self : Symbol, x : Int32, y : Int32) -> Bool? {
  if x < 0 || y < 0 || x >= self.w || y >= self.h {
    None
  } else {
    Some(self.cells[y * self.w + x])
  }
}

///|
pub fn Symbol::matrix(self : Symbol) -> Array[Array[Bool]] {
  Array::makei(self.h, fn(y) {
    Array::makei(self.w, fn(x) { self.cells[y * self.w + x] })
  })
}
