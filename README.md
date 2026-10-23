# MoonDataMatrix

[![CI](https://github.com/gywcs101/MoonDataMatrix/actions/workflows/ci.yml/badge.svg)](https://github.com/gywcs101/MoonDataMatrix/actions/workflows/ci.yml)

MoonBit 实现的 **Data Matrix ECC 200 编码库**，附原生命令行工具和完全在本地运行的浏览器演示。

**[在线演示](https://gywcs101.github.io/MoonDataMatrix/)** · [初审申报书](SUBMISSION.md) · [验证记录](VALIDATION.md)

当前为 `0.1.0` 发布准备阶段，尚未发布到 Mooncakes。GitHub 主分支可直接构建。项目不宣称通过 ISO 全条款认证。

## 功能与边界

- 24 种方形、6 种经典矩形尺寸，默认自动方形，可选择矩形、全部尺寸或指定宽高。
- ASCII、C40、Text、X12、EDIFACT、Base256 六种模式及混合模式规划。
- 文本固定使用 UTF-8 + ECI 26；字节接口原样编码，不添加 ECI、不转码。
- 空内容允许编码；不裁剪空白、换行或 BOM；文本文件必须是合法 UTF-8。
- Reed–Solomon 纠错、交织、矩阵布置及多区域定位边全部由 MoonBit 实现。
- 黑码白底 SVG，默认 2 模块静区、4 倍缩放；浏览器可导出整数像素 PNG。
- CLI 支持单条输入和 JSONL 批处理，拒绝覆盖已有输出。

首版不包含 GS1、DMRE、解码、摄像头、Structured Append、Macro 05/06 自动转换、标签排版和打印质量认证。中文显示取决于扫描器的 ECI 支持；空负载在 ZXing-C++ 默认识别流程中没有返回结果。144×144 采用固定上游的交织方式，不保证所有历史扫描器兼容。

## 快速开始

开发基线：`moonc v0.10.14+7d59c7ec9`、`moon 0.1.20260920`。CI 固定此版本；CLI 适配层使用 `moonbitlang/x@0.5.4`，编码核心仅依赖标准库。

```sh
git clone https://github.com/gywcs101/MoonDataMatrix.git
cd MoonDataMatrix
moon update
moon check --target all --deny-warn
moon test --target all --deny-warn
moon run examples/basic --target native
```

最后一条命令输出中文标签的 SVG。正式发布后才可用 `moon add gywcs101/datamatrix` 安装；当前独立集成方式见 `scripts/test-consumer.py`，它从实际发布压缩包创建独立工作区。

## 库接口

包别名取决于消费者自己的 `moon.pkg`；例如：

```moonbit
import { "gywcs101/datamatrix" @datamatrix }
```

```moonbit
fn main raise {
  let text = @datamatrix.encode_text("样本编号：LAB-2026-001")
  println(@datamatrix.render_svg(text))
  let binary = @datamatrix.encode_bytes(b"\x00\xff\x01")
  println(binary.width())
}
```

指定选项：`options={shape: Fixed(32, 32)}`，或 `Square`、`Rectangle`、`Any`。固定尺寸参数按 **宽、高** 排列，例如 `Fixed(18, 8)`。

`Symbol` 的内部矩阵不可由调用者修改；`matrix()` 返回副本，`module_at(x, y)` 在越界时返回 `None`。错误类型区分 `UnsupportedSize`、`CapacityExceeded`、`InvalidOption`。

`dimensions_for_codewords` 的输入是数据码字数量，**不是原始字节数**。不同字符与模式会影响容量，实际能否容纳请以编码接口结果为准。

`render_svg(symbol, scale=4, quiet_zone=2)` 支持 1～1024 的整数缩放和静区；静区至少为 1。输出不嵌入原始负载，不支持颜色、Logo 或装饰效果。

## CLI

```sh
moon run cmd/main --target native -- encode --text "Hello, World!" --output hello.svg
moon run cmd/main --target native -- encode --text-file examples/sample-label.txt --output sample.svg
moon run cmd/main --target native -- encode --hex 00010203fffe807f --output binary.svg
moon run cmd/main --target native -- encode --binary-file payload.bin --output payload.svg
moon run cmd/main --target native -- batch --input examples/assets.jsonl --output asset-labels
```

单条输入四选一，省略 `--output` 则输出 SVG 到标准输出。可添加 `--shape square|rectangle|any` 或 `--size WIDTHxHEIGHT`，二者互斥。十六进制必须是偶数个有效字符，不自动删除空格。

退出码：成功 0、参数错误 2、输入或编码错误 3、文件读写错误 4。诊断只写标准错误。封装启动器可能另有自己的退出码；测试直接定位实际构建的程序验证这些约定，不依赖固定构建目录。

已有文件绝不覆盖；先生成全部内容，再在同一文件系统暂存并使用不替换目标的原子重命名。操作系统崩溃可能留下 `.tmp-*` 暂存目录，不能将其当作最终结果。

### JSONL 批次规则

```json
{"id":"asset-0001","text":"ASSET-2026-0001"}
{"id":"asset-0002","hex":"00ff01"}
```

每行必须有 `id`，以及 `text` / `hex` 中恰好一个字符串字段；未知字段报错。`id` 只允许 ASCII 字母、数字、下划线和连字符，长度 1～100；为跨平台一致性，拒绝 Windows 保留设备名及大小写不敏感的重复 ID。空行无效，文件最后一个换行允许存在。

输出目录必须不存在。全部条目成功后才发布最终目录；错误报告包含行号和条目 ID。批次内容会先保存在内存中，首版适合中小规模批次。

## 浏览器演示

```sh
python scripts/build-web.py
python -m http.server --directory web 8080
```

打开 `http://localhost:8080`。页面支持文本/十六进制、尺寸选择、预览、SVG/PNG 下载和三组示例。输入变化会清除旧结果，避免下载错误对应的图片。所有编码和 SVG 生成调用编译出的 MoonBit JS；页面仅处理交互与 Canvas PNG 绘制，无上传、登录或历史记录。

## 三个可复用场景

1. **资产编号批量生成 SVG**：将资产编号写入 `examples/assets.jsonl`，运行批次命令，得到按安全 ID 命名的独立 SVG。
2. **中文样本标签**：使用浏览器的“中文样本”示例，预览并下载 SVG 或 PNG；用支持 ECI 的扫描器还原中文与 emoji。
3. **二进制设备数据**：通过字节文件或十六进制输入保留零字节和高位字节，独立解码器逐字节比较，无隐式字符集猜测。

## 验证

```sh
moon check --target all --deny-warn
moon build --target all --deny-warn
moon test --target all --deny-warn
moon fmt --check
moon info
python -m pip install -r requirements-dev.txt
python scripts/test-interop.py
python scripts/test-cli.py
python scripts/verify-package.py
python scripts/test-consumer.py
```

Rust 仅用于开发差分验证，版本基线 1.99.1；最终用户不需要 Rust 或 Python：

```sh
python scripts/test-differential.py
```

该脚本锁定上游提交和 Cargo.lock，动态生成并删除白盒测试，比较数据码字、完整纠错码字及矩阵。`--quick` 运行较小的回归集。初次运行需下载 Rust 依赖。

浏览器验证：

```sh
python scripts/build-web.py
npm ci --prefix tests/browser --ignore-scripts
node tests/browser/node_modules/playwright/cli.js install chromium
node tests/browser/test.mjs
python scripts/verify-browser-images.py
```

测试数据均为有来源的参考向量或原创合成数据。详细状态见 [VALIDATION.md](VALIDATION.md)。当前 `moon.mod` 中的版本号表示目标发布版本，不能据此认为 Mooncakes 已发布。

## 来源与许可证

MIT。编码算法移植自 [datamatrix-rs](https://github.com/jannschu/datamatrix-rs)，固定提交 `af189538aee8f029dd58f317ebd4c006c9837ac2`，采用其 MIT 许可。上游作者版权声明保存在 [LICENSES/datamatrix-rs-MIT.txt](LICENSES/datamatrix-rs-MIT.txt)。

完整六模式优化器已移植；对同代价候选采用明确的排序平局规则。项目不承诺所有输入全局最优。逐文件映射、差异及工具链说明见 [MIGRATION.md](MIGRATION.md)，第三方与测试数据来源见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
