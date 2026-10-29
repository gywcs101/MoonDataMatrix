// Adapted from datamatrix-rs symbol_size.rs; see THIRD_PARTY_NOTICES.md.

///|
priv struct Size {
  width : Int
  height : Int
  capacity : Int
  blocks : Int
  ecc : Int
  regions_x : Int
  regions_y : Int
}

///|
let sizes : Array[Size] = [
  {
    width: 10,
    height: 10,
    capacity: 3,
    blocks: 1,
    ecc: 5,
    regions_x: 1,
    regions_y: 1,
  },
  {
    width: 12,
    height: 12,
    capacity: 5,
    blocks: 1,
    ecc: 7,
    regions_x: 1,
    regions_y: 1,
  },
  {
    width: 14,
    height: 14,
    capacity: 8,
    blocks: 1,
    ecc: 10,
    regions_x: 1,
    regions_y: 1,
  },
  {
    width: 16,
    height: 16,
    capacity: 12,
    blocks: 1,
    ecc: 12,
    regions_x: 1,
    regions_y: 1,
  },
  {
    width: 18,
    height: 18,
    capacity: 18,
    blocks: 1,
    ecc: 14,
    regions_x: 1,
    regions_y: 1,
  },
  {
    width: 20,
    height: 20,
    capacity: 22,
    blocks: 1,
    ecc: 18,
    regions_x: 1,
    regions_y: 1,
  },
  {
    width: 22,
    height: 22,
    capacity: 30,
    blocks: 1,
    ecc: 20,
    regions_x: 1,
    regions_y: 1,
  },
  {
    width: 24,
    height: 24,
    capacity: 36,
    blocks: 1,
    ecc: 24,
    regions_x: 1,
    regions_y: 1,
  },
  {
    width: 26,
    height: 26,
    capacity: 44,
    blocks: 1,
    ecc: 28,
    regions_x: 1,
    regions_y: 1,
  },
  {
    width: 32,
    height: 32,
    capacity: 62,
    blocks: 1,
    ecc: 36,
    regions_x: 2,
    regions_y: 2,
  },
  {
    width: 36,
    height: 36,
    capacity: 86,
    blocks: 1,
    ecc: 42,
    regions_x: 2,
    regions_y: 2,
  },
  {
    width: 40,
    height: 40,
    capacity: 114,
    blocks: 1,
    ecc: 48,
    regions_x: 2,
    regions_y: 2,
  },
  {
    width: 44,
    height: 44,
    capacity: 144,
    blocks: 1,
    ecc: 56,
    regions_x: 2,
    regions_y: 2,
  },
  {
    width: 48,
    height: 48,
    capacity: 174,
    blocks: 1,
    ecc: 68,
    regions_x: 2,
    regions_y: 2,
  },
  {
    width: 52,
    height: 52,
    capacity: 204,
    blocks: 2,
    ecc: 42,
    regions_x: 2,
    regions_y: 2,
  },
  {
    width: 64,
    height: 64,
    capacity: 280,
    blocks: 2,
    ecc: 56,
    regions_x: 4,
    regions_y: 4,
  },
  {
    width: 72,
    height: 72,
    capacity: 368,
    blocks: 4,
    ecc: 36,
    regions_x: 4,
    regions_y: 4,
  },
  {
    width: 80,
    height: 80,
    capacity: 456,
    blocks: 4,
    ecc: 48,
    regions_x: 4,
    regions_y: 4,
  },
  {
    width: 88,
    height: 88,
    capacity: 576,
    blocks: 4,
    ecc: 56,
    regions_x: 4,
    regions_y: 4,
  },
  {
    width: 96,
    height: 96,
    capacity: 696,
    blocks: 4,
    ecc: 68,
    regions_x: 4,
    regions_y: 4,
  },
  {
    width: 104,
    height: 104,
    capacity: 816,
    blocks: 6,
    ecc: 56,
    regions_x: 4,
    regions_y: 4,
  },
  {
    width: 120,
    height: 120,
    capacity: 1050,
    blocks: 6,
    ecc: 68,
    regions_x: 6,
    regions_y: 6,
  },
  {
    width: 132,
    height: 132,
    capacity: 1304,
    blocks: 8,
    ecc: 62,
    regions_x: 6,
    regions_y: 6,
  },
  {
    width: 144,
    height: 144,
    capacity: 1558,
    blocks: 10,
    ecc: 62,
    regions_x: 6,
    regions_y: 6,
  },
  {
    width: 18,
    height: 8,
    capacity: 5,
    blocks: 1,
    ecc: 7,
    regions_x: 1,
    regions_y: 1,
  },
  {
    width: 32,
    height: 8,
    capacity: 10,
    blocks: 1,
    ecc: 11,
    regions_x: 2,
    regions_y: 1,
  },
  {
    width: 26,
    height: 12,
    capacity: 16,
    blocks: 1,
    ecc: 14,
    regions_x: 1,
    regions_y: 1,
  },
  {
    width: 36,
    height: 12,
    capacity: 22,
    blocks: 1,
    ecc: 18,
    regions_x: 2,
    regions_y: 1,
  },
  {
    width: 36,
    height: 16,
    capacity: 32,
    blocks: 1,
    ecc: 24,
    regions_x: 2,
    regions_y: 1,
  },
  {
    width: 48,
    height: 16,
    capacity: 49,
    blocks: 1,
    ecc: 28,
    regions_x: 2,
    regions_y: 1,
  },
]

