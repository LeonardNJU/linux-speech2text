# Linux 语音输入系统 (CPU 版本)

一个简单易用的 Linux 语音转文字输入工具，基于 whisper.cpp 的 CPU 版本，支持一键录音、自动识别、直接输入。

## ✨ 特性

- 🎙️ **一键切换**: 运行一次开始录音，再次运行停止录音并识别
- 🚀 **自动输入**: 识别结果直接输入到当前焦点位置
- ⏱️ **智能提醒**: 录音时长提醒和自动停止
- 🔧 **错误处理**: 完善的错误处理和资源清理
- 🌍 **多系统支持**: 支持 Debian/Ubuntu、Arch、Fedora 等主流发行版
- 📱 **桌面集成**: 自动创建桌面快捷方式
- ⚙️ **灵活配置**: 支持自定义模型、语言、超时等参数
- 💻 **CPU 优化**: 基于 whisper.cpp，无需 GPU，纯 CPU 运行
- 🔥 **高性能**: 支持 Vulkan 加速（可选）

## 🚀 快速安装

### 自动安装（推荐）

```bash
# 克隆仓库
git clone https://github.com/yourusername/linux-speech2text.git
cd linux-speech2text

# 运行安装脚本（支持交互式配置）
chmod +x install.sh
./install.sh

# 或者使用交互式配置模式
./install.sh --interactive
```

### 手动安装

#### 1. 安装系统依赖

**Debian/Ubuntu:**
```bash
sudo apt update
sudo apt install ffmpeg socat libnotify-bin xclip git build-essential
```

**Arch Linux:**
```bash
sudo pacman -S ffmpeg socat libnotify xclip git base-devel
```

**Fedora:**
```bash
sudo dnf groupinstall "Development Tools"
sudo dnf install ffmpeg socat libnotify xclip git
```

#### 2. 构建和安装 whisper.cpp

```bash
# 克隆 whisper.cpp 仓库
git clone https://github.com/ggerganov/whisper.cpp.git /tmp/whisper.cpp
cd /tmp/whisper.cpp

# 编译 (可选择加上 Vulkan 支持)
make -j$(nproc)
# 或者带 Vulkan 支持: make WHISPER_VULKAN=1 -j$(nproc)

# 安装到用户目录
mkdir -p ~/.local/bin
cp main ~/.local/bin/whisper-cli
chmod +x ~/.local/bin/whisper-cli
```

#### 3. 下载 ggml 模型

```bash
# 创建模型目录
mkdir -p ~/.local/share/model

# 下载推荐的 small 模型 (约 244MB)
wget -P ~/.local/share/model https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin

# 或者下载其他模型:
# wget -P ~/.local/share/model https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny.bin    # 39MB
# wget -P ~/.local/share/model https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.bin    # 74MB
# wget -P ~/.local/share/model https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-medium.bin  # 769MB
# wget -P ~/.local/share/model https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin # 1550MB
```

#### 4. 安装脚本

```bash
# 复制脚本到用户目录
cp voice-toggle.sh ~/.local/bin/voice-toggle
chmod +x ~/.local/bin/voice-toggle

# 确保 ~/.local/bin 在 PATH 中
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

## ⚙️ 配置参数

在安装前，您可以根据需要调整以下配置参数。修改 `voice-toggle.sh` 脚本开头的配置区域：

### 核心配置参数

```bash
# ==================== 配置区域 ====================
readonly MAX_DURATION=60        # 最大录音时长（秒）
readonly REMINDER_TIME=50       # 提醒时间（秒）
readonly SAMPLE_RATE=16000      # 音频采样率
readonly WHISPER_MODEL="ggml-small.bin"  # ggml 模型文件名
readonly WHISPER_LANGUAGE="zh"  # 识别语言代码

# 提示音文件路径
readonly START_DING_PATHS=(
    "/usr/share/sounds/freedesktop/stereo/message-new-instant.oga"
    "$HOME/.local/share/sounds/start.wav"
)

