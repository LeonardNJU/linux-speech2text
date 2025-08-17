#!/bin/bash

# 快捷键设置脚本 - 支持多种桌面环境

set -euo pipefail

readonly SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/voice_toggle_optimized.sh"
readonly SHORTCUT_KEY="<Super>v"

detect_desktop() {
    if [[ -n "${XDG_CURRENT_DESKTOP:-}" ]]; then
        echo "$XDG_CURRENT_DESKTOP" | tr '[:upper:]' '[:lower:]'
    elif [[ -n "${DESKTOP_SESSION:-}" ]]; then
        echo "$DESKTOP_SESSION" | tr '[:upper:]' '[:lower:]'
    elif command -v gnome-shell >/dev/null 2>&1; then
        echo "gnome"
    elif command -v kwin >/dev/null 2>&1; then
        echo "kde"
    elif command -v xfce4-session >/dev/null 2>&1; then
        echo "xfce"
    else
        echo "unknown"
    fi
}

setup_gnome_shortcut() {
    echo "🔧 为 GNOME 设置快捷键..."
    
    # 获取现有的自定义快捷键列表
    local existing_bindings
    existing_bindings=$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings)
    
    # 添加新的快捷键路径
    local new_path="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/voice-input/"
    
    if [[ "$existing_bindings" == "@as []" ]]; then
        # 如果没有现有快捷键，创建新的数组
        gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "['$new_path']"
    else
        # 如果有现有快捷键，添加到数组中
        local updated_bindings
        updated_bindings=$(echo "$existing_bindings" | sed "s/]/, '$new_path']/")
        gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "$updated_bindings"
    fi
    
    # 设置快捷键详细信息
    gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$new_path name '语音输入'
    gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$new_path command "$SCRIPT_PATH"
    gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:$new_path binding "$SHORTCUT_KEY"
    
    echo "✅ GNOME 快捷键设置完成: Super+V"
}

setup_kde_shortcut() {
    echo "🔧 为 KDE 设置快捷键..."
    
    # KDE 快捷键配置文件
    local kde_config="$HOME/.config/kglobalshortcutsrc"
    local kde_shortcuts="$HOME/.config/khotkeysrc"
    
    echo "📝 KDE 快捷键需要手动设置："
    echo "1. 打开 系统设置 → 快捷键"
    echo "2. 点击 自定义快捷键 → 编辑 → 新建 → 全局快捷键 → 命令/URL"
    echo "3. 设置名称: 语音输入"
    echo "4. 设置命令: $SCRIPT_PATH"
    echo "5. 设置快捷键: Meta+V"
    echo "6. 点击应用"
    
    read -p "按回车键继续..."
}

setup_xfce_shortcut() {
    echo "🔧 为 XFCE 设置快捷键..."
    
    # XFCE 使用 xfconf-query 设置快捷键
    if command -v xfconf-query >/dev/null 2>&1; then
        xfconf-query -c xfce4-keyboard-shortcuts -p "/commands/custom/<Super>v" -n -t string -s "$SCRIPT_PATH"
        echo "✅ XFCE 快捷键设置完成: Super+V"
    else
        echo "📝 XFCE 快捷键需要手动设置："
        echo "1. 打开 设置 → 键盘 → 应用程序快捷键"
        echo "2. 点击 添加"
        echo "3. 设置命令: $SCRIPT_PATH"
        echo "4. 设置快捷键: Super+V"
        
        read -p "按回车键继续..."
    fi
}

setup_generic_shortcut() {
    echo "🔧 通用快捷键设置方法："
    echo ""
    echo "请在您的桌面环境中手动设置快捷键："
    echo "命令: $SCRIPT_PATH"
    echo "快捷键: Super+V (或您喜欢的组合键)"
    echo ""
    echo "常见设置位置："
    echo "- GNOME: 设置 → 键盘 → 查看和自定义快捷键"
    echo "- KDE: 系统设置 → 快捷键"
    echo "- XFCE: 设置 → 键盘 → 应用程序快捷键"
    echo "- MATE: 系统 → 首选项 → 键盘快捷键"
    echo "- Cinnamon: 系统设置 → 键盘 → 快捷键"
    
    read -p "按回车键继续..."
}

create_launcher() {
    echo "🖥️  创建桌面启动器..."
    
    local desktop_file="$HOME/.local/share/applications/voice-input.desktop"
    mkdir -p "$(dirname "$desktop_file")"
    
    cat > "$desktop_file" << EOF
[Desktop Entry]
Name=语音输入
Name[en]=Voice Input
Comment=语音转文字输入工具
Comment[en]=Voice to text input tool
Exec=$SCRIPT_PATH
Icon=audio-input-microphone
Terminal=false
Type=Application
Categories=Utility;AudioVideo;Accessibility;
Keywords=voice;speech;input;microphone;语音;输入;
StartupNotify=true
EOF
    
    chmod +x "$desktop_file"
    echo "✅ 桌面启动器创建完成"
}

test_shortcut() {
    echo "🧪 测试语音输入系统..."
    
    if [[ -x "$SCRIPT_PATH" ]]; then
        echo "✅ 脚本可执行"
    else
        echo "❌ 脚本不可执行，正在修复..."
        chmod +x "$SCRIPT_PATH"
    fi
    
    echo "📝 测试建议："
    echo "1. 按设置的快捷键开始录音"
    echo "2. 说一句话（如：你好世界）"
    echo "3. 再按快捷键停止录音"
    echo "4. 等待识别结果自动输入"
}

main() {
    echo "🎙️  语音输入系统快捷键设置"
    echo "================================"
    echo ""
    
    # 检查脚本是否存在
    if [[ ! -f "$SCRIPT_PATH" ]]; then
        echo "❌ 错误: 找不到语音输入脚本"
        echo "请确保 voice_toggle_optimized.sh 在当前目录"
        exit 1
    fi
    
    # 检测桌面环境
    local desktop
    desktop=$(detect_desktop)
    echo "🖥️  检测到桌面环境: $desktop"
    echo ""
    
    # 根据桌面环境设置快捷键
    case "$desktop" in
        *gnome*|*ubuntu*)
            setup_gnome_shortcut
            ;;
        *kde*|*plasma*)
            setup_kde_shortcut
            ;;
        *xfce*)
            setup_xfce_shortcut
            ;;
        *)
            echo "⚠️  未识别的桌面环境: $desktop"
            setup_generic_shortcut
            ;;
    esac
    
    echo ""
    create_launcher
    echo ""
    test_shortcut
    
    echo ""
    echo "🎉 设置完成！"
    echo ""
    echo "💡 提示："
    echo "- 快捷键: Super+V（Windows键+V）"
    echo "- 也可以在应用程序菜单中找到'语音输入'"
    echo "- 首次使用会下载 Whisper 模型，请耐心等待"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi