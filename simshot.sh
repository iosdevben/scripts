#!/bin/bash

OUTFILE="$HOME/Desktop/simulator_$(date +%Y%m%d_%H%M%S).png"
TMPFILE=$(mktemp /tmp/sim_XXXXXX.png)

# Capture Simulator window without shadow
screencapture -l $(GetWindowID "Simulator" "iPhone") -o "$TMPFILE"

# Get dimensions
WIDTH=$(sips -g pixelWidth "$TMPFILE" | awk '/pixelWidth/{print $2}')
HEIGHT=$(sips -g pixelHeight "$TMPFILE" | awk '/pixelHeight/{print $2}')

# Crop the macOS title bar (56px at 2x display)
CROP_TOP=56
NEW_HEIGHT=$((HEIGHT - CROP_TOP))

sips --cropOffset 0 $CROP_TOP --cropBox $WIDTH $NEW_HEIGHT "$TMPFILE" --out "$OUTFILE"

rm "$TMPFILE"

# Copy to clipboard as PNG
osascript -e "set the clipboard to (read (POSIX file \"$OUTFILE\") as «class PNGf»)"

echo "$OUTFILE"