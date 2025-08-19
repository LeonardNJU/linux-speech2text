#!/bin/bash

# Vulkan 检测和安装脚本
# 检测 Vulkan 支持并提供安装建议

set -euo pipefail

echo "🔍 Vulkan 支持检测"
echo "==================="

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

# 检查 Vulkan 运行时
check_vulkan_runtime() {
    echo "📦 检查 Vulkan 运行时..."
    
    local has_vulkan=false
    
    # 检查 vulkan-tools (vulkaninfo)
    if command -v vulkaninfo >/dev/null 2>&1; then
        echo "✅ vulkaninfo 已安装"
        has_vulkan=true
    else
        echo "❌ vulkaninfo 未安装"
    fi
    
    # 检查 libvulkan
    if ldconfig -p | grep -q libvulkan; then
        echo "✅ libvulkan 运行时库已安装"
        has_vulkan=true
    else
        echo "❌ libvulkan 运行时库未安装"
    fi
    
    return $([ "$has_vulkan" = true ] && echo 0 || echo 1)
}

# 检查显卡驱动
check_graphics_drivers() {
    echo "🖥️  检查显卡驱动..."
    
    local has_driver=false
    
    # 检查 NVIDIA 驱动
    if command -v nvidia-smi >/dev/null 2>&1; then
        echo "✅ NVIDIA 驱动已安装"
        nvidia-smi --query-gpu=name,driver_version --format=csv,noheader,nounits 2>/dev/null || echo "   (驱动信息获取失败)"
        has_driver=true
    fi
    
    # 检查 AMD 驱动
    if lspci | grep -i amd | grep -i vga >/dev/null 2>&1; then
        echo "🔍 检测到 AMD 显卡"
        if command -v amdgpu-pro-px >/dev/null 2>&1 || command -v rocm-smi >/dev/null 2>&1; then
            echo "✅ AMD 专用驱动已安装"
            has_driver=true
        elif lsmod | grep -q amdgpu; then
            echo "✅ AMD 开源驱动 (AMDGPU) 已加载"
            has_driver=true
        else
            echo "⚠️  AMD 显卡驱动状态不明"
        fi
    fi
    
    # 检查 Intel 集成显卡
    if lspci | grep -i intel | grep -i vga >/dev/null 2>&1; then
        echo "🔍 检测到 Intel 集成显卡"
        if lsmod | grep -q i915; then
            echo "✅ Intel i915 驱动已加载"
            has_driver=true
        else
            echo "⚠️  Intel 显卡驱动状态不明"
        fi
    fi
    
    return $([ "$has_driver" = true ] && echo 0 || echo 1)
}

# 测试 Vulkan 功能
test_vulkan() {
    echo "🧪 测试 Vulkan 功能..."
    
    if ! command -v vulkaninfo >/dev/null 2>&1; then
        echo "❌ 无法测试 Vulkan - vulkaninfo 未安装"
        return 1
    fi
    
    if vulkaninfo >/dev/null 2>&1; then
        echo "✅ Vulkan 工作正常"
        echo "📊 Vulkan 设备信息:"
        vulkaninfo | grep -E "(deviceName|driverInfo|apiVersion)" | head -10 | sed 's/^/   /'
        return 0
    else
        echo "❌ Vulkan 测试失败"
        return 1
    fi
}

# 提供安装建议
suggest_installation() {
    local system=$(detect_system)
    
    echo ""
    echo "💡 Vulkan 安装建议"
    echo "=================="
    
    case $system in
        "debian")
            echo "📦 Debian/Ubuntu 安装命令:"
            echo "   sudo apt update"
            echo "   sudo apt install vulkan-tools libvulkan1 mesa-vulkan-drivers"
            echo ""
            echo "🎮 NVIDIA 用户额外安装:"
            echo "   sudo apt install nvidia-driver-libs"
            echo ""
            echo "🔴 AMD 用户额外安装:"
            echo "   sudo apt install mesa-vulkan-drivers vulkan-tools"
            ;;
        "arch")
            echo "📦 Arch Linux 安装命令:"
            echo "   sudo pacman -S vulkan-tools vulkan-icd-loader"
            echo ""
            echo "🎮 NVIDIA 用户额外安装:"
            echo "   sudo pacman -S nvidia-utils"
            echo ""
            echo "🔴 AMD 用户额外安装:"
            echo "   sudo pacman -S vulkan-radeon"
            echo ""
            echo "🔵 Intel 用户额外安装:"
            echo "   sudo pacman -S vulkan-intel"
            ;;
        "fedora")
            echo "📦 Fedora 安装命令:"
            echo "   sudo dnf install vulkan-tools vulkan-loader"
            echo ""
            echo "🎮 NVIDIA 用户额外安装:"
            echo "   sudo dnf install xorg-x11-drv-nvidia-cuda vulkan-headers"
            echo ""
            echo "🔴 AMD 用户额外安装:"
            echo "   sudo dnf install mesa-vulkan-drivers"
            ;;
        "opensuse")
            echo "📦 openSUSE 安装命令:"
            echo "   sudo zypper install vulkan-tools libvulkan1"
            echo ""
            echo "🎮 NVIDIA 用户额外安装:"
            echo "   sudo zypper install nvidia-gfxG05-vulkan-32bit nvidia-gfxG05-vulkan"
            ;;
        *)
            echo "⚠️  未知系统类型，请参考发行版文档安装 Vulkan"
            echo "💡 通常需要安装: vulkan-tools, vulkan-loader, 和对应的显卡驱动"
            ;;
    esac
    
    echo ""
    echo "🔧 安装完成后，请重新运行此脚本验证 Vulkan 支持"
    echo "🚀 启用 Vulkan 可以显著提升 whisper.cpp 的推理性能"
}

# 主函数
main() {
    local vulkan_ok=false
    local driver_ok=false
    
    if check_vulkan_runtime; then
        vulkan_ok=true
    fi
    
    if check_graphics_drivers; then
        driver_ok=true
    fi
    
    echo ""
    if [ "$vulkan_ok" = true ] && [ "$driver_ok" = true ]; then
        if test_vulkan; then
            echo "🎉 Vulkan 完全支持且工作正常！"
            echo "💡 您可以在编译 whisper.cpp 时添加 Vulkan 支持:"
            echo "   make WHISPER_VULKAN=1"
            exit 0
        else
            echo "⚠️  Vulkan 安装但测试失败"
        fi
    else
        echo "❌ Vulkan 支持不完整"
    fi
    
    suggest_installation
    exit 1
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi