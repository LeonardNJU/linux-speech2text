# linux-speech2text
a tiny script to make speak2text easier on linux

## Installation
this solution of typing by sound requires following dependecies:
- openai-whisper
- xdotools or xclip
- ffmpeg
- socat
- libnotify-bin

So you should do following: (take debian for example, while arch and red hat can also benefit from this project)
```bash
pip install openai-whisper # maybe you should add --break-system-package if you want to install it globally
sudo apt install xclip ffmpeg socat libnotify-bin

# and initialize whisper by using it once, or it will takes you 5min orso when you first use it since it need download model to your local.
# Replace $AUDIO_FILE to what ever audio file you have, we just need it to be run once.
whisper "$AUDIO_FILE" --language Chinese --model base --fp16 False --output_format txt --output_dir /tmp > /dev/null 2>&1
```

## Usage
```bash
lsamc@workstation:~/voice$ bash voice_toggle.sh
🎙️ 正在录音... 再次按下 Super+V 停止（最多 60 秒）
open(): No such file or directory
2025/08/01 10:43:29 socat[65877] N PTY is /dev/pts/31
2025/08/01 10:43:29 socat[65877] N PTY is /dev/pts/32
2025/08/01 10:43:29 socat[65877] N starting data transfer loop with FDs [5,5] and [7,7]
🎙️ Recording started: /tmp/voice_input.wav

lsamc@workstation:~/voice$ bash voice_toggle.sh 
🛑 Stopping ffmpeg recording...
✅ Recording stopped and cleaned up.
🎧 录音结束 正在识别中...
✅ 识别完成 一、二、三、四
接下来说一段话
xdotool 不可用，已复制到剪贴板

lsamc@workstation:~/voice$ 一、二、三、四
接下来说一段话

```
As simple as that. ran this script once to start recording, ran it another time to stop it and turns it into text.

NOTE: it will run faster on machines support Cuda, otherwise it will take a little bigger time. Also, can replace whisper to fast whisper

And of course, one can bind it to a shortcut to make work task on linux easier!