readonly END_DING_PATHS=(
    "/usr/share/sounds/freedesktop/stereo/complete.oga"
    "$HOME/.local/share/sounds/end.wav"
)
```

### 参数说明

#### 🤖 ggml 模型选择 (`WHISPER_MODEL`)
- **ggml-tiny.bin**: 最快，准确率较低，约 39MB
- **ggml-base.bin**: 平衡选择，约 74MB
- **ggml-small.bin**: 推荐选择，约 244MB
- **ggml-medium.bin**: 高准确率，约 769MB
- **ggml-large-v3.bin**: 最高准确率，约 1550MB

#### 🌍 语言设置 (`WHISPER_LANGUAGE`)
- **zh**: 中文识别
- **en**: 英文识别
- **auto**: 自动检测语言
- 其他支持的语言：ja(日语), ko(韩语), fr(法语), de(德语), es(西班牙语) 等

#### ⏱️ 时间设置
- **MAX_DURATION**: 最大录音时长（建议 30-120 秒）
- **REMINDER_TIME**: 提醒时间，应小于 MAX_DURATION

#### 🔊 音频设置
- **SAMPLE_RATE**: 音频采样率（16000 适合语音识别）
- **START_DING_PATHS**: 开始录音提示音文件路径列表
- **END_DING_PATHS**: 结束录音提示音文件路径列表

#### 💻 性能优化
whisper.cpp 提供了多种性能优化选项：
- **CPU**: 默认使用所有 CPU 核心，兼容性最好
- **Vulkan**: 可选的 GPU 加速，支持 NVIDIA/AMD/Intel 显卡
- **AVX**: 自动检测并使用 AVX 指令集加速
- **编译优化**: 根据您的 CPU 架构优化编译

### 配置建议

**低配置设备:**
```bash
readonly WHISPER_MODEL="ggml-tiny.bin"
readonly MAX_DURATION=30
```

**高配置设备:**
```bash
readonly WHISPER_MODEL="ggml-medium.bin"
readonly MAX_DURATION=120
```

**多语言环境:**
```bash
readonly WHISPER_LANGUAGE="auto"
```

**Vulkan 加速配置:**
```bash
# 检查 Vulkan 支持
./check_vulkan.sh

# 如果支持，重新编译 whisper.cpp 时加上:
make WHISPER_VULKAN=1 -j$(nproc)
```

## 📖 使用方法

### 命令行使用

```bash
# 开始录音
voice-toggle

# 再次运行停止录音并识别
voice-toggle
```

### 快捷键绑定（推荐）

#### GNOME 桌面

```bash
# 设置 Super+V 快捷键
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/voice-input/ name '语音输入'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/voice-input/ command 'voice-toggle'
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/voice-input/ binding '<Super>v'
```

#### KDE 桌面

1. 打开 **系统设置** → **快捷键**
2. 点击 **自定义快捷键** → **新建** → **全局快捷键** → **命令/URL**
3. 设置命令为: `voice-toggle`
4. 设置快捷键为: `Meta+V`

### 使用流程

1. 🎯 **按快捷键**: 开始录音（会有提示音）
2. 🗣️ **说话**: 清晰地说出要输入的内容
3. 🎯 **再按快捷键**: 停止录音并开始识别
4. ✅ **自动输入**: 识别结果会自动输入到当前焦点位置

## 🔧 故障排除

### 音频设备问题

#### 检查音频设备
```bash
# 列出所有音频输入设备
pactl list short sources

# 查看默认音频设备
pactl info | grep "Default Source"

# 测试麦克风录音（录制 5 秒）- CPU 版本使用 ALSA
ffmpeg -f alsa -i hw:1,0 -t 5 test_recording.wav

# 播放测试录音
paplay test_recording.wav

# 列出 ALSA 录音设备
arecord -l
```

#### 音频设备故障排除
```bash
# 重启音频服务
systemctl --user restart pipewire pipewire-pulse
# 或者对于 PulseAudio
pulseaudio -k && pulseaudio --start

