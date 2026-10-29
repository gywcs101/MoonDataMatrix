use datamatrix::{DataMatrixBuilder, SymbolList};
use std::io::{self, BufRead};
fn main() {
 for line in io::stdin().lock().lines() {
  let line=line.unwrap();let fields:Vec<_>=line.split(',').collect();
  let w:usize=fields[0].parse().unwrap();let h:usize=fields[1].parse().unwrap();
  let eci=if fields[2]=="1" {Some(26)} else {None};
  let data:Vec<u8>=fields[3].as_bytes().chunks(2).map(|p|u8::from_str_radix(std::str::from_utf8(p).unwrap(),16).unwrap()).collect();
  let list=if w>0 {SymbolList::with_extended_rectangles().enforce_width_in(w..=w).enforce_height_in(h..=h)} else {SymbolList::default().enforce_square()};
  match DataMatrixBuilder::new().with_macros(false).with_symbol_list(list).encode_eci(&data,eci) {
   Ok(dm)=>{let bm=dm.bitmap();println!("{{\"data\":{:?},\"codewords\":{:?},\"width\":{},\"height\":{},\"bits\":{:?}}}",dm.data_codewords(),dm.codewords(),bm.width(),bm.height(),bm.bits());}
   Err(e)=>println!("{{\"error\":\"{:?}\"}}",e),
  }
 }
}

