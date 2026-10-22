# MoonDataMatrix

MoonBit Data Matrix ECC 200 encoder. Work in progress; not yet released.

Planned: reusable library, native CLI, browser demo; UTF-8 text with ECI 26 and raw binary; 24 square and 6 rectangular symbols. No GS1, DMRE, decoder, structured append or automatic Macro conversion. This project does not claim ISO certification.

Development baseline: moonc v0.10.14+7d59c7ec9, moon 0.1.20260920.

## Development

```
moon check --target all --deny-warn
moon test --target all --deny-warn
moon fmt --check
moon info
```

## License and source

MIT. See THIRD_PARTY_NOTICES.md and LICENSES for upstream attribution.
