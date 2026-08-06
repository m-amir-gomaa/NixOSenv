#!/usr/bin/env bash
# record.sh — Chunked screen recording for Hyprland using wl-screenrec
#
# wl-screenrec has no native pause, so "pause" works by chunking:
#   pause  → SIGTERM the live chunk (file finalized cleanly)
#   resume → start a fresh chunk
#   stop   → ffmpeg-concat all chunks into one file (no timeline gap)
#
# Intel iGPU capture: LIBVA_DRIVER_NAME=iHD avoids the NVIDIA cross-GPU
# DMA-BUF copy that silently produces empty 0-byte files on Prime laptops.

SAVE_DIR="$HOME/Videos"
CHUNK_ROOT="/tmp"
PIDFILE="/tmp/record.pid"
SESSIONFILE="/tmp/record.session"
MODEFILE="/tmp/record.mode"

mkdir -p "$SAVE_DIR"

# Audio helpers (requires pulseaudio package for pactl)
get_sink() { pactl get-default-sink 2>/dev/null; }
get_source() { pactl get-default-source 2>/dev/null; }

# Live chunk dir, or empty when no session
chunk_dir() {
  if [ -f "$SESSIONFILE" ]; then echo "$CHUNK_ROOT/rec-$(cat "$SESSIONFILE")"; fi
}

session_active() {
  [ -f "$SESSIONFILE" ] && [ -d "$(chunk_dir)" ]
}

is_recording() {
  [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null
}

# Gracefully finalize the live wl-screenrec chunk (SIGTERM → file written)
finalize_chunk() {
  [ -f "$PIDFILE" ] || return
  PID=$(cat "$PIDFILE")
  if kill -0 "$PID" 2>/dev/null; then
    kill "$PID"
    sleep 0.8
  fi
  rm -f "$PIDFILE"
}

start_chunk() {
  MODE="$1"
  DIR="$(chunk_dir)"
  N=$(ls "$DIR"/chunk-*.mp4 2>/dev/null | wc -l)
  N=$((N + 1))
  OUTPUT="$DIR/chunk-$N.mp4"

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

  LIBVA_DRIVER_NAME=iHD wl-screenrec "${ARGS[@]}" >/dev/null 2>&1 &
  REC_PID=$!

  sleep 0.5
  if kill -0 "$REC_PID" 2>/dev/null; then
    echo "$REC_PID" >"$PIDFILE"
    echo "$MODE" >"$MODEFILE"
    notify-send -a "Recorder" -i "media-record" "⏺️ CHUNK $N" "$OUTPUT" -t 2000
  else
    notify-send -a "Recorder" -i "dialog-error" "❌ FAILED TO START RECORDING" "Check wl-screenrec and VAAPI drivers."
    return 1
  fi
}

new_session() {
  MODE="$1"
  SID=$(date +%Y%m%d-%H%M%S)
  echo "$SID" >"$SESSIONFILE"
  mkdir -p "$CHUNK_ROOT/rec-$SID"
  echo "$MODE" >"$MODEFILE"
}

stop_and_concat() {
  finalize_chunk

  DIR="$(chunk_dir)"
  if [ -n "$DIR" ] && [ -d "$DIR" ]; then
    # Non-empty chunks, numeric order (chunk-1, chunk-2, …, chunk-10)
    mapfile -t CHUNKS < <(find "$DIR" -name 'chunk-*.mp4' -size +0c | sort -V)

    if [ ${#CHUNKS[@]} -gt 0 ]; then
      MODE=$(cat "$MODEFILE" 2>/dev/null || echo "video")
      TS=$(cat "$SESSIONFILE")
      FINAL="$SAVE_DIR/rec-${MODE}-${TS}.mp4"
      LIST="$DIR/concat.txt"

      : >"$LIST"
      for C in "${CHUNKS[@]}"; do printf "file '%s'\n" "$C" >>"$LIST"; done

      # Primary: remux video copy, re-encode audio to AAC (opus-in-mp4 is
      # hostile to many players). Re-generate PTS so chunk boundaries stay clean.
      if ffmpeg -y -hide_banner -loglevel error -f concat -safe 0 -i "$LIST" \
          -c:v copy -c:a aac -b:a 192k -fflags +genpts "$FINAL"; then
        notify-send -a "Recorder" -i "media-playback-stop" "⏹️ SAVED" "$FINAL" -t 5000
      else
        # Fallback: full re-encode (timestamps too broken for stream copy)
        if ffmpeg -y -hide_banner -loglevel error -f concat -safe 0 -i "$LIST" \
            -c:v libx264 -crf 18 -preset fast -c:a aac -b:a 192k "$FINAL"; then
          notify-send -a "Recorder" -i "media-playback-stop" "⏹️ SAVED (re-encoded)" "$FINAL" -t 5000
        else
          notify-send -a "Recorder" -i "dialog-error" "❌ CONCAT FAILED" "Chunks kept in $DIR" -t 8000
        fi
      fi
    else
      notify-send -a "Recorder" -i "dialog-error" "⏹️ NOTHING TO SAVE" "No chunks recorded" -t 3000
    fi
    rm -rf "$DIR"
  fi
  rm -f "$PIDFILE" "$SESSIONFILE" "$MODEFILE"
}

pause_session() {
  finalize_chunk
  notify-send -a "Recorder" -i "media-playback-pause" "⏸️ PAUSED" "Resume with Super+P or the same key" -t 2000
}

case "$1" in
stop)
  stop_and_concat
  ;;

toggle)
  REQ_MODE="$2"
  if ! session_active; then
    # 1. No session → start fresh
    new_session "$REQ_MODE"
    start_chunk "$REQ_MODE"
  elif is_recording; then
    CUR=$(cat "$MODEFILE")
    if [ "$REQ_MODE" != "$CUR" ]; then
      # 2. Mode switch while live → finalize chunk, continue in new mode
      finalize_chunk
      echo "$REQ_MODE" >"$MODEFILE"
      start_chunk "$REQ_MODE"
    else
      # 3. Same mode → pause
      pause_session
    fi
  else
    # 4. Paused session → resume (mode may change)
    echo "$REQ_MODE" >"$MODEFILE"
    start_chunk "$REQ_MODE"
  fi
  ;;

toggle-pause)
  if is_recording; then
    pause_session
  elif session_active; then
    start_chunk "$(cat "$MODEFILE")"
  else
    notify-send -a "Recorder" -i "dialog-information" "Nothing to pause" "Start a recording first" -t 1500
  fi
  ;;

*)
  echo "Usage: $0 {stop|toggle video|toggle internal|toggle mic|toggle-pause}"
  exit 1
  ;;
esac
