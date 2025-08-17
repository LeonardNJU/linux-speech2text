#!/bin/bash

# 语音输入系统测试脚本

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TEST_SCRIPT="$SCRIPT_DIR/voice_toggle_optimized.sh"

# 颜色定义
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# 测试计数器
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}  语音输入系统测试套件${NC}"
    echo -e "${BLUE}================================${NC}"
    echo
}

print_test() {
    local test_name="$1"
    echo -e "${YELLOW}测试: $test_name${NC}"
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
}

print_pass() {
    local message="$1"
    echo -e "${GREEN}✅ PASS: $message${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

print_fail() {
    local message="$1"
    echo -e "${RED}❌ FAIL: $message${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

print_info() {
    local message="$1"
    echo -e "${BLUE}ℹ️  INFO: $message${NC}"
}

# 测试依赖工具
test_dependencies() {
    print_test "依赖工具检查"
    
    local required_tools=("ffmpeg" "socat" "whisper")
    local missing_tools=()
    
    for tool in "${required_tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            print_pass "$tool 已安装"
        else
            missing_tools+=("$tool")
            print_fail "$tool 未安装"
        fi
    done
    
    # 检查输出工具
    if command -v xdotool >/dev/null 2>&1; then
        print_pass "xdotool 已安装（推荐）"
    elif command -v xclip >/dev/null 2>&1; then
        print_pass "xclip 已安装"
    else
        print_fail "xdotool 和 xclip 都未安装"
        missing_tools+=("xdotool或xclip")
    fi
    
    if [[ ${#missing_tools[@]} -eq 0 ]]; then
        print_pass "所有依赖工具都已安装"
        return 0
    else
        print_fail "缺少依赖工具: ${missing_tools[*]}"
        return 1
    fi
}

# 测试脚本语法
test_script_syntax() {
    print_test "脚本语法检查"
    
    if [[ ! -f "$TEST_SCRIPT" ]]; then
        print_fail "优化脚本文件不存在: $TEST_SCRIPT"
        return 1
    fi
    
    if bash -n "$TEST_SCRIPT" 2>/dev/null; then
        print_pass "脚本语法正确"
        return 0
    else
        print_fail "脚本语法错误"
        return 1
    fi
}

# 测试权限
test_permissions() {
    print_test "文件权限检查"
    
    if [[ -x "$TEST_SCRIPT" ]]; then
        print_pass "脚本具有执行权限"
    else
        print_fail "脚本缺少执行权限"
        print_info "运行: chmod +x $TEST_SCRIPT"
        return 1
    fi
    
    return 0
}

# 测试音频设备
test_audio_devices() {
    print_test "音频设备检查"
    
    local audio_system_found=false
    
    # 检查 PipeWire (现代音频系统)
    if command -v pipewire >/dev/null 2>&1; then
        if pgrep -x pipewire >/dev/null 2>&1; then
            print_pass "PipeWire 正在运行 (现代音频系统)"
            audio_system_found=true
        else
            print_info "PipeWire 已安装但未运行"
        fi
    fi
    
    # 检查 PulseAudio (传统音频系统)
    if command -v pulseaudio >/dev/null 2>&1; then
        if pulseaudio --check 2>/dev/null; then
            if [[ "$audio_system_found" == "true" ]]; then
                print_pass "PulseAudio 兼容层正在运行"
            else
                print_pass "PulseAudio 正在运行"
                audio_system_found=true
            fi
        else
            if [[ "$audio_system_found" == "false" ]]; then
                print_fail "PulseAudio 未运行"
                print_info "尝试启动: pulseaudio --start"
            fi
        fi
    fi
    
    if [[ "$audio_system_found" == "false" ]]; then
        print_fail "未检测到运行中的音频系统 (PipeWire 或 PulseAudio)"
        return 1
    fi
    
    # 检查录音设备 (pactl 兼容 PipeWire 和 PulseAudio)
    if command -v pactl >/dev/null 2>&1; then
        local sources
        sources=$(pactl list short sources 2>/dev/null | wc -l)
        if [[ $sources -gt 0 ]]; then
            print_pass "检测到 $sources 个音频输入设备"
        else
            print_fail "未检测到音频输入设备"
            return 1
        fi
    else
        print_fail "pactl 命令未找到 (需要 pulseaudio-utils 或 pipewire-pulse)"
        return 1
    fi
    
    return 0
}

# 测试临时目录创建
test_temp_directory() {
    print_test "临时目录创建"
    
    local test_temp_dir="/tmp/voice_input_test_$$"
    
    if mkdir -p "$test_temp_dir" 2>/dev/null; then
        print_pass "临时目录创建成功"
        rm -rf "$test_temp_dir"
        return 0
    else
        print_fail "临时目录创建失败"
        return 1
    fi
}

# 测试 Whisper 模型
test_whisper_model() {
    print_test "Whisper 模型检查"
    
    if ! command -v whisper >/dev/null 2>&1; then
        print_fail "Whisper 未安装"
        return 1
    fi
    
    # 创建测试音频文件
    local test_audio="/tmp/whisper_test_$$.wav"
    
    if command -v sox >/dev/null 2>&1; then
        # 创建1秒的静音文件用于测试
        if sox -n -r 16000 -c 1 "$test_audio" synth 1 sine 440 vol 0.01 2>/dev/null; then
            print_info "创建测试音频文件"
            
            # 测试 Whisper
            if timeout 30 whisper "$test_audio" \
                --language Chinese \
                --model tiny \
                --fp16 False \
                --output_format txt \
                --output_dir /tmp \
                --verbose False >/dev/null 2>&1; then
                print_pass "Whisper 模型工作正常"
                rm -f "$test_audio" "/tmp/whisper_test_$$.txt"
                return 0
            else
                print_fail "Whisper 模型测试失败"
                rm -f "$test_audio"
                return 1
            fi
        else
            print_fail "无法创建测试音频文件"
            return 1
        fi
    else
        print_info "跳过 Whisper 测试（需要 sox 工具）"
        return 0
    fi
}

# 测试通知系统
test_notification() {
    print_test "通知系统检查"
    
    if command -v notify-send >/dev/null 2>&1; then
        if notify-send "测试通知" "语音输入系统测试" 2>/dev/null; then
            print_pass "通知系统工作正常"
            return 0
        else
            print_fail "通知系统测试失败"
            return 1
        fi
    else
        print_fail "notify-send 未安装"
        return 1
    fi
}

# 性能基准测试
test_performance() {
    print_test "性能基准测试"
    
    local start_time end_time duration
    
    # 测试脚本启动时间
    start_time=$(date +%s.%N)
    bash -c "source '$TEST_SCRIPT' && check_dependencies" 2>/dev/null || true
    end_time=$(date +%s.%N)
    
    duration=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "0.1")
    
    if (( $(echo "$duration < 1.0" | bc -l 2>/dev/null || echo "1") )); then
        print_pass "脚本启动时间: ${duration}s (良好)"
    else
        print_fail "脚本启动时间: ${duration}s (较慢)"
    fi
}

# 生成测试报告
generate_report() {
    echo
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}  测试报告${NC}"
    echo -e "${BLUE}================================${NC}"
    echo -e "总测试数: $TESTS_TOTAL"
    echo -e "${GREEN}通过: $TESTS_PASSED${NC}"
    echo -e "${RED}失败: $TESTS_FAILED${NC}"
    
    local success_rate
    if [[ $TESTS_TOTAL -gt 0 ]]; then
        success_rate=$(( TESTS_PASSED * 100 / TESTS_TOTAL ))
        echo -e "成功率: ${success_rate}%"
    fi
    
    echo
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}🎉 所有测试通过！系统准备就绪。${NC}"
        return 0
    else
        echo -e "${RED}⚠️  有 $TESTS_FAILED 个测试失败，请检查上述问题。${NC}"
        echo
        echo -e "${YELLOW}建议操作:${NC}"
        echo "1. 安装缺失的依赖工具"
        echo "2. 检查音频设备配置"
        echo "3. 确认音频系统正常运行 (PipeWire 或 PulseAudio)"
        echo "4. 运行安装脚本: ./install.sh"
        return 1
    fi
}

# 主函数
main() {
    print_header
    
    # 运行所有测试
    test_script_syntax
    test_permissions
    test_dependencies
    test_temp_directory
    test_audio_devices
    test_notification
    test_whisper_model
    test_performance
    
    # 生成报告
    generate_report
}

# 检查 bc 命令（用于浮点计算）
if ! command -v bc >/dev/null 2>&1; then
    echo "警告: bc 命令未安装，性能测试可能不准确"
fi

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi