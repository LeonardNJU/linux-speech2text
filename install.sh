#!/bin/bash

# 语音输入系统安装脚本

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly INSTALL_DIR="$HOME/.local/bin"
readonly CONFIG_DIR="$HOME/.config/voice-input"
readonly SOUNDS_DIR="$HOME/.local/share/sounds"

echo "🚀 开始安装语音输入系统..."

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
                sudo apt install -y ffmpeg socat libnotify-bin xclip pipewire-pulse pipewire-audio-client-libraries
            else
                echo "📦 安装 PulseAudio 音频工具..."
                sudo apt install -y ffmpeg socat libnotify-bin xclip pulseaudio-utils
            fi
            ;;
        "arch")
            # Arch Linux typically uses PipeWire by default in modern installations
            if pacman -Qi pipewire >/dev/null 2>&1; then
                echo "📦 检测到 PipeWire，安装 PipeWire 音频工具..."
                sudo pacman -S --needed ffmpeg socat libnotify xclip pipewire-pulse python-pipx
            else
                echo "📦 安装 PulseAudio 音频工具..."
                sudo pacman -S --needed ffmpeg socat libnotify xclip pulseaudio python-pipx
            fi
            ;;
        "fedora")
            # Fedora uses PipeWire by default since Fedora 34
            if rpm -q pipewire >/dev/null 2>&1; then
                echo "📦 检测到 PipeWire，安装 PipeWire 音频工具..."
                sudo dnf install -y ffmpeg socat libnotify xclip pipewire-pulseaudio
            else
                echo "📦 安装 PulseAudio 音频工具..."
                sudo dnf install -y ffmpeg socat libnotify xclip pulseaudio-utils
            fi
            ;;
        "opensuse")
            if rpm -q pipewire >/dev/null 2>&1; then
                echo "📦 检测到 PipeWire，安装 PipeWire 音频工具..."
                sudo zypper install -y ffmpeg socat libnotify-tools xclip pipewire-pulseaudio
            else
                echo "📦 安装 PulseAudio 音频工具..."
                sudo zypper install -y ffmpeg socat libnotify-tools xclip pulseaudio-utils
            fi
            ;;
        *)
            echo "⚠️  未识别的系统类型，请手动安装以下依赖:"
            echo "   - ffmpeg"
            echo "   - socat" 
            echo "   - libnotify (notify-send)"
            echo "   - xclip"
            echo "   - pipewire-pulse 或 pulseaudio-utils (音频系统)"
            read -p "按回车键继续..."
            ;;
    esac
}

# 安装 Python 依赖
install_python_deps() {
    echo "🐍 安装 Python 依赖..."
    
    local system=$(detect_system)
    
    # 首先尝试系统包管理器安装 (推荐方式)
    case $system in
        "arch")
            if pacman -Ss python-openai-whisper >/dev/null 2>&1; then
                echo "📦 使用 pacman 安装 openai-whisper..."
                sudo pacman -S --needed python-openai-whisper
                return 0
            fi
            ;;
        "debian")
            # Debian/Ubuntu 可能没有官方包，继续使用其他方法
            ;;
        "fedora")
            if dnf search python3-openai-whisper >/dev/null 2>&1; then
                echo "📦 使用 dnf 安装 openai-whisper..."
                sudo dnf install -y python3-openai-whisper
                return 0
            fi
            ;;
    esac
    
    # 尝试使用 pipx (推荐的应用安装方式)
    if command -v pipx >/dev/null 2>&1; then
        echo "📦 使用 pipx 安装 openai-whisper..."
        pipx install openai-whisper
        return 0
    fi
    
    # 检查是否在虚拟环境中
    if [[ -n "${VIRTUAL_ENV:-}" ]]; then
        echo "📦 在虚拟环境中安装 openai-whisper..."
        pip install openai-whisper
        return 0
    fi
    
    # 尝试传统的 pip --user 方式
    if command -v pip3 >/dev/null 2>&1; then
        echo "📦 尝试使用 pip3 --user 安装..."
        if pip3 install --user openai-whisper 2>/dev/null; then
            return 0
        else
            echo "⚠️  pip --user 安装失败 (可能是 PEP 668 限制)"
        fi
    elif command -v pip >/dev/null 2>&1; then
        echo "📦 尝试使用 pip --user 安装..."
        if pip install --user openai-whisper 2>/dev/null; then
            return 0
        else
            echo "⚠️  pip --user 安装失败 (可能是 PEP 668 限制)"
        fi
    fi
    
    # 如果所有方法都失败，提供手动安装指导
    echo "❌ 自动安装 openai-whisper 失败"
    echo ""
    echo "🔧 请手动安装 openai-whisper，推荐以下方法之一："
    echo ""
    case $system in
        "arch")
            echo "1. 使用 AUR (推荐):"
            echo "   yay -S python-openai-whisper"
            echo "   # 或者"
            echo "   paru -S python-openai-whisper"
            echo ""
            echo "2. 使用 pipx:"
            echo "   sudo pacman -S python-pipx"
            echo "   pipx install openai-whisper"
            ;;
        "debian")
            echo "1. 使用 pipx (推荐):"
            echo "   sudo apt install pipx"
            echo "   pipx install openai-whisper"
            echo ""
            echo "2. 使用虚拟环境:"
            echo "   python3 -m venv ~/.local/share/whisper-venv"
            echo "   ~/.local/share/whisper-venv/bin/pip install openai-whisper"
            echo "   ln -s ~/.local/share/whisper-venv/bin/whisper ~/.local/bin/whisper"
            ;;
        "fedora")
            echo "1. 使用 pipx (推荐):"
            echo "   sudo dnf install pipx"
            echo "   pipx install openai-whisper"
            ;;
        *)
            echo "1. 使用 pipx (推荐):"
            echo "   # 安装 pipx (方法因发行版而异)"
            echo "   pipx install openai-whisper"
            echo ""
            echo "2. 使用虚拟环境:"
            echo "   python3 -m venv ~/.local/share/whisper-venv"
            echo "   ~/.local/share/whisper-venv/bin/pip install openai-whisper"
            echo "   ln -s ~/.local/share/whisper-venv/bin/whisper ~/.local/bin/whisper"
            ;;
    esac
    echo ""
    echo "3. 强制使用 pip (不推荐，可能破坏系统):"
    echo "   pip install --user openai-whisper --break-system-packages"
    echo ""
    read -p "按回车键继续安装其他组件..."
}

