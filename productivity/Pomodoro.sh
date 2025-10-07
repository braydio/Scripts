
#!/bin/bash

# Check if parameters are provided
if [ $# -ne 2 ]; then
    echo "Usage: Timer <work_duration_minutes> <break_duration_minutes>"
    exit 1
fi

# Parameters
work_duration=$1  # Work duration in minutes
break_duration=$2  # Break duration in minutes

# Path to Minecraft music
minecraft_music="$HOME/Music/MinecraftMusic.mp3"

# Function to start or unpause music
play_music() {
    if pgrep -x "mpv" >/dev/null; then
        # Unpause music if already playing
        echo "Pausing music..."
        playerctl play
    else
        # Start music if not already playing
        mpv --no-video "$minecraft_music" --loop-file=inf --input-ipc-server=/tmp/mpv-socket &
    fi
}

# Function to pause music
pause_music() {
    if pgrep -x "mpv" >/dev/null; then
        echo '{ "command": ["set_property", "pause", true] }' | socat - /tmp/mpv-socket
    fi
}

# Pomodoro loop
while true; do
    # Work session
    notify-send -t 5000 "Pomodoro Timer" "Work session started! Focus for $work_duration minutes."
    play_music
    sleep "$((work_duration * 60))"  # Convert minutes to seconds

    pause_music
    notify-send "Pomodoro Timer" "Work session completed! Take a $break_duration-minute break."

    # Break session
    sleep "$((break_duration * 60))"
    notify-send "Pomodoro Timer" "Break session over! Time to focus again."
done
