#!/bin/sh
# Captura uma área selecionada com slurp+grim, salva em arquivo E copia
# para a área de transferência (wl-copy) — mesmo comportamento do seu
# bind antigo do Hyprland, com o bônus de também salvar o arquivo.
# Chamado pelo kwm via: sh -c "$HOME/.config/kwm/scripts/screenshot-select.sh"

DIR="$HOME/Pictures/Screenshots"
mkdir -p "$DIR"
FILE="$DIR/$(date +%Y-%m-%d_%H-%M-%S)-selecao.png"

GEOM="$(slurp)"
[ -z "$GEOM" ] && exit 0   # usuário cancelou a seleção (ESC)

grim -g "$GEOM" "$FILE" && wl-copy < "$FILE"

if command -v notify-send >/dev/null 2>&1; then
    notify-send "Screenshot" "Área copiada e salva em $FILE"
fi
