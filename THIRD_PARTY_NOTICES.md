# Third-party sources

Reference and port source: [datamatrix-rs](https://github.com/jannschu/datamatrix-rs), commit `af189538aee8f029dd58f317ebd4c006c9837ac2`, copyright 2021 Jannik Schürg. We select its MIT option; the complete license is in LICENSES/datamatrix-rs-MIT.txt.

Port scope: symbol tables, ECC encoding, placement, data encodation and the complete six-mode planner. Six-mode data decoding is adapted from src/decodation/mod.rs; matrix extraction shares the ported placement traversal. The Reed–Solomon decoder is an original implementation of Berlekamp–Massey and a syndrome linear solve. See MIGRATION.md for the per-file mapping and deterministic tie-order adjustment. Root LICENSE applies to original contributions and does not replace upstream notices.

ZXing-C++ 2.3.0 Python binding is an independent validation decoder, not shipped in the library. Its license remains applicable to its own distribution.



## Fixtures and validation dependencies

- `ecc_wbtest.mbt`, `compact_wbtest.mbt`, `x12_edifact_wbtest.mbt` and `planner_wbtest.mbt` include upstream algorithm/reference vectors, under the selected MIT license above.
- The deterministic corpus in `scripts/test-differential.py` is generated from original inputs (seed 20261022). Expected values are produced by the pinned upstream Rust implementation. The Rust runner is an original adapter. Cargo.lock pins its dependency resolution.
- Other test strings, JSONL records and browser examples are synthetic original data. They contain no private, medical or customer records.
- `moonbitlang/x@0.5.4` supplies the CLI filesystem/process APIs under Apache-2.0; it is resolved as a dependency, not vendored. Source: https://github.com/moonbitlang/x .
- Playwright, Pillow and ZXing-C++ are validation dependencies. Their own distributed license terms apply. No images or code were copied from those projects into the production encoder.
- `web/core.js` is generated from this repository's MoonBit sources and standard library, distributed with the browser demo. The generated JS includes standard-library code from `moonbitlang/core@0.10.14+7d59c7ec9`, copyright International Digital Economy Academy and upstream contributors (https://github.com/moonbitlang/core). Its Apache-2.0 license and complete upstream NOTICE are retained in LICENSES/Apache-2.0.txt and LICENSES/moonbit-core-NOTICE.txt. The deployed site includes these and both MIT notices in its licenses/ directory, linked from the page footer. No manual modifications are made to standard-library source.

## Character-set data

`charset/table_*.mbt` and `charset/gb_ranges.mbt` are generated from CPython 3.13.5 codec mappings, under the Python Software Foundation license and historical notices included in [LICENSES/Python.txt](LICENSES/Python.txt). Sources: [CPython codecs](https://github.com/python/cpython/tree/v3.13.5/Lib/encodings) and [CJK codec mappings](https://github.com/python/cpython/tree/v3.13.5/Modules/cjkcodecs). `charset/SOURCES.json` records the exact generator environment and codec names. The generated representation is a sorted lookup table plus GB18030 pointer ranges; the MoonBit conversion code is original MIT code. Mapping data retains the CPython mapping version, including its GB18030 mapping behavior.

`message.mbt`, `append.mbt` and the JSON adapters are original implementations. The Data Matrix control numbering and ECI assignments were cross-checked against the Zint manual and reference behavior. No Zint implementation code is copied into this project. Fixed protocol vectors and application examples are original data.

`append_message.mbt` adds original segmented automatic splitting with per-symbol ECI state. Protocol references: [Zint ECI assignments](https://zint.org.uk/manual/chapter/4/) and [Data Matrix controls and structured append](https://zint.org.uk/manual/chapter/6/). These pages are references for behavior, not copied code. CPython codec names and aliases are fixed in `charset/SOURCES.json`; the mapping generator enforces strict reversible text conversion.
