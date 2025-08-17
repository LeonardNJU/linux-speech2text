#!/bin/bash

# 语音输入系统安装脚本 - 增强版
# 支持交互式配置参数

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly INSTALL_DIR="$HOME/.local/bin"
readonly CONFIG_DIR="$HOME/.config/voice-input"
readonly SOUNDS_DIR="$HOME/.local/share/sounds"

# 默认配置参数
DEFAULT_WHISPER_MODEL="small"
DEFAULT_WHISPER_LANGUAGE="Chinese"
DEFAULT_MAX_DURATION=60
DEFAULT_REMINDER_TIME=50
DEFAULT_SAMPLE_RATE=16000
DEFAULT_DEVICE_PREFERENCE="auto"

# 用户配置参数（将在交互模式中设置）
USER_WHISPER_MODEL=""
USER_WHISPER_LANGUAGE=""
USER_MAX_DURATION=""
USER_REMINDER_TIME=""
USER_SAMPLE_RATE=""
USER_DEVICE_PREFERENCE=""
USER_START_SOUND=""
USER_END_SOUND=""

# 交互模式标志
INTERACTIVE_MODE=false

echo "🚀 开始安装语音输入系统..."

# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --interactive|-i)
                INTERACTIVE_MODE=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                echo "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# 显示帮助信息
show_help() {
    cat << EOF
语音输入系统安装脚本

用法: $0 [选项]

选项:
  -i, --interactive    启用交互式配置模式
  -h, --help          显示此帮助信息

交互式配置模式允许您自定义以下参数:
  - Whisper 模型大小 (tiny/base/small/medium/large)
  - 识别语言 (Chinese/English/auto 等)
  - 最大录音时长
  - 提醒时间
  - 音频采样率
  - 设备偏好 (CPU/CUDA/auto)
  - 提示音设置

示例:
  $0                   # 使用默认配置安装
  $0 --interactive     # 交互式配置安装
EOF
}

# 交互式配置函数
interactive_config() {
    echo ""
    echo "🔧 交互式配置模式"
    echo "================="
    echo "请根据您的需求配置以下参数（直接回车使用默认值）："
    echo ""

    # Whisper 模型选择
    echo "🤖 选择 Whisper 模型:"
    echo "  tiny            - 最快，准确率较低 (~39MB)"
    echo "  base            - 平衡选择 (~74MB)"
    echo "  small           - 推荐选择 (~244MB) [默认]"
    echo "  medium          - 高准确率 (~769MB)"
    echo "  large-v3-turbo  - 最高准确率 (~1550MB)"
    read -p "请选择模型 [${DEFAULT_WHISPER_MODEL}]: " USER_WHISPER_MODEL
    USER_WHISPER_MODEL=${USER_WHISPER_MODEL:-$DEFAULT_WHISPER_MODEL}

    # 语言设置
    echo ""
    echo "🌍 选择识别语言:"
    echo "  Chinese - 中文 [默认]"
    echo "  English - 英文"
    echo "  auto    - 自动检测"
    echo "  其他: Japanese, Korean, French, German, Spanish 等"
    read -p "请选择语言 [${DEFAULT_WHISPER_LANGUAGE}]: " USER_WHISPER_LANGUAGE
    USER_WHISPER_LANGUAGE=${USER_WHISPER_LANGUAGE:-$DEFAULT_WHISPER_LANGUAGE}

    # 时间设置
    echo ""
    echo "⏱️ 时间设置:"
    read -p "最大录音时长（秒）[${DEFAULT_MAX_DURATION}]: " USER_MAX_DURATION
    USER_MAX_DURATION=${USER_MAX_DURATION:-$DEFAULT_MAX_DURATION}
    
    read -p "提醒时间（秒，应小于最大录音时长）[${DEFAULT_REMINDER_TIME}]: " USER_REMINDER_TIME
    USER_REMINDER_TIME=${USER_REMINDER_TIME:-$DEFAULT_REMINDER_TIME}

    # 音频设置
    echo ""
    echo "🔊 音频设置:"
    read -p "音频采样率 [${DEFAULT_SAMPLE_RATE}]: " USER_SAMPLE_RATE
    USER_SAMPLE_RATE=${USER_SAMPLE_RATE:-$DEFAULT_SAMPLE_RATE}

    # 设备偏好
    echo ""
    echo "💻 计算设备偏好:"
    echo "  auto - 自动检测（推荐）[默认]"
    echo "  cpu  - 强制使用 CPU"
    echo "  cuda - 强制使用 CUDA（需要 NVIDIA GPU）"
    read -p "请选择设备偏好 [${DEFAULT_DEVICE_PREFERENCE}]: " USER_DEVICE_PREFERENCE
    USER_DEVICE_PREFERENCE=${USER_DEVICE_PREFERENCE:-$DEFAULT_DEVICE_PREFERENCE}

    # 提示音设置
    echo ""
    echo "🔔 提示音设置:"
    echo "  default - 使用系统默认提示音 [默认]"
    echo "  custom  - 使用自定义提示音文件"
    echo "  none    - 禁用提示音"
    read -p "请选择提示音设置 [default]: " sound_choice
    sound_choice=${sound_choice:-default}

    if [[ "$sound_choice" == "custom" ]]; then
        read -p "开始录音提示音文件路径: " USER_START_SOUND
        read -p "结束录音提示音文件路径: " USER_END_SOUND
    elif [[ "$sound_choice" == "none" ]]; then
        USER_START_SOUND="none"
        USER_END_SOUND="none"
    else
        USER_START_SOUND="default"
        USER_END_SOUND="default"
    fi

    # 显示配置摘要
    echo ""
    echo "📋 配置摘要:"
    echo "============"
    echo "Whisper 模型: $USER_WHISPER_MODEL"
    echo "识别语言: $USER_WHISPER_LANGUAGE"
    echo "最大录音时长: ${USER_MAX_DURATION}秒"
    echo "提醒时间: ${USER_REMINDER_TIME}秒"
    echo "音频采样率: $USER_SAMPLE_RATE"
    echo "设备偏好: $USER_DEVICE_PREFERENCE"
    echo "提示音: $sound_choice"
    echo ""
    
    read -p "确认使用以上配置? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ 安装已取消"
        exit 1
    fi
}

