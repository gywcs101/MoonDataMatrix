# Third-party sources

Reference and port source: [datamatrix-rs](https://github.com/jannschu/datamatrix-rs), commit `af189538aee8f029dd58f317ebd4c006c9837ac2`, copyright 2021 Jannik Schürg. We select its MIT option; the complete license is in LICENSES/datamatrix-rs-MIT.txt.

Planned port scope: symbol tables, ECC encoding, placement, data encodation and mode planner. No decoder is ported. Per-file migration and fixture provenance are recorded as implementation progresses. Root LICENSE applies to original contributions and does not replace upstream notices.

ZXing-C++ 2.3.0 Python binding is a development-only independent decoder, not shipped in the library. Its license remains applicable to its own distribution.

Ecosystem check: cached Mooncakes module inventory dated 2026-10-21 contained no Data Matrix encoder. On 2026-10-22 targeted GitHub search `datamatrix language:MoonBit` returned zero repositories; the Mooncakes full-list endpoint could not be refreshed. These checks are not proof of absence.
