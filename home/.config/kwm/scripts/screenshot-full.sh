#!/bin/sh
# Captura a tela inteira com grim e salva com timestamp.
# Chamado pelo kwm via: sh -c "$HOME/.config/kwm/scripts/screenshot-full.sh"

DIR="$HOME/Pictures/Screenshots"
mkdir -p "$DIR"
FILE="$DIR/$(date +%Y-%m-%d_%H-%M-%S).png"

grim "$FILE"

if command -v notify-send >/dev/null 2>&1; then
    notify-send "Screenshot" "Salvo em $FILE"
fi
