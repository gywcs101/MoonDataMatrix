# 兼容性与可靠性

本地实现验证：2026-10-22；远端与在线交付复核：2026-10-23。以下记录对应已验证版本的支持范围与使用限制。

## 本地已经验证

- MoonBit 12 个测试块在 native、JS、wasm、wasm-gc 上通过；其中包含多组循环用例。覆盖尺寸关系、纠错参考向量、30 种布置、ASCII、C40/Text、X12/EDIFACT、Base256 边界、UTF-8、接口保护及优化器结束规则。
- 固定 datamatrix-rs 提交的 172 组差分用例：数据码字、完整纠错码字、尺寸及每一个矩阵模块完全一致。`scripts/test-differential.py` 可重现。
- ZXing-C++ 对中文、emoji、空白/BOM、全部字节值、随机二进制、1555 字节大尺寸、30 种经典尺寸逐字节还原；`scripts/test-interop.py` 的固定语料持续纳入 CI。
- CLI：中文命令行参数、文本/字节文件、十六进制、退出码、无效输入、不覆盖文件、JSONL 校验、批次失败无最终目录与 SVG 解码通过。
- 浏览器：预览、错误提示、输入变化清除旧结果、SVG/PNG 下载通过。下载 PNG 与浏览器实际渲染 SVG 后生成的图片均由 ZXing-C++ 成功还原中文样例。
- 实际压缩包检查：源码、README、许可证、来源说明和实例齐全；没有 node_modules、Rust 构建目录、测试产物、调研缓存或凭据。
- 独立消费者：从实际压缩包解出的库导入新的 MoonBit 模块，四种后端测试通过。此项验证本地包，不能替代发布后从 Mooncakes 实际安装验证。

## 远端 CI

GitHub Actions 的 `CI` 工作流覆盖 Windows/Linux/macOS native 与 CLI；Linux 额外覆盖四后端、生成接口一致性、固定上游差分、独立解码、消费者和浏览器测试。

[主分支 CI 记录](https://github.com/gywcs101/MoonDataMatrix/actions/workflows/ci.yml)提供各提交的检查结果。

### 已核实的远端记录

实现提交：`3f2ef302b3bc662cf042a930ef381db2d7c490cf`。

- [CI 成功记录](https://github.com/gywcs101/MoonDataMatrix/actions/runs/39780885239)：Windows/Linux/macOS native、Linux 四后端、172 组上游差分、独立解码、消费者和浏览器验证均通过。
- [演示部署成功记录](https://github.com/gywcs101/MoonDataMatrix/actions/runs/39780885230)。
- [在线演示](https://gywcs101.github.io/MoonDataMatrix/)：2026-10-23 实际浏览器访问验证了预览、中文示例、PNG 下载及五个许可说明链接。下载 PNG 由 ZXing-C++ 成功还原 UTF-8 原始字节。
- `scripts/test-interop.py` 当前包含 52 组独立解码用例，包括最大数字容量 3116 位的原始字节输入。

上述验证结果对应所列实现提交。

## 已知边界

- 未取得完整 ISO/IEC 16022:2024 付费正文，不宣称标准认证。
- 本项目不声明对所有输入的全局最优编码；排序平局处理的移植差异详见 MIGRATION.md。
- 空负载库内编码测试通过，但 ZXing-C++ 2.3.0 默认不返回识别结果，未计入成功扫码用例。
- 144×144 按固定上游交织，现有 ZXing-C++ 用例通过；未验证所有历史扫描器。
- 中文设备显示依赖 ECI 支持。
- 本地未模拟断电；崩溃可能留下命名明确的暂存目录。正常错误不会暴露半批最终目录。
- 当前消费者验证使用本地发布包；尚未发布 Mooncakes `0.1.0`，尚无正式安装结果。