# 检测系统类型
detect_system() {
    if command -v apt >/dev/null 2>&1; then
        echo "debian"
    elif command -v pacman >/dev/null 2>&1; then
        echo "arch"
    elif command -v dnf >/dev/null 2>&1; then
        echo "fedora"
    elif command -v zypper >/dev/null 2>&1; then
        echo "opensuse"
    else
        echo "unknown"
    fi
}

# 安装系统依赖
install_system_deps() {
    local system=$(detect_system)
    
    echo "📦 检测到系统类型: $system"
    echo "📦 安装系统依赖..."
    
    case $system in
        "debian")
            sudo apt update
            # Install PipeWire (modern) or PulseAudio (fallback) audio system
            if apt list --installed 2>/dev/null | grep -q pipewire; then
                echo "📦 检测到 PipeWire，安装 PipeWire 音频工具..."
                sudo apt install -y ffmpeg socat libnotify-bin xclip pipewire-pulse pipewire-audio-client-libraries xdotool
            else
                echo "📦 安装 PulseAudio 音频工具..."
                sudo apt install -y ffmpeg socat libnotify-bin xclip pulseaudio-utils xdotool
            fi
            ;;
        "arch")
            # Arch Linux typically uses PipeWire by default in modern installations
            if pacman -Qi pipewire >/dev/null 2>&1; then
                echo "📦 检测到 PipeWire，安装 PipeWire 音频工具..."
                sudo pacman -S --needed ffmpeg socat libnotify xclip pipewire-pulse python-pipx xdotool
            else
                echo "📦 安装 PulseAudio 音频工具..."
                sudo pacman -S --needed ffmpeg socat libnotify xclip pulseaudio python-pipx xdotool
            fi
            ;;
        "fedora")
            # Fedora uses PipeWire by default since Fedora 34
            if rpm -q pipewire >/dev/null 2>&1; then
                echo "📦 检测到 PipeWire，安装 PipeWire 音频工具..."
                sudo dnf install -y ffmpeg socat libnotify xclip pipewire-pulseaudio xdotool
            else
                echo "📦 安装 PulseAudio 音频工具..."
                sudo dnf install -y ffmpeg socat libnotify xclip pulseaudio-utils xdotool
            fi
            ;;
        "opensuse")
            if rpm -q pipewire >/dev/null 2>&1; then
                echo "📦 检测到 PipeWire，安装 PipeWire 音频工具..."
                sudo zypper install -y ffmpeg socat libnotify-tools xclip pipewire-pulseaudio xdotool
            else
                echo "📦 安装 PulseAudio 音频工具..."
                sudo zypper install -y ffmpeg socat libnotify-tools xclip pulseaudio-utils xdotool
            fi
            ;;
        *)
            echo "⚠️  未识别的系统类型，请手动安装以下依赖:"
            echo "   - ffmpeg"
            echo "   - socat" 
            echo "   - libnotify (notify-send)"
            echo "   - xclip"
            echo "   - xdotool"
            echo "   - pipewire-pulse 或 pulseaudio-utils (音频系统)"
            read -p "按回车键继续..."
            ;;
    esac
}

