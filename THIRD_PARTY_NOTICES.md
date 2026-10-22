# Third-party sources

Reference and port source: [datamatrix-rs](https://github.com/jannschu/datamatrix-rs), commit `af189538aee8f029dd58f317ebd4c006c9837ac2`, copyright 2021 Jannik Schürg. We select its MIT option; the complete license is in LICENSES/datamatrix-rs-MIT.txt.

Port scope: symbol tables, ECC encoding, placement, data encodation and the complete six-mode planner. No decoder is ported. See MIGRATION.md for the per-file mapping and deterministic tie-order adjustment. Root LICENSE applies to original contributions and does not replace upstream notices.

ZXing-C++ 2.3.0 Python binding is a development-only independent decoder, not shipped in the library. Its license remains applicable to its own distribution.

Ecosystem check: cached Mooncakes module inventory dated 2026-10-21 contained no Data Matrix encoder. On 2026-10-22 targeted GitHub search `datamatrix language:MoonBit` returned zero repositories; the Mooncakes full-list endpoint could not be refreshed. These checks are not proof of absence.


## Fixtures and validation dependencies

- `ecc_wbtest.mbt`, `compact_wbtest.mbt`, `x12_edifact_wbtest.mbt` and `planner_wbtest.mbt` include upstream algorithm/reference vectors, under the selected MIT license above.
- The deterministic corpus in `scripts/test-differential.py` is generated from original inputs (seed 20261022). Expected values are produced by the pinned upstream Rust implementation; generated temporary MoonBit test files are removed after the run. The Rust runner is an original adapter. Cargo.lock pins its dependency resolution.
- Other test strings, JSONL records and browser examples are synthetic original data. They contain no private, medical or customer records.
- `moonbitlang/x@0.5.4` supplies the CLI filesystem/process APIs under Apache-2.0; it is resolved as a dependency, not vendored. Source: https://github.com/moonbitlang/x .
- Playwright, Pillow and ZXing-C++ are development-only dependencies. Their own distributed license terms apply. No images or code were copied from those projects into the production encoder.
- `web/core.js` is generated from this repository's MoonBit sources and standard library, ignored in Git, and rebuilt for deployment. The standard library retains its Apache-2.0 notices in its source distribution.
