# MoonDataMatrix

[![CI](https://github.com/gywcs101/MoonDataMatrix/actions/workflows/ci.yml/badge.svg)](https://github.com/gywcs101/MoonDataMatrix/actions/workflows/ci.yml)

MoonBit 实现的 **Data Matrix 编解码库**，附原生命令行工具和完全在本地运行的浏览器演示。

**[在线演示](https://gywcs101.github.io/MoonDataMatrix/)** · [兼容性与可靠性](VALIDATION.md)

## 功能

- 24 种方形、6 种经典矩形及 18 种 DMRE 扩展矩形；默认自动方形，可选择尺寸集合或指定宽高。
- ASCII、C40、Text、X12、EDIFACT、Base256 六种模式及混合模式规划。
- 文本固定使用 UTF-8 + ECI 26；字节接口原样编码，不添加 ECI、不转码。
- 空内容允许编码；不裁剪空白、换行或 BOM；文本文件必须是合法 UTF-8。
- Reed–Solomon 纠错、交织、矩阵布置及多区域定位边全部由 MoonBit 实现。
- 黑码白底 SVG，默认 2 模块静区、4 倍缩放；浏览器可导出整数像素 PNG。
- GS1/FNC1、ECI 多段切换、Macro 05/06、Reader Programming 和最多 16 个符号的结构化追加。
- 模块矩阵解析、Reed–Solomon 纠错和六模式解码，返回原始字节、文本、控制信息及纠错数量。
- 独立字符集转换包，覆盖西欧、中文、日韩及 UTF 系列；文本按完整字符分片，符号集合可乱序重组。
- CLI 支持单条输入、JSONL 批处理、消息 JSON、矩阵解码与重组，拒绝覆盖已有输出。

中文标签请使用支持 UTF-8 ECI 的扫描器读取。全部 48 种尺寸（含 144 × 144 和 DMRE）已通过 ZXing-C++ 独立解码验证。

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

在应用的 `moon.mod` 中将 `"gywcs101/MoonDataMatrix@0.2.0"` 加入 `import` 块，再在使用该库的包中添加下面的导入。工作区会使用本地源码模块。

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
| `Dmre` | 自动选择 18 种 DMRE 尺寸 |
| `WithDmre` | 从经典与 DMRE 共 48 种尺寸中选择 |
| `Fixed(width, height)` | 指定尺寸，例如 `Fixed(18, 8)` |

固定尺寸参数按 **宽、高** 排列。

`Symbol` 提供只读矩阵访问；`matrix()` 返回副本，`module_at(x, y)` 在越界时返回 `None`。错误类型区分 `UnsupportedSize`、`CapacityExceeded`、`InvalidOption`。

`dimensions_for_codewords` 按**数据码字数量**选择尺寸。原始输入的字符与编码模式会影响码字数量，实际容量请以编码接口结果为准。

`render_svg(symbol, scale=4, quiet_zone=2)` 支持 1～1024 的整数缩放和静区；静区至少为 1。输出为黑白模块图形，仅包含渲染所需的几何数据。

## 高级消息与解码

```moonbit
let symbol = @datamatrix.encode_message([
  Text("中文", 29),
  Text("日本語", 20),
  Text("🙂", 32),
])
let decoded = @datamatrix.decode_matrix(symbol.matrix())
println(decoded.text()) // 中文日本語🙂
```

`MessageSegment` 提供 `Data(Bytes)`、`Text(String, Int)`、`Eci(Int)` 和 `Fnc1`。文本段自动转换到指定 ECI；字节段按当前 ECI 原样处理。`MessageOptions::new` 可设置 `symbol`、`gs1`、`macro_kind`（0、5、6）、`reader_programming` 和 `append`。

`encode_gs1` 接受使用 ASCII GS（29）分隔字段的元素串；`encode_macro` 接受完整 Macro 05/06 封装。GS1 元素串的应用标识符、字段长度及业务规则由调用方校验，文本采用 Latin-1。宏、读取器编程和结构化追加的互斥组合会返回参数错误。

`decode_matrix` 接受标准朝向、包含定位边的布尔模块矩阵，每个布尔值对应一个模块。`DecodedMessage` 提供 `bytes()`、`text()`、`eci_changes()`、`fnc1_positions()`，以及 `gs1`、`macro_kind`、`reader_programming`、`append` 和 `corrected_codewords`。读取照片时，应先由图像处理组件完成定位与采样。

`encode_append_text(text, file_id1, file_id2)` 按 Unicode 字符边界拆分 UTF-8 文本；`encode_append_bytes` 拆分原始字节，也可指定 ECI。二者接受 `options` 指定符号尺寸。文件标识的两个整数各为 1～254。内容能装入一个符号时返回普通符号，否则生成最多 16 片；`assemble` 对解码结果排序并检查文件标识、总数、缺片和重复片。

### 字符集

可单独导入 `gywcs101/MoonDataMatrix/charset`，调用 `encode(text, eci)` 与 `decode(bytes, eci)`。

| ECI | 字符集 |
| --- | --- |
| 2、3 | CP437、ISO-8859-1 |
| 4～13、15～18 | ISO-8859-2～11、13～16 |
| 20 | Shift JIS |
| 21～24 | Windows-1250、1251、1252、1256 |
| 25、26、27 | UTF-16 BE、UTF-8、ASCII |
| 28、29、30 | Big5、GB2312、EUC-KR |
| 31、32 | GBK、GB18030 |
| 33～35 | UTF-16 LE、UTF-32 BE、UTF-32 LE |

协议支持 ECI 0～999999 的编码及多段还原。文本转换按上表执行，其他编号仍保留 ECI 与原始字节。转换严格检查非法序列和不可表示字符；无 ECI 的数据按 Latin-1 转成文本，二进制应用直接使用 `bytes()`。映射版本和许可证见 [第三方来源](THIRD_PARTY_NOTICES.md)。

## 命令行工具

```sh
moon run cmd/main --target native -- encode --text "Hello, World!" --output hello.svg
moon run cmd/main --target native -- encode --text-file examples/sample-label.txt --output sample.svg
moon run cmd/main --target native -- encode --hex 00010203fffe807f --output binary.svg
moon run cmd/main --target native -- encode --binary-file payload.bin --output payload.svg
moon run cmd/main --target native -- batch --input examples/assets.jsonl --output asset-labels
```

`payload.bin` 表示用户准备的二进制文件。上述命令应在仓库根目录运行。

单条输入四选一，省略 `--output` 则输出 SVG 到标准输出。可添加 `--shape square|rectangle|any|dmre|all` 或 `--size WIDTHxHEIGHT`，二者互斥。十六进制必须是偶数个有效字符，不自动删除空格。

诊断只写标准错误，程序自身的退出码如下；通过 `moon run` 等启动器调用时，启动器可能转换退出码。

| 退出码 | 含义 |
| --- | --- |
| `0` | 成功 |
| `2` | 参数错误 |
| `3` | 输入或编码错误 |
| `4` | 文件读写错误 |

输出采用原子写入，并保留已有文件。单条输出在编码完成后写入，批量输出在全部条目成功后生成最终目录。

### 高级编码、解码与重组

```sh
moon run cmd/main --target native -- encode --message-file examples/gs1-message.json --output gs1.svg
moon run cmd/main --target native -- message --input examples/multilingual-message.json --output symbols.json
moon run cmd/main --target native -- encode --text "中文🙂" --format json --output matrix.json
moon run cmd/main --target native -- decode --input matrix.json
moon run cmd/main --target native -- message --input examples/append-message.json --output parts.json
moon run cmd/main --target native -- assemble --input parts.json
```

消息文件中的 `segments` 按顺序排列，每段使用 `text`（可带 `eci`，默认 26）、`hex`（可带 `eci`）、独立 `eci`，或 `fnc1: true`。顶层可设置 `gs1`、`macro`、`reader_programming`、`append` 和尺寸选项。完整示例见 [多字符集消息](examples/multilingual-message.json)、[DMRE 标签](examples/dmre-message.json)、[Macro](examples/macro-message.json) 和 [读取器编程](examples/reader-message.json)。

自动分片使用 `split: true` 和 `text` / `hex` / `segments` 中的一项，指定 `file_id1`、`file_id2` 及尺寸即可。`segments` 可混合字符集文本、原始字节、ECI 和 FNC1；文本按字符边界分片，每片保留独立读取所需的 ECI 状态。库入口为 `encode_append_message(segments, file_id1, file_id2, options=...)`，其中 `options` 为 `MessageOptions`。Macro 和 Reader Programming 消息应装入单个符号。`append` 用于手动分片，包含 `index`、`count`、`file_id1`、`file_id2`。

`message` 输出 `symbols` 数组，每项包含宽高、布尔矩阵、SVG 和解码结果。`decode` 接受布尔矩阵或包含 `matrix` 的对象；`assemble` 接受矩阵对象数组或 `symbols` 对象。解码 JSON 包含十六进制数据、文本、ECI 偏移及控制信息；文本不能转换时为 `null`，原始字节仍可读取。

### JSONL 批次规则

输入文件每行是一个独立 JSON 对象，例如：

```jsonl
{"id":"asset-0001","text":"ASSET-2026-0001"}
{"id":"asset-0002","hex":"00ff01"}
```

每行必须有 `id`，以及 `text` / `hex` / `message` 中恰好一项；`message` 为上述高级消息对象，选项在对象内指定。普通输入和单符号消息写为 `<id>.svg`；高级消息另附 `<id>.json` 矩阵集合，多符号消息写入 `<id>/part-01.svg` 等和 `<id>/symbols.json`。未知字段报错。`id` 只允许 ASCII 字母、数字、下划线和连字符，长度 1～100；为跨平台一致性，拒绝 Windows 保留设备名及大小写不敏感的重复 ID。空行无效，文件最后一个换行允许存在。

### 三条完整使用链

```sh
moon run cmd/main --target native -- batch --input examples/gs1-batch.jsonl --output gs1-labels
moon run cmd/main --target native -- assemble --input gs1-labels/batch-a.json
```

批次附带的是符号集合；取其 `symbols[0]` 对象交给 `decode`，或将整个单符号集合交给 `assemble`，即可读取 GS1 标识、字段分隔与商品数据。

```sh
moon run cmd/main --target native -- encode --message-file examples/dmre-message.json --format json --output device.json
moon run cmd/main --target native -- assemble --input device.json
moon run cmd/main --target native -- message --input examples/mixed-append.json --output exchange.json
moon run cmd/main --target native -- assemble --input exchange.json
```

DMRE 输出包含 SVG、矩阵与解码结果，可用于设备标签；多字符集消息由接收端逐矩阵解码、按文件标识重组，恢复中文、日文与 Unicode 内容。

输出目录必须不存在。全部条目成功后才发布最终目录；错误报告包含行号和条目 ID。批次内容会先保存在内存中，适合中小规模批次。

## 浏览器演示

```sh
python scripts/build-web.py
python -m http.server --directory _build/site 8080
```

打开 [本地演示](http://localhost:8080)。工作台按编码生成、矩阵解码、批量处理和符号重组组织；左侧样例库覆盖中文、二进制、GS1、DMRE、多字符集、自动分片、Macro、Reader Programming、纠错和乱序重组。文本输入可直接选择字符集，分段编辑器支持逐段指定文本字符集、原始字节、FNC1 和 ECI 切换，也可导入消息 JSON。GS1 输入中使用 `␝` 表示 FNC1 字段分隔符，也接受 ASCII GS。

浏览器批量处理接受与 CLI 相同的 JSONL 行格式，全部条目成功后展示结果，最多预览 256 个符号；更大批次可使用 CLI。结果可逐个预览，SVG/PNG 下载对应当前符号，矩阵 JSON 包含完整集合与批次条目标识。多符号消息同时展示当前分片和完整重组内容。输入变化会清除旧结果；文本、原始字节、控制信息和导出参数分别显示。所有编码和 SVG 生成调用编译出的 MoonBit JS；页面负责交互与 Canvas PNG 绘制，无上传、登录或历史记录。

## 三个可复用场景

1. **资产编号批量生成 SVG**：将资产编号写入 `examples/assets.jsonl`，运行批次命令，得到按安全 ID 命名的独立 SVG。
2. **中文样本标签**：使用浏览器的“中文样本”示例，预览并下载 SVG 或 PNG；用支持 ECI 的扫描器还原中文。
3. **二进制设备数据**：通过字节文件或十六进制输入保留零字节和高位字节，独立解码器逐字节比较，无隐式字符集猜测。

## 兼容性与可靠性

核心已在 native、JS、wasm、wasm-gc 四种后端验证，原生 CLI 覆盖 Windows、Linux、macOS。190 组用例与固定上游实现的码字、纠错和矩阵完全一致；70 组独立解码用例覆盖中文、二进制及全部经典尺寸。新增验证覆盖 ECI、GS1、Macro、结构化追加，以及外部编码器生成的矩阵与损坏模块纠错。网页下载图片也经过独立解码验证。

详细验证范围及设备兼容性说明见 [兼容性与可靠性](VALIDATION.md)。在线演示可直接在浏览器中使用；本地运行网页需要 MoonBit 和 Python 3。

## 来源与许可证

本项目采用 [MIT 许可证](LICENSE)。编码算法移植自 [datamatrix-rs](https://github.com/jannschu/datamatrix-rs)，固定提交 `af189538aee8f029dd58f317ebd4c006c9837ac2`，采用其 MIT 许可。上游作者版权声明保存在 [LICENSES/datamatrix-rs-MIT.txt](LICENSES/datamatrix-rs-MIT.txt)。

完整六模式优化器已移植；对同代价候选采用明确的排序平局规则。逐文件映射、差异及工具链说明见 [MIGRATION.md](MIGRATION.md)，第三方与测试数据来源见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
