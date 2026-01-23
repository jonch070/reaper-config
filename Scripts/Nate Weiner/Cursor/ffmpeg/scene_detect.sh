#!/bin/bash
# Scene Detection Wrapper Script
# Runs ffmpeg scene detection and signals completion via status file

VIDEO_FILE="$1"
START_TIME="$2"
DURATION="$3"
THRESHOLD="$4"
OUTPUT_FILE="$5"
STATUS_FILE="${OUTPUT_FILE}.status"
PID_FILE="${OUTPUT_FILE}.pid"
FFMPEG_PATH="$6"

# Write our PID so Lua can kill us if needed
echo $$ > "$PID_FILE"

# Write "processing" status
echo "processing" > "$STATUS_FILE"

# Run ffmpeg scene detection
# Optionally downscale for faster processing
if [ -n "$7" ] && [ "$7" -gt 0 ]; then
    DOWNSCALE_WIDTH="$7"
    VIDEO_FILTER="scale=${DOWNSCALE_WIDTH}:-1,select='gt(scene,${THRESHOLD})',showinfo"
else
    VIDEO_FILTER="select='gt(scene,${THRESHOLD})',showinfo"
fi

"${FFMPEG_PATH}" -ss "$START_TIME" -t "$DURATION" -i "$VIDEO_FILE" \
    -vf "$VIDEO_FILTER" \
    -f null - > "$OUTPUT_FILE" 2>&1

# Check if ffmpeg succeeded
if [ $? -eq 0 ]; then
    echo "done" > "$STATUS_FILE"
else
    echo "error" > "$STATUS_FILE"
fi

# Clean up PID file
rm -f "$PID_FILE"
