# MoonDataMatrix

[![CI](https://github.com/gywcs101/MoonDataMatrix/actions/workflows/ci.yml/badge.svg)](https://github.com/gywcs101/MoonDataMatrix/actions/workflows/ci.yml)

MoonBit 实现的 **Data Matrix ECC 200 编码库**，附原生命令行工具和完全在本地运行的浏览器演示。

**[在线演示](https://gywcs101.github.io/MoonDataMatrix/)** · [兼容性与可靠性](VALIDATION.md)

## 功能

- 24 种方形、6 种经典矩形尺寸，默认自动方形，可选择矩形、全部尺寸或指定宽高。
- ASCII、C40、Text、X12、EDIFACT、Base256 六种模式及混合模式规划。
- 文本固定使用 UTF-8 + ECI 26；字节接口原样编码，不添加 ECI、不转码。
- 空内容允许编码；不裁剪空白、换行或 BOM；文本文件必须是合法 UTF-8。
- Reed–Solomon 纠错、交织、矩阵布置及多区域定位边全部由 MoonBit 实现。
- 黑码白底 SVG，默认 2 模块静区、4 倍缩放；浏览器可导出整数像素 PNG。
- CLI 支持单条输入和 JSONL 批处理，拒绝覆盖已有输出。

中文标签请使用支持 UTF-8 ECI 的扫描器读取。全部 30 种经典尺寸（含 144 × 144）已通过 ZXing-C++ 独立解码验证。

## 快速开始

源码运行环境：`moonc v0.10.14+7d59c7ec9`、`moon 0.1.20260920`。CLI 使用 `moonbitlang/x@0.5.4`，编码核心仅依赖标准库。

```sh
git clone https://github.com/gywcs101/MoonDataMatrix.git
cd MoonDataMatrix
moon update
moon run examples/basic --target native
```

最后一条命令输出中文标签的 SVG。

### 在自己的应用中使用

将本仓库与已有 MoonBit 应用（以下名为 `myapp`）放在同一个父目录，在该父目录运行：

```sh
moon work init
moon work use MoonDataMatrix myapp
```

在应用的 `moon.mod` 中将 `"gywcs101/MoonDataMatrix@0.1.0"` 加入 `import` 块，再在使用该库的包中添加下面的导入。工作区会使用本地源码模块。

## 库接口

在应用包的 `moon.pkg` 中添加导入（已有 `import` 块时合并条目）：

```text
import { "gywcs101/MoonDataMatrix" @datamatrix }
```

使用示例：

```moonbit
fn main raise {
  let text = @datamatrix.encode_text("样本编号：LAB-2026-001")
  println(@datamatrix.render_svg(text))
  let binary = @datamatrix.encode_bytes(b"\x00\xff\x01")
  println(binary.width())
}
```

通过 `options` 参数选择形状，例如 `options={shape: Fixed(32, 32)}`。

| 形状选项 | 行为 |
| --- | --- |
| `Square` | 自动选择方形，默认选项 |
| `Rectangle` | 自动选择经典矩形 |
| `Any` | 从全部 30 种经典尺寸中选择 |
| `Fixed(width, height)` | 指定尺寸，例如 `Fixed(18, 8)` |

固定尺寸参数按 **宽、高** 排列。

`Symbol` 提供只读矩阵访问；`matrix()` 返回副本，`module_at(x, y)` 在越界时返回 `None`。错误类型区分 `UnsupportedSize`、`CapacityExceeded`、`InvalidOption`。

`dimensions_for_codewords` 按**数据码字数量**选择尺寸。原始输入的字符与编码模式会影响码字数量，实际容量请以编码接口结果为准。

`render_svg(symbol, scale=4, quiet_zone=2)` 支持 1～1024 的整数缩放和静区；静区至少为 1。输出为黑白模块图形，仅包含渲染所需的几何数据。

## 命令行工具

```sh
moon run cmd/main --target native -- encode --text "Hello, World!" --output hello.svg
moon run cmd/main --target native -- encode --text-file examples/sample-label.txt --output sample.svg
moon run cmd/main --target native -- encode --hex 00010203fffe807f --output binary.svg
moon run cmd/main --target native -- encode --binary-file payload.bin --output payload.svg
moon run cmd/main --target native -- batch --input examples/assets.jsonl --output asset-labels
```

`payload.bin` 表示用户准备的二进制文件。上述命令应在仓库根目录运行。

单条输入四选一，省略 `--output` 则输出 SVG 到标准输出。可添加 `--shape square|rectangle|any` 或 `--size WIDTHxHEIGHT`，二者互斥。十六进制必须是偶数个有效字符，不自动删除空格。

诊断只写标准错误，程序自身的退出码如下；通过 `moon run` 等启动器调用时，启动器可能转换退出码。

| 退出码 | 含义 |
| --- | --- |
| `0` | 成功 |
| `2` | 参数错误 |
| `3` | 输入或编码错误 |
| `4` | 文件读写错误 |

输出采用原子写入，并保留已有文件。单条输出在编码完成后写入，批量输出在全部条目成功后生成最终目录。

### JSONL 批次规则

输入文件每行是一个独立 JSON 对象，例如：

```jsonl
{"id":"asset-0001","text":"ASSET-2026-0001"}
{"id":"asset-0002","hex":"00ff01"}
```

每行必须有 `id`，以及 `text` / `hex` 中恰好一个字符串字段；未知字段报错。`id` 只允许 ASCII 字母、数字、下划线和连字符，长度 1～100；为跨平台一致性，拒绝 Windows 保留设备名及大小写不敏感的重复 ID。空行无效，文件最后一个换行允许存在。

输出目录必须不存在。全部条目成功后才发布最终目录；错误报告包含行号和条目 ID。批次内容会先保存在内存中，适合中小规模批次。

## 浏览器演示

```sh
python scripts/build-web.py
python -m http.server --directory web 8080
```

打开 [本地演示](http://localhost:8080)。页面支持文本/十六进制、尺寸选择、预览、SVG/PNG 下载和三组示例。输入变化会清除旧结果，避免下载错误对应的图片。所有编码和 SVG 生成调用编译出的 MoonBit JS；页面仅处理交互与 Canvas PNG 绘制，无上传、登录或历史记录。

## 三个可复用场景

1. **资产编号批量生成 SVG**：将资产编号写入 `examples/assets.jsonl`，运行批次命令，得到按安全 ID 命名的独立 SVG。
2. **中文样本标签**：使用浏览器的“中文样本”示例，预览并下载 SVG 或 PNG；用支持 ECI 的扫描器还原中文与 emoji。
3. **二进制设备数据**：通过字节文件或十六进制输入保留零字节和高位字节，独立解码器逐字节比较，无隐式字符集猜测。

## 兼容性与可靠性

核心已在 native、JS、wasm、wasm-gc 四种后端验证，原生 CLI 覆盖 Windows、Linux、macOS。172 组用例与固定上游实现的码字、纠错和矩阵完全一致；52 组独立解码用例覆盖中文、二进制及全部经典尺寸。网页下载图片也经过独立解码验证。

详细验证范围及设备兼容性说明见 [兼容性与可靠性](VALIDATION.md)。在线演示可直接在浏览器中使用；本地运行网页需要 MoonBit 和 Python 3。

## 来源与许可证

本项目采用 [MIT 许可证](LICENSE)。编码算法移植自 [datamatrix-rs](https://github.com/jannschu/datamatrix-rs)，固定提交 `af189538aee8f029dd58f317ebd4c006c9837ac2`，采用其 MIT 许可。上游作者版权声明保存在 [LICENSES/datamatrix-rs-MIT.txt](LICENSES/datamatrix-rs-MIT.txt)。

完整六模式优化器已移植；对同代价候选采用明确的排序平局规则。逐文件映射、差异及工具链说明见 [MIGRATION.md](MIGRATION.md)，第三方与测试数据来源见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
