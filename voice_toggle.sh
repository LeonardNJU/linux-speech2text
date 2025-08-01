#!/bin/bash

SOCAT_PID=""
FFMPEG_PID=""
REC_PATH="/tmp/voice_input.wav"
TTY_IN="/tmp/ffmpeg.stdin"
TTY_CTRL="/tmp/ffmpeg.control"

AUDIO_FILE="/tmp/voice_input.wav"
PID_FILE="/tmp/voice_record_pid"
MAX_DURATION=60
REMINDER_TIME=50
DING=~/scripts/ding.wav

start_recording() {
  REC_PATH="${1:-$REC_PATH}"  # 可传入录音路径
  socat -d -d \
    PTY,raw,echo=0,link="$TTY_IN" \
    PTY,raw,echo=0,link="$TTY_CTRL" &
  SOCAT_PID=$!

  for i in {1..10}; do
    [[ -e "$TTY_IN" && -e "$TTY_CTRL" ]] && break
    sleep 0.1
  done

  ffmpeg -loglevel quiet -y -f pulse -i default -ac 1 -ar 16000 "$REC_PATH" < "$TTY_IN" &
  echo $! > "$PID_FILE"

#  echo "🎙️ Recording started: $REC_PATH"
  notify-send "🎙️ Recording started: $REC_PATH"
}

stop_recording() {
  if [[ -e "$TTY_CTRL" ]]; then
    echo q > "$TTY_CTRL"
#    echo "🛑 Stopping ffmpeg recording..."
    notify-send "🛑 Stopping ffmpeg recording..."
  fi

  FFMPEG_PID=$(cat "$PID_FILE")
  tail --pid="$FFMPEG_PID" -f /dev/null

  kill "$SOCAT_PID" "$FFMPEG_PID" 2>/dev/null
  rm -f "$TTY_IN" "$TTY_CTRL"

#  echo "✅ Recording stopped and cleaned up."
  notify-send "✅ Recording stopped and cleaned up."
}




if [ -f "$PID_FILE" ]; then
    # 正在录音，停止并识别
    stop_recording
    rm "$PID_FILE"
    notify-send "🎧 录音结束" "正在识别中..."
#    echo "🎧 录音结束" "正在识别中..."

    TEXT=$(whisper "$AUDIO_FILE" --language Chinese --model base --fp16 False --output_format txt --output_dir /tmp > /dev/null 2>&1 && cat /tmp/voice_input.txt)

    notify-send "✅ 识别完成" "$TEXT"
#    echo "✅ 识别完成" "$TEXT"
    if command -v xdotool >/dev/null; then
        xdotool type --clearmodifiers "$TEXT"
    else
        echo "$TEXT" | xclip -selection clipboard
        notify-send "xdotool 不可用，已复制到剪贴板"
#        echo "xdotool 不可用，已复制到剪贴板"
    fi
else
    # 没有在录音，启动录音
    paplay "$DING" &
    notify-send "🎙️ 正在录音..." "再次按下 Super+V 停止（最多 ${MAX_DURATION} 秒）"
#    echo "🎙️ 正在录音..." "再次按下 Super+V 停止（最多 ${MAX_DURATION} 秒）"

    rm -f "$AUDIO_FILE" "$PID_FILE"
    start_recording "$AUDIO_FILE"
    echo $! > "$PID_FILE"

    (
        sleep $REMINDER_TIME
        [ -f "$PID_FILE" ] && notify-send "⚠️ 快结束啦" "还剩 $(($MAX_DURATION - $REMINDER_TIME)) 秒"
#        [ -f "$PID_FILE" ] && echo "⚠️ 快结束啦" "还剩 $(($MAX_DURATION - $REMINDER_TIME)) 秒"
    ) &

    (
      sleep "$MAX_DURATION"
      if [ -f "$PID_FILE" ]; then
          stop_recording
          rm "$PID_FILE"
          notify-send "⏱️ 自动停止录音" "已达到最大时长 ${MAX_DURATION} 秒"

          TEXT=$(whisper "$AUDIO_FILE" --language Chinese --model base --fp16 False --output_format txt --output_dir /tmp > /dev/null 2>&1 && cat /tmp/voice_input.txt)

          notify-send "✅ 识别完成" "$TEXT"
      #    echo "✅ 识别完成" "$TEXT"
          if command -v xdotool >/dev/null; then
              xdotool type --clearmodifiers "$TEXT"
          else
              echo "$TEXT" | xclip -selection clipboard
              notify-send "xdotool 不可用，已复制到剪贴板"
      #        echo "xdotool 不可用，已复制到剪贴板"
          fi
      fi
  ) &
fi
