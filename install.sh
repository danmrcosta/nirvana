#!/usr/bin/env bash
# nirvana — instala o meu Arch + niri em qualquer notebook/PC.
# Detecta sozinho CPU e GPU (AMD, Intel, NVIDIA ou híbrido) e instala
# os drivers e ajustes certos. Rodar num Arch recém-instalado, como
# usuário normal (com sudo):   ./install.sh
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
HW="$DIR/home/.local/bin/niri-hardware"
G='\033[0;32m'; B='\033[0;34m'; Y='\033[1;33m'; N='\033[0m'
passo() { echo -e "\n${G}==> $*${N}"; }
aviso() { echo -e "${Y}!! $*${N}"; }

[[ $EUID -eq 0 ]] && { echo "Rode como seu usuário, não como root."; exit 1; }
[[ -f /etc/arch-release ]] || { echo "Isto é para Arch Linux."; exit 1; }

# ── 0. Hardware ──────────────────────────────────────────────────────────────
CPU=$(bash "$HW" cpu)
GPUS=$(bash "$HW" gpus)
tem() { [[ " $GPUS " == *" $1 "* ]]; }
NVIDIA=0; tem nvidia && NVIDIA=1
HIBRIDO=0; if [[ $NVIDIA -eq 1 ]] && { tem intel || tem amd; }; then HIBRIDO=1; fi

echo -e "${B}=== nirvana · Arch + niri ===${N}"
echo "CPU: $CPU   GPUs: ${GPUS:-nenhuma detectada}   híbrido: $([[ $HIBRIDO -eq 1 ]] && echo sim || echo não)"

# ── 1. pacman.conf: multilib + cor + downloads paralelos ────────────────────
passo "Ajustando pacman.conf"
sudo sed -i 's/^#Color/Color/; s/^#ParallelDownloads.*/ParallelDownloads = 5/' /etc/pacman.conf
if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
    sudo sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' /etc/pacman.conf
fi

# ── 2. Pacotes ───────────────────────────────────────────────────────────────
passo "Escolhendo pacotes para este hardware"
PKGS=()
lista() { mapfile -t -O "${#PKGS[@]}" PKGS < <(grep -v '^\s*$' "$DIR/pacotes/$1"); }
lista base.txt
case $CPU in amd) PKGS+=(amd-ucode) ;; intel) PKGS+=(intel-ucode) ;; esac
tem amd    && lista gpu-amd.txt
tem intel  && lista gpu-intel.txt
if [[ $NVIDIA -eq 1 ]]; then
    lista gpu-nvidia.txt
    # o driver NVIDIA é DKMS: precisa dos headers de cada kernel instalado
    for k in /usr/lib/modules/*/pkgbase; do PKGS+=("$(cat "$k")-headers"); done
    PKGS+=(linux-zen-headers)
    [[ $HIBRIDO -eq 1 ]] && PKGS+=(nvidia-prime)
fi
# leitor de digital (Synaptics, Goodix, Validity, Elan, FPC…)
if grep -qsxE '06cb|27c6|138a|10a5|2808|1c7a|04f3' /sys/bus/usb/devices/*/idVendor; then
    PKGS+=(fprintd)
fi
mapfile -t PKGS < <(printf '%s\n' "${PKGS[@]}" | sort -u)
echo "${#PKGS[@]} pacotes."
sudo pacman -Syu --needed --noconfirm "${PKGS[@]}"

# ── 3. Paru + AUR ────────────────────────────────────────────────────────────
passo "AUR (paru)"
if ! command -v paru &>/dev/null; then
    tmp=$(mktemp -d)
    git clone https://aur.archlinux.org/paru-bin.git "$tmp/paru"
    (cd "$tmp/paru" && makepkg -si --noconfirm)
fi
mapfile -t AUR < <(grep -vE '^(paru|paru-bin|paru-debug)?$' "$DIR/pacotes/aur.txt" || true)
if [[ ${#AUR[@]} -gt 0 ]]; then paru -S --needed --noconfirm "${AUR[@]}"; fi

# ── 4. Flatpak ───────────────────────────────────────────────────────────────
passo "Flatpak"
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
while read -r app; do
    if [[ -n $app ]]; then flatpak install --user -y flathub "$app" || aviso "falhou: $app"; fi
done < "$DIR/pacotes/flatpak.txt"

# ── 5. Dotfiles (faz backup do que já existir) ──────────────────────────────
passo "Copiando configs para ~"
BK="$HOME/.backup-antes-do-nirvana-$(date +%F-%H%M)"
(cd "$DIR/home" && find . -mindepth 1 \( -type f -o -type l \)) | while read -r f; do
    if [[ -e "$HOME/$f" ]]; then mkdir -p "$BK/$(dirname "$f")"; cp -a "$HOME/$f" "$BK/$f"; fi
done
cp -a "$DIR/home/." "$HOME/"
chmod +x "$HOME"/.local/bin/*
mkdir -p "$HOME/Pictures/Screenshots"
xdg-user-dirs-update || true
if [[ -d $BK ]]; then echo "Backup dos arquivos antigos: $BK"; fi

passo "Gerando config da tela (niri-hardware)"
"$HOME/.local/bin/niri-hardware"
niri validate >/dev/null 2>&1 && echo "config do niri válida" || aviso "rode 'niri validate' para ver o erro"

# ── 6. Arquivos de sistema ───────────────────────────────────────────────────
passo "Configurações de sistema"
sudo install -Dm644 "$DIR/sistema/zram-generator.conf" /etc/systemd/zram-generator.conf
sudo install -Dm644 "$DIR/sistema/wifi_backend.conf" /etc/NetworkManager/conf.d/wifi_backend.conf
sudo install -Dm644 "$DIR/sistema/ly-config.ini" /etc/ly/config.ini

if [[ $NVIDIA -eq 1 ]]; then
    echo "NVIDIA: modeset, suspensão e ajuste de VRAM do niri"
    sudo install -Dm644 "$DIR/sistema/nvidia/nvidia.conf" /etc/modprobe.d/nvidia.conf
    sudo install -Dm644 "$DIR/sistema/nvidia/50-limit-free-buffer-pool-in-wayland-compositors.json" \
        /etc/nvidia/nvidia-application-profiles-rc.d/50-limit-free-buffer-pool-in-wayland-compositors.json
    # o hook "kms" põe o nouveau no initramfs — com o driver NVIDIA ele sai
    sudo sed -i -E '/^HOOKS=/ s/ kms//' /etc/mkinitcpio.conf
    sudo systemctl enable nvidia-suspend nvidia-resume nvidia-hibernate
fi
sudo mkinitcpio -P

# Idioma e fuso
sudo sed -i -E 's/^#(en_US.UTF-8 UTF-8)/\1/; s/^#(pt_BR.UTF-8 UTF-8)/\1/' /etc/locale.gen
sudo locale-gen
printf 'LANG=en_US.UTF-8\nLC_ALL=en_US.UTF-8\n' | sudo tee /etc/locale.conf >/dev/null
sudo timedatectl set-timezone America/Sao_Paulo || true

# ── 7. Serviços ──────────────────────────────────────────────────────────────
passo "Ativando serviços"
sudo systemctl enable NetworkManager bluetooth tuned ufw lm_sensors fstrim.timer systemd-timesyncd
sudo systemctl disable getty@tty1 2>/dev/null || true
sudo systemctl enable ly@tty1
sudo ufw default deny incoming && sudo ufw enable || true
sudo sensors-detect --auto >/dev/null 2>&1 || true

echo -e "\n${B}=== Pronto! Reinicie (sudo reboot) e entre no niri pelo ly. ===${N}"
