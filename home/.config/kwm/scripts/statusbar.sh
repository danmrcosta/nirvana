#!/usr/bin/env bash
FIFO="$HOME/.cache/kwm/statusbar.fifo"
mkdir -p "$(dirname "$FIFO")"
[ -p "$FIFO" ] || mkfifo "$FIFO"

# abre o FIFO uma vez só e mantém o fd 3 aberto pro resto da vida do script
exec 3>"$FIFO"

while true; do
    printf '🕒 %s\n' "$(date '+%d/%m/%Y | %H:%M')" >&3
    sleep 1
done
