# Linux 语音输入系统

[DEPRECATED] 目前此系统已废弃, 现在使用[VocoType-ibus](https://github.com/LeonardNJU/VocoType-ibus) 获得最佳效果!

一个简单易用的 Linux 语音转文字输入工具，支持一键录音、自动识别、直接输入。

**注意: 如果你用的是no-CUDA笔记本的话, 请使用CPU-version分支**

## ✨ 特性

- 🎙️ **一键切换**: 运行一次开始录音，再次运行停止录音并识别
- 🚀 **自动输入**: 识别结果直接输入到当前焦点位置
- ⏱️ **智能提醒**: 录音时长提醒和自动停止
- 🔧 **错误处理**: 完善的错误处理和资源清理
- 🌍 **多系统支持**: 支持 Debian/Ubuntu、Arch、Fedora 等主流发行版
- 📱 **桌面集成**: 自动创建桌面快捷方式
- ⚙️ **灵活配置**: 支持自定义模型、语言、超时等参数

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
sudo apt install ffmpeg socat libnotify-bin xclip pulseaudio-utils
```

**Arch Linux:**
```bash
sudo pacman -S ffmpeg socat libnotify xclip pulseaudio
```

**Fedora:**
```bash
sudo dnf install ffmpeg socat libnotify xclip pulseaudio-utils
```

#### 2. 安装 Python 依赖

```bash
pip3 install --user openai-whisper
```

#### 3. 安装脚本

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
readonly WHISPER_MODEL="small"  # Whisper 模型大小
readonly WHISPER_LANGUAGE="Chinese"  # 识别语言

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

#### 🤖 Whisper 模型选择 (`WHISPER_MODEL`)
- **tiny**: 最快，准确率较低，约 39MB
- **base**: 平衡选择，约 74MB
- **small**: 推荐选择，约 244MB
- **medium**: 高准确率，约 769MB
- **large**: 最高准确率，约 1550MB, 推荐使用large-v3-Turbo这个和large(也就是默认的large-v3)的准确率几乎一样,但是推理时间只需要一半

#### 🌍 语言设置 (`WHISPER_LANGUAGE`)
- **Chinese**: 中文识别
- **English**: 英文识别
- **auto**: 自动检测语言
- 其他支持的语言：Japanese, Korean, French, German, Spanish 等

#### ⏱️ 时间设置
- **MAX_DURATION**: 最大录音时长（建议 30-120 秒）
- **REMINDER_TIME**: 提醒时间，应小于 MAX_DURATION

#### 🔊 音频设置
- **SAMPLE_RATE**: 音频采样率（16000 适合语音识别）
- **START_DING_PATHS**: 开始录音提示音文件路径列表
- **END_DING_PATHS**: 结束录音提示音文件路径列表

#### 💻 设备选择 (Whisper 内部)
Whisper 会自动检测并使用可用的计算设备：
- **CPU**: 兼容性最好，速度较慢
- **CUDA**: 需要 NVIDIA GPU 和 CUDA 支持，速度最快
- 安装 CUDA 版本的 PyTorch 可启用 GPU 加速

### 配置建议

**低配置设备:**
```bash
readonly WHISPER_MODEL="tiny"
readonly MAX_DURATION=30
```

**高配置设备:**
```bash
readonly WHISPER_MODEL="medium"
readonly MAX_DURATION=120
```

**多语言环境:**
```bash
readonly WHISPER_LANGUAGE="auto"
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

# 测试麦克风录音（录制 5 秒）
ffmpeg -f pulse -i default -t 5 test_recording.wav

# 播放测试录音
paplay test_recording.wav
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
   - 测试录音设备: `ffmpeg -f pulse -i default -t 3 test.wav`

2. **识别结果为空**
   - 检查录音音量是否足够
   - 确认说话清晰度
   - 播放录音文件检查质量: `paplay /tmp/voice_input/voice_input.wav`

3. **无法输入文字**
   - 确保安装了 `xdotool` 或 `xclip`
   - 检查目标应用是否有焦点

4. **首次使用很慢**
   - Whisper 首次运行需要下载模型文件
   - 后续使用会很快

5. **GPU 加速不工作**
   - 安装 CUDA 版本的 PyTorch: `pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118`
   - 检查 CUDA 可用性: `python -c "import torch; print(torch.cuda.is_available())"`

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

#### Whisper 模型缓存位置
- **默认位置**: `~/.cache/whisper/`
- **模型文件**: 根据选择的模型大小，文件大小从 39MB 到 1550MB 不等

## 🎯 性能优化

### GPU 加速设置
```bash
# 安装 CUDA 版本的 PyTorch（如果有 NVIDIA GPU）
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118

# 验证 CUDA 可用性
python -c "import torch; print('CUDA available:', torch.cuda.is_available())"
```

### 模型性能测试 (这个似乎有点问题,建议直接用whisper命令测)
```bash
# 运行模型性能测试
python model_benchmark.py

# 测试特定模型
python model_benchmark.py --models tiny,base,small
```

### 优化建议
- **更快的模型**: 可以尝试使用 `faster-whisper` 替代 `openai-whisper`
- **模型选择**: 根据设备性能选择合适大小的模型
- **内存优化**: 使用较小的模型可以减少内存占用
- **网络优化**: 首次运行前预下载模型文件

## 🔍 测试和调试

### 系统测试
```bash
# 运行完整系统测试
./test_voice_system.sh

# 测试音频设备
./test_voice_system.sh --audio-only
```

### 手动测试录音
```bash
# 测试 5 秒录音
ffmpeg -f pulse -i default -t 5 -y test_manual.wav

# 播放录音检查质量
paplay test_manual.wav

# 使用 Whisper 测试识别
whisper test_manual.wav --language Chinese --model small
```

## 🚀 未来开发计划

目前有一些将来的更新计划
- 实时输入系统,也就是说你可以一边说话,文字就一边上屏,并且可根据你说的话进行一些实时修改
- 手机端作为外接麦克风, 甚至是网络输入方式: 通过公网服务器作为跳板机,用户在手机端下达命令,而通过一些远程桌面服务查看当前Agent的工作状态,已达到`Vibe programming`的目标

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

本项目采用 Apache License 2.0 许可证。