///|
let dmre_sizes : Array[Size] = [
  {
    width: 48,
    height: 8,
    capacity: 18,
    blocks: 1,
    ecc: 15,
    regions_x: 2,
    regions_y: 1,
  },
  {
    width: 64,
    height: 8,
    capacity: 24,
    blocks: 1,
    ecc: 18,
    regions_x: 4,
    regions_y: 1,
  },
  {
    width: 80,
    height: 8,
    capacity: 32,
    blocks: 1,
    ecc: 22,
    regions_x: 4,
    regions_y: 1,
  },
  {
    width: 96,
    height: 8,
    capacity: 38,
    blocks: 1,
    ecc: 28,
    regions_x: 4,
    regions_y: 1,
  },
  {
    width: 120,
    height: 8,
    capacity: 49,
    blocks: 1,
    ecc: 32,
    regions_x: 6,
    regions_y: 1,
  },
  {
    width: 144,
    height: 8,
    capacity: 63,
    blocks: 1,
    ecc: 36,
    regions_x: 6,
    regions_y: 1,
  },
  {
    width: 64,
    height: 12,
    capacity: 43,
    blocks: 1,
    ecc: 27,
    regions_x: 4,
    regions_y: 1,
  },
  {
    width: 88,
    height: 12,
    capacity: 64,
    blocks: 1,
    ecc: 36,
    regions_x: 4,
    regions_y: 1,
  },
  {
    width: 64,
    height: 16,
    capacity: 62,
    blocks: 1,
    ecc: 36,
    regions_x: 4,
    regions_y: 1,
  },
  {
    width: 36,
    height: 20,
    capacity: 44,
    blocks: 1,
    ecc: 28,
    regions_x: 2,
    regions_y: 1,
  },
  {
    width: 44,
    height: 20,
    capacity: 56,
    blocks: 1,
    ecc: 34,
    regions_x: 2,
    regions_y: 1,
  },
  {
    width: 64,
    height: 20,
    capacity: 84,
    blocks: 1,
    ecc: 42,
    regions_x: 4,
    regions_y: 1,
  },
  {
    width: 48,
    height: 22,
    capacity: 72,
    blocks: 1,
    ecc: 38,
    regions_x: 2,
    regions_y: 1,
  },
  {
    width: 48,
    height: 24,
    capacity: 80,
    blocks: 1,
    ecc: 41,
    regions_x: 2,
    regions_y: 1,
  },
  {
    width: 64,
    height: 24,
    capacity: 108,
    blocks: 1,
    ecc: 46,
    regions_x: 4,
    regions_y: 1,
  },
  {
    width: 40,
    height: 26,
    capacity: 70,
    blocks: 1,
    ecc: 38,
    regions_x: 2,
    regions_y: 1,
  },
  {
    width: 48,
    height: 26,
    capacity: 90,
    blocks: 1,
    ecc: 42,
    regions_x: 2,
    regions_y: 1,
  },
  {
    width: 64,
    height: 26,
    capacity: 118,
    blocks: 1,
    ecc: 50,
    regions_x: 4,
    regions_y: 1,
  },
]

///|
fn select_size(needed : Int, options : EncodeOptions) -> Size raise EncodeError {
  if needed < 0 {
    raise CapacityExceeded
  }
  let pool = match options.shape {
    WithDmre | Dmre | Fixed(_, _) => sizes + dmre_sizes
    _ => sizes
  }
  let candidates = pool.filter(fn(s) {
    match options.shape {
      Square => s.width == s.height
      Rectangle => s.width != s.height
      Any | WithDmre => true
      Dmre =>
        dmre_sizes
        .iter()
        .any(fn(d) { d.width == s.width && d.height == s.height })
      Fixed(w, h) => s.width == w && s.height == h
    }
  })
  if candidates.is_empty() {
    raise UnsupportedSize
  }
  let mut best : Size? = None
  for s in candidates {
    if s.capacity >= needed {
      match best {
        None => best = Some(s)
        Some(b) => if s.capacity < b.capacity { best = Some(s) }
      }
    }
  }
  match best {
    Some(s) => s
    None => raise CapacityExceeded
  }
}
