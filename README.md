# Linux 语音输入系统

一个简单易用的 Linux 语音转文字输入工具，支持一键录音、自动识别、直接输入。

## ✨ 特性

- 🎙️ **一键切换**: 运行一次开始录音，再次运行停止录音并识别
- 🚀 **自动输入**: 识别结果直接输入到当前焦点位置
- ⏱️ **智能提醒**: 录音时长提醒和自动停止
- 🔧 **错误处理**: 完善的错误处理和资源清理
- 🌍 **多系统支持**: 支持 Debian/Ubuntu、Arch、Fedora 等主流发行版
- 📱 **桌面集成**: 自动创建桌面快捷方式

## 🚀 快速安装

### 自动安装（推荐）

```bash
# 克隆仓库
git clone https://github.com/yourusername/linux-speech2text.git
cd linux-speech2text

# 运行安装脚本
chmod +x install.sh
./install.sh
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
cp voice_toggle_optimized.sh ~/.local/bin/voice-toggle
chmod +x ~/.local/bin/voice-toggle

# 确保 ~/.local/bin 在 PATH 中
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
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

## ⚙️ 配置选项

脚本支持以下配置（在脚本开头修改）：

```bash
readonly MAX_DURATION=60        # 最大录音时长（秒）
readonly REMINDER_TIME=50       # 提醒时间（秒）
readonly SAMPLE_RATE=16000      # 音频采样率
readonly WHISPER_MODEL="base"   # Whisper 模型大小
readonly WHISPER_LANGUAGE="Chinese"  # 识别语言
```

## 🔧 故障排除

### 常见问题

1. **录音失败**
   - 检查麦克风权限
   - 确认 PulseAudio 正在运行: `pulseaudio --check`

2. **识别结果为空**
   - 检查录音音量是否足够
   - 确认说话清晰度

3. **无法输入文字**
   - 确保安装了 `xdotool` 或 `xclip`
   - 检查目标应用是否有焦点

4. **首次使用很慢**
   - Whisper 首次运行需要下载模型文件
   - 后续使用会很快

### 日志查看

```bash
# 查看详细日志
tail -f /tmp/voice_input_*/voice_input.log
```

## 🎯 性能优化

- **GPU 加速**: 如果有 NVIDIA GPU，安装 CUDA 版本的 PyTorch 可显著提升识别速度
- **更快的模型**: 可以尝试使用 `faster-whisper` 替代 `openai-whisper`
- **模型选择**: 根据需要选择不同大小的模型（tiny/base/small/medium/large）

## 📁 文件结构

```
linux-speech2text/
├── voice_toggle.sh              # 原始脚本
├── voice_toggle_optimized.sh    # 优化版本脚本
├── install.sh                   # 自动安装脚本
├── README.md                    # 说明文档
└── LICENSE                      # 许可证
```

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

本项目采用 Apache License 2.0 许可证。