# 测试音频设备
test_audio_devices() {
    echo "🎤 测试音频设备..."
    
    # 检查音频服务
    if ! pactl info >/dev/null 2>&1; then
        echo "❌ 无法连接到音频系统 (PipeWire/PulseAudio)"
        echo "请检查音频服务状态:"
        echo "  systemctl --user status pipewire"
        echo "  systemctl --user status pulseaudio"
        return 1
    fi
    
    # 列出音频输入设备
    echo "📋 可用的音频输入设备:"
    pactl list short sources | while read -r line; do
        echo "  $line"
    done
    
    # 测试录音
    echo ""
    read -p "是否测试录音功能? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        local test_file="/tmp/voice_test_$(date +%s).wav"
        echo "🎙️ 开始录音测试（3秒）..."
        echo "请对着麦克风说话..."
        
        if ffmpeg -loglevel error -f pulse -i default -t 3 -y "$test_file" 2>/dev/null; then
            echo "✅ 录音完成"
            
            if [[ -s "$test_file" ]]; then
                echo "📊 录音文件大小: $(du -h "$test_file" | cut -f1)"
                read -p "是否播放录音测试? (y/N): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    echo "🔊 播放录音..."
                    paplay "$test_file" 2>/dev/null || aplay "$test_file" 2>/dev/null || echo "⚠️ 无法播放录音文件"
                fi
            else
                echo "❌ 录音文件为空，请检查麦克风设置"
            fi
            
            rm -f "$test_file"
        else
            echo "❌ 录音测试失败，请检查音频设备"
            return 1
        fi
    fi
    
    return 0
}

# 安装 Python 依赖
install_python_deps() {
    echo "🐍 安装 Python 依赖..."
    
    local system=$(detect_system)
    
    # 根据设备偏好安装对应版本
    if [[ "$USER_DEVICE_PREFERENCE" == "cuda" ]] || [[ "$USER_DEVICE_PREFERENCE" == "auto" && -x "$(command -v nvidia-smi)" ]]; then
        echo "🚀 检测到 CUDA 支持，将安装 GPU 加速版本"
        install_whisper_with_cuda
    else
        echo "💻 安装 CPU 版本"
        install_whisper_cpu
    fi
}

# 安装 CPU 版本的 Whisper
install_whisper_cpu() {
    # 首先尝试系统包管理器安装
    local system=$(detect_system)
    case $system in
        "arch")
            if pacman -Ss python-openai-whisper >/dev/null 2>&1; then
                echo "📦 使用 pacman 安装 openai-whisper..."
                sudo pacman -S --needed python-openai-whisper
                return 0
            fi
            ;;
        "fedora")
            if dnf search python3-openai-whisper >/dev/null 2>&1; then
                echo "📦 使用 dnf 安装 openai-whisper..."
                sudo dnf install -y python3-openai-whisper
                return 0
            fi
            ;;
    esac
    
    # 尝试使用 pipx
    if command -v pipx >/dev/null 2>&1; then
        echo "📦 使用 pipx 安装 openai-whisper..."
        pipx install openai-whisper
        return 0
    fi
    
    # 尝试 pip 安装
    install_whisper_fallback
}

# 安装 CUDA 版本的 Whisper
install_whisper_with_cuda() {
    echo "🔧 安装 CUDA 版本的 PyTorch 和 Whisper..."
    
    if command -v pipx >/dev/null 2>&1; then
        echo "📦 使用 pipx 安装..."
        pipx install openai-whisper
        pipx inject openai-whisper torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
    else
        install_whisper_fallback
        echo "🚀 安装 CUDA 版本的 PyTorch..."
        pip3 install --user torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118 2>/dev/null || true
    fi
}

