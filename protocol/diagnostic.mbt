///|
/// Actionable diagnostics for CLI and browser adapters; library errors stay typed.
pub fn user_error(error : Error) -> String {
  match error {
    @json.ParseError::InvalidChar(pos, _)
    | @json.ParseError::InvalidIdentEscape(pos)
    | @json.ParseError::InvalidNumber(pos, _) =>
      "JSON 格式错误：第 \{pos.line} 行、第 \{pos.column + 1} 列附近。请检查引号、逗号和括号；普通文字请使用文本输入模式。"
    @json.ParseError::InvalidEof =>
      "JSON 内容不完整。请补全引号和括号；普通文字请使用文本输入模式。"
    @json.ParseError::DepthLimitExceeded =>
      "JSON 嵌套层数过多。请简化消息结构后重试。"
    @lib.EncodeError::CapacityExceeded =>
      "内容超出所选尺寸的容量。请选择自动尺寸或更大尺寸；长消息可使用自动分片，最多 16 个符号。"
    @lib.EncodeError::UnsupportedSize =>
      "不支持该符号尺寸。请从尺寸列表选择，或使用自动尺寸。"
    @lib.EncodeError::InvalidOption(reason) => option_error(reason)
    @lib.DecodeError::InvalidMatrix(_) =>
      "矩阵形状或定位边无效。请导入完整、行宽一致且包含定位边的矩阵 JSON。"
    @lib.DecodeError::UnsupportedMatrixSize =>
      "无法识别该矩阵尺寸。请使用经典 ECC 200 或 DMRE 的完整模块矩阵。"
    @lib.DecodeError::CorrectionFailed =>
      "矩阵损坏超出纠错能力。请重新采样或导入未损坏的矩阵。"
    @lib.DecodeError::InvalidText =>
      "数据无法按指定字符集转换为文本。请检查 ECI 编号；仍可读取原始字节。"
    @lib.DecodeError::InvalidCodeword(reason) =>
      if reason.contains("duplicate") {
        "符号集合包含重复分片。请每个序号只保留一个符号后重组。"
      } else if reason.contains("missing") || reason.contains("empty append") {
        "符号集合缺少分片或追加信息。请导入同一消息的完整符号集合。"
      } else if reason.contains("inconsistent") {
        "分片的文件标识或总数不一致。请仅选择同一消息的符号进行重组。"
      } else {
        "矩阵中的编码数据无效。请重新导入原始矩阵，或检查输入数据是否完整。"
      }
    InvalidRequest(reason) =>
      if reason.contains("matrix") || reason.contains("modules") {
        "矩阵 JSON 无效。请提供 matrix 数组，每行长度一致，每个模块使用 true 或 false；可从生成结果下载矩阵 JSON。"
      } else if reason.contains("symbols") {
        "缺少符号集合。请导入包含 symbols 数组的矩阵集合 JSON。"
      } else if reason.contains("split") {
        "自动分片输入无效。请设置 split 为 true，并在 text、hex、segments 中只提供一项。"
      } else if reason.contains("fnc1") || reason.contains("segment") {
        "消息分段格式错误。请提供 segments 数组，每段选择 text、hex、eci 或 fnc1 中的一种；可参考高级消息示例。"
      } else {
        "消息选项或字段格式错误。请参照高级消息示例，检查字段名称、数值和布尔值，删除未知字段。"
      }
    _ =>
      "处理失败。请检查输入并重新生成；若仍失败，请保存输入及所选选项以便反馈。"
  }
}

///|
fn option_error(reason : String) -> String {
  if reason.contains("hex") {
    "十六进制输入无效。请只填写 0–9、A–F，每个字节两位，不带空格。"
  } else if reason.contains("charset") || reason.contains("Latin-1") {
    "输入包含所选字符集无法表示的字符。请选择 UTF-8 或其他合适的字符集；GS1 文本请使用 ISO-8859-1 可表示的字符。"
  } else if reason.contains("ECI") {
    "ECI 设置无效。编号范围为 0–999999；GS1 消息请按其元素串字符集填写。"
  } else if reason.contains("append") {
    "结构化追加设置无效。总数应为 2–16，序号为 1 到总数，两个文件标识均为 1–254；自动分片请勿再指定追加头。"
  } else if reason.contains("scale") {
    "渲染参数无效。缩放与静区必须是 1–1024 的整数。"
  } else {
    "控制选项组合无效。Macro 请选择 05 或 06；Macro、读取器编程与结构化追加请按各自示例使用，避免混合互斥选项。"
  }
}
