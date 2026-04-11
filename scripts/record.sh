#!/usr/bin/env bash
# record.sh — Screen recording script for Hyprland using wl-screenrec
# Handles multiple modes, pause/resume, and proper Intel iGPU acceleration.

SAVE_DIR="$HOME/Videos"
PIDFILE="/tmp/record.pid"
STATEFILE="/tmp/record.state"
MODEFILE="/tmp/record.mode"

mkdir -p "$SAVE_DIR"

# Audio helper (requires pulseaudio package for pactl)
get_sink() { pactl get-default-sink 2>/dev/null; }
get_source() { pactl get-default-source 2>/dev/null; }

stop_recording() {
	if [ -f "$PIDFILE" ]; then
		PID=$(cat "$PIDFILE")
		if kill -0 "$PID" 2>/dev/null; then
			kill "$PID"
			# Wait a bit for wl-screenrec to finalize the file
			sleep 0.8
		fi
		rm -f "$PIDFILE" "$STATEFILE" "$MODEFILE"
	fi
}

start_recording() {
	MODE="$1"
	TIMESTAMP=$(date +%Y%m%d-%H%M%S)
	MODE_NAME=$(echo "$MODE" | tr '[:lower:]' '[:upper:]')
	OUTPUT="$SAVE_DIR/rec-${MODE}-${TIMESTAMP}.mp4"

	# LIBVA_DRIVER_NAME=iHD is crucial for Intel iGPU capture in Prime setups.
	# It avoids cross-GPU copies that fail on NVIDIA.
	# --low-power=off is used if some drivers complain about RC modes.
	ARGS=("-f" "$OUTPUT")

	case "$MODE" in
	video)
		# Silent screen recording
		;;
	internal)
		# Desktop audio (Sink monitor)
		SINK=$(get_sink)
		if [ -n "$SINK" ]; then
			ARGS+=("--audio" "--audio-device" "$SINK.monitor")
		else
			ARGS+=("--audio")
		fi
		;;
	mic)
		# Microphone audio (Default source)
		SOURCE=$(get_source)
		if [ -n "$SOURCE" ]; then
			ARGS+=("--audio" "--audio-device" "$SOURCE")
		else
			ARGS+=("--audio")
		fi
		;;
	esac

	# Launch wl-screenrec
	LIBVA_DRIVER_NAME=iHD wl-screenrec "${ARGS[@]}" >/dev/null 2>&1 &
	REC_PID=$!

	sleep 0.5
	if kill -0 "$REC_PID" 2>/dev/null; then
		echo "$REC_PID" >"$PIDFILE"
		echo "running" >"$STATEFILE"
		echo "$MODE" >"$MODEFILE"
		notify-send -a "Recorder" -i "media-record" "⏺️ $MODE_NAME RECORDING" "$OUTPUT" -t 4000
	else
		notify-send -a "Recorder" -i "dialog-error" "❌ FAILED TO START RECORDING" "Check if wl-screenrec and VAAPI drivers are working."
	fi
}

toggle_recording() {
	REQ_MODE="$1"

	# 1. No recording running -> Start
	if [ ! -f "$PIDFILE" ]; then
		start_recording "$REQ_MODE"
		return
	fi

	PID=$(cat "$PIDFILE")
	# 2. PID file exists but process is dead -> Cleanup and Start
	if ! kill -0 "$PID" 2>/dev/null; then
		rm -f "$PIDFILE" "$STATEFILE" "$MODEFILE"
		start_recording "$REQ_MODE"
		return
	fi

	# 3. Mode mismatch -> Stop old, Start new
	CUR_MODE=$(cat "$MODEFILE" 2>/dev/null)
	if [ "$REQ_MODE" != "$CUR_MODE" ]; then
		stop_recording
		start_recording "$REQ_MODE"
		return
	fi

	# 4. Same mode -> Toggle Pause/Resume
	STATE=$(cat "$STATEFILE" 2>/dev/null)
	if [ "$STATE" = "running" ]; then
		kill -STOP "$PID"
		echo "paused" >"$STATEFILE"
		notify-send -a "Recorder" -i "media-playback-pause" "⏸️ RECORDING PAUSED" "Press key again to resume" -t 1000
	else
		kill -CONT "$PID"
		echo "running" >"$STATEFILE"
		notify-send -a "Recorder" -i "media-playback-start" "▶️ RECORDING RESUMED" "Press key again to pause" -t 2000
	fi
}

case "$1" in
stop)
	stop_recording
	notify-send -a "Recorder" -i "media-playback-stop" "⏹️ ALL RECORDING STOPPED" -t 3000
	;;
toggle)
	toggle_recording "$2"
	;;
*)
	echo "Usage: $0 {stop|toggle video|toggle internal|toggle mic}"
	exit 1
	;;
esac