# 备用安装方法
install_whisper_fallback() {
    if [[ -n "${VIRTUAL_ENV:-}" ]]; then
        echo "📦 在虚拟环境中安装 openai-whisper..."
        pip install openai-whisper
        return 0
    fi
    
    if command -v pip3 >/dev/null 2>&1; then
        echo "📦 尝试使用 pip3 --user 安装..."
        if pip3 install --user openai-whisper 2>/dev/null; then
            return 0
        else
            echo "⚠️  pip --user 安装失败，尝试使用 --break-system-packages"
            pip3 install --user openai-whisper --break-system-packages 2>/dev/null || true
        fi
    fi
}

# 创建目录结构
setup_directories() {
    echo "📁 创建目录结构..."
    mkdir -p "$INSTALL_DIR" "$CONFIG_DIR" "$SOUNDS_DIR"
}

# 自定义脚本配置
customize_script() {
    echo "🔧 自定义脚本配置..."
    
    local source_script="$SCRIPT_DIR/voice-toggle.sh"
    local target_script="$INSTALL_DIR/voice-toggle"
    
    if [[ ! -f "$source_script" ]]; then
        echo "❌ 源脚本文件不存在: $source_script"
        exit 1
    fi
    
    # 复制脚本
    cp "$source_script" "$target_script"
    chmod +x "$target_script"
    
    # 如果是交互模式，应用用户配置
    if [[ "$INTERACTIVE_MODE" == "true" ]]; then
        echo "📝 应用用户配置..."
        
        # 替换配置参数
        sed -i "s/readonly MAX_DURATION=.*/readonly MAX_DURATION=$USER_MAX_DURATION/" "$target_script"
        sed -i "s/readonly REMINDER_TIME=.*/readonly REMINDER_TIME=$USER_REMINDER_TIME/" "$target_script"
        sed -i "s/readonly SAMPLE_RATE=.*/readonly SAMPLE_RATE=$USER_SAMPLE_RATE/" "$target_script"
        sed -i "s/readonly WHISPER_MODEL=.*/readonly WHISPER_MODEL=\"$USER_WHISPER_MODEL\"/" "$target_script"
        sed -i "s/readonly WHISPER_LANGUAGE=.*/readonly WHISPER_LANGUAGE=\"$USER_WHISPER_LANGUAGE\"/" "$target_script"
        
        # 处理提示音设置
        if [[ "$USER_START_SOUND" == "none" ]]; then
            sed -i 's/readonly START_DING_PATHS=(/readonly START_DING_PATHS=(/' "$target_script"
            sed -i '/readonly START_DING_PATHS=(/,/)/{s/.*/readonly START_DING_PATHS=()/}' "$target_script"
        elif [[ "$USER_START_SOUND" != "default" && -n "$USER_START_SOUND" ]]; then
            sed -i "s|readonly START_DING_PATHS=(.*|readonly START_DING_PATHS=(\"$USER_START_SOUND\")|" "$target_script"
        fi
        
        if [[ "$USER_END_SOUND" == "none" ]]; then
            sed -i '/readonly END_DING_PATHS=(/,/)/{s/.*/readonly END_DING_PATHS=()/}' "$target_script"
        elif [[ "$USER_END_SOUND" != "default" && -n "$USER_END_SOUND" ]]; then
            sed -i "s|readonly END_DING_PATHS=(.*|readonly END_DING_PATHS=(\"$USER_END_SOUND\")|" "$target_script"
        fi
        
        echo "✅ 配置已应用到脚本"
    fi
}

# 初始化 Whisper 模型
init_whisper() {
    echo "🤖 初始化 Whisper 模型..."
    echo "这可能需要几分钟时间下载模型文件..."
    
    local model_to_use="$DEFAULT_WHISPER_MODEL"
    if [[ "$INTERACTIVE_MODE" == "true" && -n "$USER_WHISPER_MODEL" ]]; then
        model_to_use="$USER_WHISPER_MODEL"
    fi
    
    # 创建临时音频文件进行测试
    local temp_audio="/tmp/whisper_test_$(date +%s).wav"
    if command -v sox >/dev/null 2>&1; then
        sox -n -r 16000 -c 1 "$temp_audio" synth 1 sine 440 vol 0.1
        echo "📥 下载 $model_to_use 模型..."
        whisper "$temp_audio" --language Chinese --model "$model_to_use" --fp16 False --output_format txt --output_dir /tmp >/dev/null 2>&1 || true
        rm -f "$temp_audio" /tmp/whisper_test*.txt
        echo "✅ 模型初始化完成"
    else
        echo "⚠️  跳过 Whisper 初始化，首次使用时会自动下载模型"
    fi
}

