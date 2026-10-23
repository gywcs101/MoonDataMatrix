# Port provenance and compatibility

## Source

`jannschu/datamatrix-rs` at `af189538aee8f029dd58f317ebd4c006c9837ac2`, MIT option. Only encoding-related algorithms are ported. No decoder, DMRE or GS1 support is exposed.

| MoonBit file | Upstream source | Adaptation |
|---|---|---|
| sizes.mbt | src/symbol_size.rs | 30 classic sizes, option-based selection |
| ecc.mbt | src/errorcode/mod.rs, galois.rs | Same polynomial 0x12D and block interleaving; generator coefficients calculated rather than copied |
| placement.mbt | src/placement.rs IndexTraversal / MatrixMap | Utah/corner traversal and region borders; private Symbol storage |
| encode.mbt | src/encodation/ascii.rs, mod.rs | ASCII, padding, public UTF-8/byte APIs |
| compact.mbt | src/encodation/c40.rs, text.rs | Character maps and triplet packing |
| x12_edifact.mbt | src/encodation/x12.rs, edifact.rs | Native alphabet and bit packing |
| base256.mbt | src/encodation/base256.rs | Absolute-position randomization |
| encoder_context.mbt | src/encodation/mod.rs and six encoders | Context, switching, backtracking and end-of-data rules |
| planner.mbt | src/encodation/planner/*.rs | All six cost states, fractional costs, switches, pruning and final selection |

## Optimizer

The six-mode optimizer is ported from the pinned upstream implementation. The public API automatically selects encoding modes.

One deliberate determinism adjustment: upstream uses an unstable cost-only sort before pruning. Equal-cost order can depend on the language/runtime sorting implementation. This port uses the upstream final tie preferences (maximum mode complexity, then switch count) during that sorting step too, with stable order for exact ties. It does not change primary cost ordering. A UTF-8 ECI `Hello, World!` regression covers this adjustment. No universal global-optimality claim is made.

The pinned Rust reference runner compares padded data codewords, complete data/ECC codewords and every matrix cell. The current deterministic corpus has 172 cases, including all 30 sizes, mode-oriented alphabets, binary length boundaries and 144×144. All matched exactly in the recorded validation. This is regression evidence, not a proof for all inputs.

## Intentional API differences

- Text always uses UTF-8 plus ECI 26, even for Latin-1 or ASCII. Rust comparison uses `encode_eci(..., Some(26))` explicitly.
- Bytes are untouched and receive no ECI.
- Square symbols are the default. Rust comparison restricts its symbol list to squares too.
- Automatic macros and FNC1 are disabled.
- SVG output and native CLI/browser adapters are original implementations.
- The 144×144 block ordering follows the pinned upstream; interoperability is checked with ZXing-C++ 2.3.0. Historical scanner compatibility is not guaranteed.

## Runtime compatibility

The source distribution supports moonc `0.10.14+7d59c7ec9` with CLI dependency `moonbitlang/x@0.5.4`. The core depends only on the MoonBit standard library.

The native CLI supports Unicode command-line arguments on Windows through a C adapter using Windows APIs. Encoding and JSONL processing run in MoonBit.
