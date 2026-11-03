# 基于 FPGA 的实时多音色合成电子乐器

2026 年全国大学生嵌入式芯片与系统设计竞赛 FPGA 赛道参赛工程。

我们用高云 GW5AT-60K 实现音频合成、包络、混音和效果处理。八个压力区负责选音和力度，触摸板、旋钮、手势及光电拨弦提供演奏控制。声音经 I²S 输出到 PCM5102，再接有源音响；Android 控制端通过蓝牙调参数、传曲谱和接收演奏录音。

## 功能

- 口琴、尼龙吉他、钢琴三种音色，支持 ADSR、分区音高、和弦及吉他自动扫弦。
- 128 路合成测试，支持分页查看、逐路关闭和恢复。
- 混响、回声、合唱，以及滑音、颤音；三种乐器分别保存调音台参数。
- HDMI 实时波形、频谱、李萨如图，脱机 LED 曲谱指引和音游。
- 手机端参数控制、曲谱与曲名上传、键位音高设置及录音回传。

## 目录

```text
FPGA/         Gowin 工程、RTL、约束、IP、初始化数据及测试平台
Android/      手机端 Java 源码、构建脚本与协议测试
仿真工具/     Verilator 构建、音色分析等脚本
下载文件/     FPGA 烧录文件和 Android 安装包
说明.txt      开发环境及使用说明
```

## 编译与运行

FPGA 使用 **Gowin EDA V1.9.12.04**，器件为 **GW5AT-LV60PG484AC1/I0**。打开 `FPGA/pressure_ws2812_dualpcm.gprj`，执行综合和布局布线；顶层为 `pressure_poly8_top`。命令行构建入口是 `FPGA/build.tcl`，管脚与时钟约束在 `FPGA/constraints/`。

手机端需要配置 `JAVA_HOME` 和 `ANDROID_SDK_ROOT`，安装 Android SDK 35、Build Tools 35.0.0，在 `Android/` 下运行：

```sh
python build.py
```

生成的 APK 位于 `Android/build/`。构建脚本会创建本地测试签名；与手机已安装应用签名不同时，需要先卸载旧应用再安装。

已有的烧录文件和安装包在 `下载文件/`。蓝牙模块 UART 波特率为 **115200**，模块 TX/RX 与 FPGA RX/TX 交叉连接并共地。音频输出使用 **PCM5102 + 有源音响**。

## 仿真

`FPGA/tb/` 保存测试平台，`FPGA/run_v13_checks.py` 接收测试模块名，使用 Icarus Verilog 运行。可用 `IVERILOG_BIN` 指定安装目录；涉及 Gowin 原生 IP 的测试需要对应仿真库。

使用 `仿真工具/` 中的脚本前，设置 `CONSOLE60_SOURCE`、`CONSOLE60_OSS_SUITE`、`CONSOLE60_LLVM_BIN`。音色分析脚本中使用的参考文件路径按本机位置调整，详细说明见 `说明.txt`。