# 检查音频服务状态
systemctl --user status pipewire
```

### 常见问题

1. **录音失败**
   - 检查麦克风权限
   - 确认 PulseAudio/PipeWire 正在运行: `pactl info`
   - 测试录音设备: `ffmpeg -f alsa -i hw:1,0 -t 3 test.wav`

2. **识别结果为空**
   - 检查录音音量是否足够
   - 确认说话清晰度
   - 播放录音文件检查质量: `paplay /tmp/voice_input/voice_input.wav`

3. **无法输入文字**
   - 确保安装了 `xdotool` 或 `xclip`
   - 检查目标应用是否有焦点

4. **首次使用很慢**
   - 首次运行 whisper-cli 会加载模型到内存
   - 确保模型文件存在: `ls ~/.local/share/model/`
   - 检查模型是否损坏，重新下载

5. **Vulkan 加速不工作**
   - 运行 Vulkan 检测脚本: `./check_vulkan.sh`
   - 重新编译 whisper.cpp: `make WHISPER_VULKAN=1 clean && make WHISPER_VULKAN=1`
   - 检查显卡驱动是否正确安装

6. **录音设备错误 (hw:1,0 不存在)**
   - 运行 `arecord -l` 查看可用设备
   - 修改脚本中的 `hw:1,0` 为正确的设备号

### 日志查看

```bash
# 查看详细日志
tail -f /tmp/voice_input/voice_input.log

# 查看最近的错误
grep "ERROR" /tmp/voice_input/voice_input.log
```

## 📁 文件和目录结构

### 项目文件
```
linux-speech2text/
├── voice-toggle.sh              # 主脚本文件
├── install.sh                   # 自动安装脚本
├── model_benchmark.py           # 模型性能测试工具
├── test_voice_system.sh         # 系统测试脚本
├── setup_shortcuts.sh           # 快捷键设置脚本
├── README.md                    # 说明文档
└── LICENSE                      # 许可证
```

### 安装后的文件位置

#### 脚本安装位置
- **主脚本**: `~/.local/bin/voice-toggle`
- **配置目录**: `~/.config/voice-input/`
- **提示音文件**: `~/.local/share/sounds/`
- **桌面快捷方式**: `~/.local/share/applications/voice-input.desktop`

#### 运行时文件位置
- **临时目录**: `/tmp/voice_input/`
- **录音文件**: `/tmp/voice_input/voice_input.wav`
- **日志文件**: `/tmp/voice_input/voice_input.log`
- **进程文件**: `/tmp/voice_input/recording.pid`

#### ggml 模型存储位置
- **存储位置**: `~/.local/share/model/`
- **模型文件**: 根据选择的模型大小，文件大小从 39MB 到 1550MB 不等

## 🎯 性能优化

### Vulkan 加速设置 (可选)
```bash
# 检查 Vulkan 支持
./check_vulkan.sh

# 如果支持 Vulkan，重新编译 whisper.cpp
cd /tmp/whisper.cpp
make clean
make WHISPER_VULKAN=1 -j$(nproc)
cp main ~/.local/bin/whisper-cli
```

### 模型性能测试
```bash
# 测试不同模型的性能 (需要先下载对应模型)
time whisper-cli -m ~/.local/share/model/ggml-tiny.bin -l zh test.wav
time whisper-cli -m ~/.local/share/model/ggml-small.bin -l zh test.wav
time whisper-cli -m ~/.local/share/model/ggml-medium.bin -l zh test.wav

# 查看 CPU 使用情况
htop
```

### 优化建议
- **模型选择**: 根据设备性能选择合适大小的模型
- **内存优化**: 使用较小的模型可以减少内存占用  
- **CPU 优化**: whisper.cpp 已经针对 CPU 进行了大量优化
- **Vulkan 加速**: 如果有独立显卡，启用 Vulkan 可显著提升性能
- **编译优化**: 根据您的 CPU 架构重新编译可获得最佳性能

## 🔍 测试和调试

### 系统测试
```bash
# 运行完整系统测试
./test_voice_system.sh

# 测试音频设备
./test_voice_system.sh --audio-only
```

### 手动测试录音和识别
```bash
# 测试 5 秒录音 (CPU 版本使用 ALSA)
ffmpeg -f alsa -i hw:1,0 -t 5 -y test_manual.wav

# 播放录音检查质量
paplay test_manual.wav

# 使用 whisper-cli 测试识别
whisper-cli -m ~/.local/share/model/ggml-small.bin -l zh test_manual.wav
```

## 🚀 未来开发计划

目前有一些将来的更新计划
- 实时输入系统,也就是说你可以一边说话,文字就一边上屏,并且可根据你说的话进行一些实时修改
- 手机端作为外接麦克风, 甚至是网络输入方式: 通过公网服务器作为跳板机,用户在手机端下达命令,而通过一些远程桌面服务查看当前Agent的工作状态,已达到`Vibe programming`的目标

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

本项目采用 Apache License 2.0 许可证。