# 创建目录结构
setup_directories() {
    echo "📁 创建目录结构..."
    mkdir -p "$INSTALL_DIR" "$CONFIG_DIR" "$SOUNDS_DIR"
}

# 复制文件
install_files() {
    echo "📋 安装脚本文件..."
    
    # 复制主脚本
    cp "$SCRIPT_DIR/voice_toggle_optimized.sh" "$INSTALL_DIR/voice-toggle"
    chmod +x "$INSTALL_DIR/voice-toggle"
    
    # 创建提示音文件（简单的beep音）
    if command -v sox >/dev/null 2>&1; then
        sox -n -r 44100 -c 2 "$SOUNDS_DIR/ding.wav" synth 0.1 sine 800 vol 0.5
    else
        echo "⚠️  未安装 sox，跳过提示音生成。系统将使用默认提示音。"
    fi
}

# 初始化 Whisper 模型
init_whisper() {
    echo "🤖 初始化 Whisper 模型..."
    echo "这可能需要几分钟时间下载模型文件..."
    
    # 创建临时音频文件进行测试
    local temp_audio="/tmp/whisper_test.wav"
    if command -v sox >/dev/null 2>&1; then
        sox -n -r 16000 -c 1 "$temp_audio" synth 1 sine 440 vol 0.1
        whisper "$temp_audio" --language Chinese --model base --fp16 False --output_format txt --output_dir /tmp >/dev/null 2>&1 || true
        rm -f "$temp_audio" /tmp/whisper_test.txt
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
    echo "   2. 建议绑定到快捷键 (如 Super+V):"
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
    echo "📝 配置文件位置: $CONFIG_DIR"
    echo "🔊 提示音位置: $SOUNDS_DIR/ding.wav"
    echo ""
    echo "🎯 使用流程："
    echo "   1. 按快捷键开始录音"
    echo "   2. 说话"
    echo "   3. 再按快捷键停止录音并识别"
    echo "   4. 文字会自动输入到当前焦点位置"
    echo ""
}

# 主函数
main() {
    echo "🎙️  Linux 语音输入系统安装程序"
    echo "=================================="
    
    # 检查是否有网络连接
    if ! ping -c 1 google.com >/dev/null 2>&1 && ! ping -c 1 baidu.com >/dev/null 2>&1; then
        echo "⚠️  警告: 网络连接可能有问题，Whisper 模型下载可能失败"
        read -p "是否继续安装? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    install_system_deps
    install_python_deps
    setup_directories
    install_files
    init_whisper
    create_desktop_entry
    show_usage
    
    echo "🎉 安装完成！享受语音输入吧！"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi