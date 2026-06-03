# VoiceInput

VoiceInput 是一个 macOS 菜单栏语音输入工具。按住快捷键说话后，它会使用 Apple Speech Recognition 转写语音，并把结果粘贴到当前光标所在位置。

## 功能

- 双击并按住 Option 进行语音输入
- 支持英语、简体中文、繁体中文、日语、韩语
- 可在 App 内单独选择麦克风，不影响系统默认输入设备
- 支持外置麦克风、AirPods、MacBook 内置麦克风等输入源
- 录音时显示浮窗、实时转写文本和 5 根腾讯蓝电平柱
- 可选 LLM 润色，用于修正明显的语音识别错误
- 自动粘贴到当前应用，并尽量恢复原剪贴板内容

## 系统要求

- macOS 14 或更新版本
- Swift 5.9 或更新版本
- 需要授予麦克风、语音识别和辅助功能权限

## 安装

在项目目录中执行：

```bash
make install
```

这会构建并安装到：

```text
/Applications/VoiceInput.app
```

安装完成后启动：

```bash
open /Applications/VoiceInput.app
```

开发时也可以直接运行构建产物：

```bash
make run
```

## 第一次启动授权

第一次启动后，系统会请求相关权限。请在 macOS 系统设置中允许：

- `麦克风`：用于录制语音
- `语音识别`：用于调用 Apple Speech Recognition
- `辅助功能`：用于监听全局 Option 快捷键和自动粘贴文本

如果快捷键没有反应，优先检查：

```text
系统设置 -> 隐私与安全性 -> 辅助功能 -> VoiceInput
```

如果显示无法开始录音或没有声音，检查：

```text
系统设置 -> 隐私与安全性 -> 麦克风 -> VoiceInput
系统设置 -> 隐私与安全性 -> 语音识别 -> VoiceInput
```

## 使用方法

1. 把光标放到要输入文字的位置。
2. 快速短按一次 Option。
3. 第二次按下 Option 后不要松手，开始说话。
4. 说完后松开 Option。
5. VoiceInput 会转写语音，并把文本粘贴到当前光标位置。

注意：快捷键是 `Double-tap and hold Option`，不是双击后自动录音。第二次 Option 必须按住，松开就会结束录音。

## 菜单说明

VoiceInput 启动后会出现在 macOS 菜单栏，图标是麦克风。

### Language

选择语音识别语言：

- English
- Simplified Chinese
- Traditional Chinese
- Japanese
- Korean

默认语言是 `Simplified Chinese`。

### Microphone

选择 VoiceInput 使用的输入设备：

- `System Default`：跟随 macOS 当前默认输入设备
- 具体麦克风设备：例如 MacBook 内置麦克风、外置麦克风、AirPods 麦克风

这个设置只影响 VoiceInput，不会修改 macOS 系统默认输入。因此可以让其他软件继续使用 AirPods，同时让 VoiceInput 固定使用外置麦克风。

`Microphone` 菜单每次打开都会重新扫描设备，所以运行期间插拔麦克风后不需要重启 App。

### LLM Refinement

可选的语音文本修正功能。

- `Enabled`：开启或关闭 LLM 润色
- `Settings...`：配置 API Base URL、API Key 和 Model

默认配置：

```text
API Base URL: https://api.openai.com/v1
Model: gpt-4o-mini
```

LLM 润色只做保守修正，例如把明显的识别错误改成正确技术词，不会主动扩写、翻译或改写内容。如果 API 请求失败，会回退使用原始识别文本。

## 常见问题

### 双击 Option 后没有开始录音

检查辅助功能权限。VoiceInput 需要辅助功能权限才能监听全局快捷键。

### UI 显示 Listening，但电平不动

通常是输入设备没有声音或选择了错误麦克风。

处理方式：

1. 打开菜单栏 `VoiceInput -> Microphone`
2. 选择一个明确的输入设备，例如外置麦克风或 MacBook Pro 麦克风
3. 再次按住 Option 录音

如果 AirPods 连接后没有输入，可以让系统和其他软件继续使用 AirPods，但在 VoiceInput 的 `Microphone` 菜单里选择外置麦克风。

### 显示 Selected microphone unavailable

之前选择的麦克风已经断开。重新打开 `Microphone` 菜单，选择一个当前存在的设备。

### 显示 Unable to start microphone

说明音频引擎没有启动成功。常见原因是设备正在切换、蓝牙输入状态异常或权限未生效。

可以尝试：

1. 重新选择 `Microphone`
2. 拔插外置麦克风
3. 退出并重新打开 VoiceInput
4. 检查麦克风权限

### 显示 Enable Speech Recognition permission

需要开启语音识别权限：

```text
系统设置 -> 隐私与安全性 -> 语音识别 -> VoiceInput
```

### 识别完成后没有粘贴

检查辅助功能权限。VoiceInput 通过模拟 `Command + V` 把文本粘贴到当前应用。

## 开发命令

```bash
swift build
swift build -c release
make build
make run
make install
make clean
```

## 项目结构

```text
Sources/VoiceInput/
  AppDelegate.swift              菜单栏入口和权限请求
  DictationController.swift      录音状态机、转写、润色和粘贴流程
  SpeechTranscriber.swift        Apple Speech Recognition 和音频输入
  AudioInputDeviceManager.swift  CoreAudio 输入设备枚举与选择
  FloatingTranscriptPanel.swift  录音浮窗
  WaveformView.swift             电平柱显示
  TextInjector.swift             自动粘贴和剪贴板恢复
  LLMRefiner.swift               可选 LLM 润色
```

## 卸载

退出 VoiceInput 后删除应用：

```bash
rm -rf /Applications/VoiceInput.app
```

如果还想清除本地设置，可以删除 `com.local.voiceinput` 的用户默认配置。
