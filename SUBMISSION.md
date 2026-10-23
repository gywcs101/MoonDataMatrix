# MoonDataMatrix 初审申报书

## 项目名称与简介

MoonDataMatrix：MoonBit Data Matrix ECC 200 编码库。提供可复用库、原生 CLI、浏览器演示，面向资产编号、中文样本标签与二进制标识数据。

## 项目方向及核心功能

方向：标准编码工具与 MoonBit 生态组件。核心编码使用 MoonBit，实现六种模式、自动模式规划、30 种经典尺寸、Reed–Solomon 纠错和交织、矩阵布置与 SVG 输出。原生适配层负责文件和原子输出，浏览器使用编译生成的 MoonBit JS。

## 三个完整使用场景

1. 资产管理员准备包含资产 ID 与编号的 JSONL → CLI 检查全部记录 → 生成独立 SVG → 全批成功后发布目标目录 → 资产系统导入这些图片。重复 ID 或非法记录不会产生半批最终目录。
2. 实验人员输入中文样本编号和备注 → 浏览器选择尺寸并预览 → 下载 SVG/PNG → 支持 ECI 的扫描器还原中文。处理过程不上传样本信息，演示数据为虚构数据。
3. 设备开发者输入包含零字节和高位字节的二进制数据 → 字节接口或 CLI 编码 → 独立 ZXing-C++ 解码 → 与原始字节逐项比较，用于设备标识与离线传递。

## 原创与移植范围

项目为成熟开源编码算法的 MoonBit 移植，加上原创公共 API、SVG 渲染、安全输出 CLI 和浏览器交互。

- 来源：https://github.com/jannschu/datamatrix-rs
- 固定提交：`af189538aee8f029dd58f317ebd4c006c9837ac2`
- 上游许可证：MIT 或 Apache-2.0，本项目选择 MIT。
- 参考范围：编码模式、尺寸表、纠错、布置与完整六模式规划器；不移植解码器。
- 同代价候选采用明确的排序平局规则，详见 MIGRATION.md。
- THIRD_PARTY_NOTICES.md 和 LICENSES/ 保留来源、许可与版权信息。

## 首版边界

文本始终 UTF-8 + ECI 26；字节接口不转码。首版不实现 GS1、DMRE、扫码识别、Structured Append、自动 Macro 转换、标签排版或打印质量认证。没有获取完整付费 ISO 正文，不宣称全部标准条款认证或所有输入全局最优。

## 仓库与工程证据

- 在线演示：https://gywcs101.github.io/MoonDataMatrix/
- 公开仓库：https://github.com/gywcs101/MoonDataMatrix
- 提交历史：https://github.com/gywcs101/MoonDataMatrix/commits/main/
- CI：https://github.com/gywcs101/MoonDataMatrix/actions/workflows/ci.yml
- 运行方式和实例：README.md、examples/、web/
- 详细验证范围与剩余事项：VALIDATION.md

开发过程保留真实提交，包含基础组件、编码模式、CLI、网页和优化器替换；不空提交、不改写提交时间。Gitlink 不作为本轮阻塞项。

## 发布状态

目标模块 `gywcs101/datamatrix`，目标正式版本 `0.1.0`，MIT。当前未发布 Mooncakes，正式发布安排在初审后工程验收完成时，届时核对远端版本、构建状态与实际安装结果。

## 初审交付核对（2026-10-23）

实现提交 `3f2ef302b3bc662cf042a930ef381db2d7c490cf` 的多平台 CI 与静态演示部署均成功。在线演示的中文预览、PNG 下载、许可链接已实际访问验证，下载 PNG 经独立解码器逐字节还原成功。仓库已有不少于 10 条真实提交。此次核对不代表主办方初审已通过，申报材料尚未代为提交。
