# 兼容性与可靠性

## 验证范围

核心测试覆盖 native、JS、wasm、wasm-gc；GitHub Actions 同时检查 Windows、Linux、macOS 的原生 CLI。各提交的结果可在 [CI 记录](https://github.com/gywcs101/MoonDataMatrix/actions/workflows/ci.yml) 查看。

| 能力 | 验证内容 |
| --- | --- |
| 编码与尺寸 | 190 组固定 datamatrix-rs 差分用例逐项比较数据码字、纠错码字与矩阵，覆盖 30 种经典尺寸和 18 种 DMRE 尺寸 |
| 外部读取 | 70 组 ZXing-C++ 用例逐字节还原中文、emoji、BOM、全部字节值、随机二进制、144×144 和全部 48 种尺寸 |
| 矩阵解码 | 六种模式、594 组确定性输入、全部尺寸；外部 ZXing-C++ 编码的英文、中文及二进制矩阵由 MoonBit 还原 |
| 纠错 | 按纠错块注入错误，覆盖块纠错容量、144×144 不等长数据块与已知不可纠正样例 |
| 控制协议 | ECI 编号长度边界及切换、GS1/FNC1、Macro 05/06、Reader Programming、非法组合与控制位置 |
| 字符集 | 生成映射表逐条往返检查；Unicode 边界、BOM、非法序列与不可表示字符；多字符集消息独立字节对照 |
| 结构化追加 | 自动文本和字节分片、最多 16 片、乱序重组、重复片与不一致元数据 |
| 分段消息与批次 | 混合 ECI 文本自动分片、UTF-16 字符边界、ECI 899 原始字节、GS1 分片与高级消息 JSONL；分片经 ZXing-C++ 独立字节对照，批次错误与防覆盖验证 |
| CLI | 原有输入与 JSONL 批次、高级消息、矩阵 JSON、解码与重组、退出码和防覆盖行为 |
| 浏览器 | GS1、DMRE、多字符集、多符号示例；SVG/PNG/JSON 下载、矩阵导入与重组、旧结果清除 |
| 包与消费者 | 实际压缩包文件及许可证检查；独立 MoonBit 项目导入并在四后端使用编码、解码与字符集接口 |

上述检查分别由 scripts/test-differential.py、scripts/test-interop.py、scripts/test-extended.py、scripts/test-cli.py、scripts/test-consumer.py、scripts/verify-package.py 和 tests/browser/test.mjs 重现。浏览器下载的 PNG 与 SVG 栅格化图像另由 scripts/verify-browser-images.py 独立解码。

## 输入与设备兼容性

`decode_matrix` 接受按符号方向排列、包含完整定位边的规则布尔矩阵。图像采样系统可将模块读取结果传入该接口；纠错作用于数据和纠错码字。

文本接口采用 UTF-8 ECI 26。指定字符集消息保留每次 ECI 切换，解码后的原始字节始终可读取；文本转换严格检查序列和字符集编号。外部读取设备需要支持对应的 ECI 才能直接显示文本。ZXing-C++ 2.3.0 对 ECI 31～35 的文本显示存在差异，这些用例通过原始字节与 Python 对应字符集转换进行独立核对。

GS1 接口负责首位 FNC1、字段分隔及 GS1 标识恢复；商品应用负责提供符合业务要求的应用标识符和字段值。普通字节 `0x1D` 与 FNC1 的控制元数据分别保留。

144×144 使用固定上游的交织顺序，并通过 ZXing-C++ 验证。空负载可编码并由本库还原；ZXing-C++ 2.3.0 默认不返回空负载识别结果。

输出文件通过暂存文件提交，批量输出在所有条目成功后生成最终目录。已有文件受到保护；进程异常终止留下的暂存目录带有独立名称，可与最终结果区分。

## 来源与复现

上游版本、移植差异见 [MIGRATION.md](MIGRATION.md)；字符集映射、独立验证工具及样例的来源见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。[在线演示](https://gywcs101.github.io/MoonDataMatrix/) 使用与库相同的 MoonBit 核心。