# 创建桌面快捷方式
create_desktop_entry() {
    echo "🖥️  创建桌面快捷方式..."
    
    local desktop_file="$HOME/.local/share/applications/voice-input.desktop"
    mkdir -p "$(dirname "$desktop_file")"
    
    cat > "$desktop_file" << EOF
[Desktop Entry]
Name=语音输入
Comment=语音转文字输入工具
Exec=$INSTALL_DIR/voice-toggle
Icon=audio-input-microphone
Terminal=false
Type=Application
Categories=Utility;AudioVideo;
Keywords=voice;speech;input;microphone;
EOF
    
    chmod +x "$desktop_file"
}

# 显示使用说明
show_usage() {
    echo ""
    echo "✅ 安装完成！"
    echo ""
    echo "📖 使用方法："
    echo "   1. 命令行使用: voice-toggle"
    echo "   2. 建议绑定到快捷键 (如 Super+V)"
    echo ""
    echo "🔧 快捷键设置 (GNOME):"
    echo "   gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/voice-input/ name '语音输入'"
    echo "   gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/voice-input/ command '$INSTALL_DIR/voice-toggle'"
    echo "   gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/voice-input/ binding '<Super>v'"
    echo ""
    echo "🔧 快捷键设置 (KDE):"
    echo "   系统设置 -> 快捷键 -> 自定义快捷键 -> 新建 -> 全局快捷键 -> 命令/URL"
    echo "   命令: $INSTALL_DIR/voice-toggle"
    echo "   快捷键: Meta+V"
    echo ""
    
    if [[ "$INTERACTIVE_MODE" == "true" ]]; then
        echo "📋 您的配置:"
        echo "   模型: $USER_WHISPER_MODEL"
        echo "   语言: $USER_WHISPER_LANGUAGE"
        echo "   最大录音时长: ${USER_MAX_DURATION}秒"
        echo "   设备偏好: $USER_DEVICE_PREFERENCE"
        echo ""
    fi
    
    echo "📁 重要文件位置:"
    echo "   脚本位置: $INSTALL_DIR/voice-toggle"
    echo "   配置目录: $CONFIG_DIR"
    echo "   提示音目录: $SOUNDS_DIR"
    echo "   临时文件: /tmp/voice_input/"
    echo "   日志文件: /tmp/voice_input/voice_input.log"
    echo "   模型缓存: ~/.cache/whisper/"
    echo ""
    echo "🎯 使用流程："
    echo "   1. 按快捷键开始录音"
    echo "   2. 说话"
    echo "   3. 再按快捷键停止录音并识别"
    echo "   4. 文字会自动输入到当前焦点位置"
    echo ""
    echo "🔧 故障排除:"
    echo "   查看日志: tail -f /tmp/voice_input/voice_input.log"
    echo "   测试录音: ffmpeg -f pulse -i default -t 3 test.wav"
    echo "   播放测试: paplay test.wav"
    echo "   音频设备: pactl list short sources"
    echo ""
}

# 主函数
main() {
    echo "🎙️  Linux 语音输入系统安装程序"
    echo "=================================="
    
    # 解析命令行参数
    parse_args "$@"
    
    # 检查网络连接
    if ! ping -c 1 google.com >/dev/null 2>&1 && ! ping -c 1 baidu.com >/dev/null 2>&1; then
        echo "⚠️  警告: 网络连接可能有问题，Whisper 模型下载可能失败"
        read -p "是否继续安装? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # 交互式配置
    if [[ "$INTERACTIVE_MODE" == "true" ]]; then
        interactive_config
    else
        echo "📝 使用默认配置进行安装"
        USER_WHISPER_MODEL="$DEFAULT_WHISPER_MODEL"
        USER_WHISPER_LANGUAGE="$DEFAULT_WHISPER_LANGUAGE"
        USER_MAX_DURATION="$DEFAULT_MAX_DURATION"
        USER_REMINDER_TIME="$DEFAULT_REMINDER_TIME"
        USER_SAMPLE_RATE="$DEFAULT_SAMPLE_RATE"
        USER_DEVICE_PREFERENCE="$DEFAULT_DEVICE_PREFERENCE"
        USER_START_SOUND="default"
        USER_END_SOUND="default"
    fi
    
    # 安装步骤
    install_system_deps
    test_audio_devices
    install_python_deps
    setup_directories
    customize_script
    init_whisper
    create_desktop_entry
    show_usage
    
    echo "🎉 安装完成！享受语音输入吧！"
}

# 程序入口
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi