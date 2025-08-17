#!/bin/bash

# 语音输入系统 - 优化版本
# 功能：按键切换录音状态，自动语音识别并输出文字

set -euo pipefail

# ==================== 配置区域 ====================
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TEMP_DIR="/tmp/voice_input"
readonly AUDIO_FILE="$TEMP_DIR/voice_input.wav"
readonly PID_FILE="$TEMP_DIR/recording.pid"
readonly LOG_FILE="$TEMP_DIR/voice_input.log"

readonly MAX_DURATION=60
readonly REMINDER_TIME=50
readonly SAMPLE_RATE=16000
readonly WHISPER_MODEL="small"
readonly WHISPER_LANGUAGE="Chinese"

# 提示音文件路径
readonly START_DING_PATHS=(
    "/usr/share/sounds/freedesktop/stereo/message-new-instant.oga"
)

readonly END_DING_PATHS=(
    "/usr/share/sounds/freedesktop/stereo/complete.oga"
)

# ==================== 工具函数 ====================

log() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    if [[ -d "$TEMP_DIR" ]]; then
        echo "$message" >> "$LOG_FILE"
    fi
}

error_exit() {
    local msg="$1"
    log "ERROR: $msg"
    notify-send "❌ 错误" "$msg" 2>/dev/null || true
    cleanup
    exit 1
}

notify() {
    local title="$1"
    local message="${2:-}"
    log "NOTIFY: $title - $message"
    if command -v notify-send >/dev/null 2>&1; then
        notify-send "$title" "$message"
    else
        echo "$title: $message"
    fi
}

check_dependencies() {
    local missing_deps=()
    
    for cmd in ffmpeg whisper; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        error_exit "缺少依赖工具: ${missing_deps[*]}. 请先安装这些工具。"
    fi
    
    if ! command -v xdotool >/dev/null 2>&1 && ! command -v xclip >/dev/null 2>&1; then
        error_exit "需要安装 xdotool 或 xclip 来输出文字"
    fi
    
    setup_audio_environment
}

setup_audio_environment() {
    if [[ -z "${XDG_RUNTIME_DIR:-}" ]]; then
        export XDG_RUNTIME_DIR="/run/user/$(id -u)"
        log "设置 XDG_RUNTIME_DIR: $XDG_RUNTIME_DIR"
    fi
    
    if ! pactl info >/dev/null 2>&1; then
        error_exit "无法连接到音频系统 (PipeWire/PulseAudio)，请检查音频服务状态"
    fi
    
    local input_sources
    input_sources=$(pactl list short sources 2>/dev/null | wc -l)
    if [[ $input_sources -eq 0 ]]; then
        error_exit "未检测到音频输入设备，请检查麦克风连接"
    fi
    
    log "音频环境检查完成，检测到 $input_sources 个音频输入设备"
}

find_start_ding_sound() {
    for path in "${START_DING_PATHS[@]}"; do
        if [[ -f "$path" ]]; then
            echo "$path"
            return 0
        fi
    done
    log "WARNING: 未找到开始录音提示音文件"
    return 1
}

find_end_ding_sound() {
    for path in "${END_DING_PATHS[@]}"; do
        if [[ -f "$path" ]]; then
            echo "$path"
            return 0
        fi
    done
    log "WARNING: 未找到结束录音提示音文件"
    return 1
}

setup_temp_dir() {
    if [[ ! -d "$TEMP_DIR" ]]; then
        mkdir -p "$TEMP_DIR" || error_exit "无法创建临时目录: $TEMP_DIR"
    fi
}

cleanup() {
    log "开始清理资源..."
    
    if [[ -f "$PID_FILE" ]]; then
        local ffmpeg_pid
        ffmpeg_pid=$(cat "$PID_FILE" 2>/dev/null || echo "")
        if [[ -n "$ffmpeg_pid" ]] && kill -0 "$ffmpeg_pid" 2>/dev/null; then
            log "停止 ffmpeg 进程: $ffmpeg_pid"
            kill -TERM "$ffmpeg_pid" 2>/dev/null || true
            local count=0
            while kill -0 "$ffmpeg_pid" 2>/dev/null && [[ $count -lt 50 ]]; do
                sleep 0.1
                ((count++))
            done
            if kill -0 "$ffmpeg_pid" 2>/dev/null; then
                kill -KILL "$ffmpeg_pid" 2>/dev/null || true
            fi
        fi
    fi
    
    rm -f "$PID_FILE" 2>/dev/null || true
    log "资源清理完成"
}

# ==================== 录音功能 ====================

start_recording() {
    log "开始启动录音..."
    
    ffmpeg -loglevel error -y \
        -f pulse -i default \
        -ac 1 -ar "$SAMPLE_RATE" \
        "$AUDIO_FILE" 2>>"$LOG_FILE" &
    
    local ffmpeg_pid=$!
    echo "$ffmpeg_pid" > "$PID_FILE"
    log "ffmpeg 进程已启动，PID: $ffmpeg_pid"
    
    local c2=0
    while [[ $c2 -lt 10 ]]; do
        if kill -0 "$ffmpeg_pid" 2>/dev/null; then
            break
        fi
        sleep 0.1; ((c2++))
    done
    
    if ! kill -0 "$ffmpeg_pid" 2>/dev/null; then
        log "ffmpeg 进程已退出，检查错误日志..."
        if [[ -f "$LOG_FILE" ]]; then
            log "最近的错误信息:"
            tail -5 "$LOG_FILE" | while read line; do log "  $line"; done
        fi
        cleanup
        rm -f "$PID_FILE"
        error_exit "录音启动失败，请检查音频设备"
    fi
    
    log "录音已启动，PID: $ffmpeg_pid"
    notify "🎙️ 开始录音" "再次运行脚本停止录音（最多 ${MAX_DURATION} 秒）"
    
    if ding_file=$(find_start_ding_sound); then
        if command -v paplay >/dev/null 2>&1; then
            paplay "$ding_file" 2>/dev/null &
        elif command -v aplay >/dev/null 2>&1; then
            aplay "$ding_file" 2>/dev/null &
        fi
    fi
}

stop_recording() {
    log "开始停止录音..."
    
    if [[ ! -f "$PID_FILE" ]]; then
        log "WARNING: PID文件不存在"
        return 1
    fi
    
    local ffmpeg_pid
    ffmpeg_pid=$(cat "$PID_FILE" 2>/dev/null || echo "")
    
    if [[ -z "$ffmpeg_pid" ]]; then
        log "WARNING: 无法读取录音进程PID"
        return 1
    fi
    
    log "发送停止信号给ffmpeg进程: $ffmpeg_pid"
    kill -TERM "$ffmpeg_pid" 2>/dev/null || true
    
    local count=0
    while kill -0 "$ffmpeg_pid" 2>/dev/null && [[ $count -lt 100 ]]; do
        sleep 0.1
        ((count++))
    done
    
    if kill -0 "$ffmpeg_pid" 2>/dev/null; then
        log "强制终止录音进程"
        kill -KILL "$ffmpeg_pid" 2>/dev/null || true
    fi
    
    cleanup
    rm -f "$PID_FILE"
    log "录音已停止"
    
    if ding_file=$(find_end_ding_sound); then
        if command -v paplay >/dev/null 2>&1; then
            paplay "$ding_file" 2>/dev/null &
        elif command -v aplay >/dev/null 2>&1; then
            aplay "$ding_file" 2>/dev/null &
        fi
    fi
    
    notify "🛑 录音结束" "正在进行语音识别..."
}

# ==================== 语音识别功能 ====================

recognize_speech() {
    log "开始语音识别..."
    
    if [[ ! -f "$AUDIO_FILE" ]]; then
        error_exit "录音文件不存在: $AUDIO_FILE"
    fi
    
    if [[ ! -s "$AUDIO_FILE" ]]; then
        error_exit "录音文件为空，请检查麦克风设置"
    fi
    
    local output_file="$TEMP_DIR/voice_input.txt"
    
    if ! whisper "$AUDIO_FILE" \
        --language "$WHISPER_LANGUAGE" \
        --model "$WHISPER_MODEL" \
        --fp16 False \
        --output_format txt \
        --output_dir "$TEMP_DIR" \
        --verbose False 2>>"$LOG_FILE"; then
        error_exit "语音识别失败，请检查音频质量"
    fi
    
    if [[ ! -f "$output_file" ]]; then
        error_exit "识别结果文件未生成"
    fi
    
    local text
    text=$(cat "$output_file" 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -d '\n')
    
    if [[ -z "$text" ]]; then
        notify "⚠️ 识别结果为空" "请检查录音内容或麦克风设置"
        return 1
    fi
    
    log "识别完成: $text"
    echo "$text"
}

output_text() {
    local text="$1"
    
    if [[ -z "$text" ]]; then
        log "WARNING: 输出文本为空"
        return 1
    fi
    
    log "输出文本: $text"
    
    local has_xdotool=false
    local has_xclip=false
    
    if command -v xdotool >/dev/null 2>&1; then
        has_xdotool=true
    fi
    
    if command -v xclip >/dev/null 2>&1; then
        has_xclip=true
    fi
    
    if [[ "$has_xdotool" == "false" && "$has_xclip" == "false" ]]; then
        error_exit "无法复制文字，请安装 xdotool 或 xclip"
    fi
    
    if [[ "$has_xclip" == "true" ]]; then
        echo "$text" | xclip -selection clipboard
        notify "✅ 识别完成" "已复制到剪贴板: $text"
    fi
    
    if [[ "$has_xdotool" == "true" ]]; then
        sleep 0.2
        xdotool type --clearmodifiers "$text"
        notify "✅ 已自动上屏"
    fi
}

# ==================== 定时器功能 ====================

start_reminder_timer() {
    (
        sleep "$REMINDER_TIME"
        if [[ -f "$PID_FILE" ]]; then
            local remaining=$((MAX_DURATION - REMINDER_TIME))
            notify "⚠️ 录音提醒" "还剩 ${remaining} 秒自动停止"
        fi
    ) &
}

start_max_duration_timer() {
    (
        sleep "$MAX_DURATION"
        if [[ -f "$PID_FILE" ]]; then
            log "达到最大录音时长，自动停止"
            stop_recording
            notify "⏱️ 自动停止" "已达到最大时长 ${MAX_DURATION} 秒"
            
            if text=$(recognize_speech); then
                output_text "$text"
            fi
        fi
    ) &
}

# ==================== 主程序逻辑 ====================

main() {
    trap cleanup INT TERM
    
    check_dependencies
    setup_temp_dir
    
    if [[ -f "$PID_FILE" ]]; then
        local ffmpeg_pid
        ffmpeg_pid="$(cat "$PID_FILE" 2>/dev/null || true)"
        if [[ -n "$ffmpeg_pid" ]] && kill -0 "$ffmpeg_pid" 2>/dev/null; then
            log "===语音输入系统-Phase2==="
            log "检测到正在录音，准备停止"
            if stop_recording; then
                if text=$(recognize_speech); then
                    output_text "$text"
                fi
            fi
            log "=== 程序执行完成 ==="
            return
        else
            log "PID 文件存在但 ffmpeg 未运行，视作未在录音；清理残留并重新开始"
            cleanup
            rm -f "$PID_FILE" 2>/dev/null || true
        fi
    fi

    log "===语音输入系统-Phase1==="
    rm -f "$AUDIO_FILE" 2>/dev/null || true

    start_recording
    start_reminder_timer
    start_max_duration_timer
    log "=== 程序执行完成 ==="
}

# ==================== 程序入口 ====================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi