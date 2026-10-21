#!/usr/bin/env bash
# Recria o sistema do Dan (niri + configs) no Acer Predator Helios Neo 16.
# Rodar num Arch Linux recém-instalado, como usuário normal (com sudo):
#   ./install.sh
# Opções:
#   --sem-extras   não instala XFCE/i3 (só o necessário pro niri)
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
G='\033[0;32m'; B='\033[0;34m'; Y='\033[1;33m'; N='\033[0m'
passo() { echo -e "\n${G}==> $*${N}"; }
aviso() { echo -e "${Y}!! $*${N}"; }

SEM_EXTRAS=0
for a in "$@"; do if [[ $a == --sem-extras ]]; then SEM_EXTRAS=1; fi; done

[[ $EUID -eq 0 ]] && { echo "Rode como seu usuário, não como root."; exit 1; }
[[ -f /etc/arch-release ]] || { echo "Isto é para Arch Linux."; exit 1; }

echo -e "${B}=== Instalando o sistema do Dan no Helios Neo 16 ===${N}"

# ── 1. pacman.conf: multilib + cor + downloads paralelos ────────────────────
passo "Ajustando pacman.conf"
sudo sed -i 's/^#Color/Color/; s/^#ParallelDownloads.*/ParallelDownloads = 5/' /etc/pacman.conf
if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
    sudo sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' /etc/pacman.conf
fi

# ── 2. Pacotes oficiais ──────────────────────────────────────────────────────
passo "Instalando pacotes (sistema + drivers Intel/NVIDIA)"
mapfile -t PKGS < <(cat "$DIR/pacotes/pacman.txt" "$DIR/pacotes/hardware-helios.txt" | grep -v '^\s*$')
if [[ $SEM_EXTRAS -eq 1 ]]; then
    mapfile -t PKGS < <(printf '%s\n' "${PKGS[@]}" | grep -vE '^(xfce4|xfwm4|xfdesktop|xfconf|xfburn|garcon|exo|thunar|i3-|i3status|parole|ristretto|mousepad|tumbler|dmenu)')
fi
sudo pacman -Syu --needed --noconfirm "${PKGS[@]}"

# ── 3. Paru + AUR ────────────────────────────────────────────────────────────
passo "AUR (paru)"
if ! command -v paru &>/dev/null; then
    tmp=$(mktemp -d)
    git clone https://aur.archlinux.org/paru-bin.git "$tmp/paru"
    (cd "$tmp/paru" && makepkg -si --noconfirm)
fi
mapfile -t AUR < <(grep -vE '^(paru|paru-debug)?$' "$DIR/pacotes/aur.txt" || true)
if [[ ${#AUR[@]} -gt 0 ]]; then paru -S --needed --noconfirm "${AUR[@]}"; fi

# ── 4. Flatpak ───────────────────────────────────────────────────────────────
passo "Flatpak"
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
while read -r app; do
    if [[ -n $app ]]; then flatpak install --user -y flathub "$app" || aviso "falhou: $app"; fi
done < "$DIR/pacotes/flatpak.txt"

# ── 5. Dotfiles (faz backup do que já existir) ──────────────────────────────
passo "Copiando configs para ~"
BK="$HOME/.backup-antes-do-sistema-helios-$(date +%F-%H%M)"
cd "$DIR/home"
find . -mindepth 1 \( -type f -o -type l \) | while read -r f; do
    if [[ -e "$HOME/$f" ]]; then mkdir -p "$BK/$(dirname "$f")"; cp -a "$HOME/$f" "$BK/$f"; fi
done
cp -a "$DIR/home/." "$HOME/"
chmod +x "$HOME"/.local/bin/* 2>/dev/null || true
mkdir -p "$HOME/Pictures/Screenshots"
xdg-user-dirs-update || true
if [[ -d $BK ]]; then echo "Backup dos arquivos antigos: $BK"; fi
cd "$DIR"

# ── 6. Arquivos de sistema ───────────────────────────────────────────────────
passo "Configurações de sistema"
sudo install -Dm644 sistema/zram-generator.conf /etc/systemd/zram-generator.conf
sudo install -Dm644 sistema/wifi_backend.conf /etc/NetworkManager/conf.d/wifi_backend.conf
sudo install -Dm644 sistema/ly-config.ini /etc/ly/config.ini
sudo install -Dm644 sistema/nvidia.conf /etc/modprobe.d/nvidia.conf
sudo install -Dm644 sistema/50-limit-free-buffer-pool-in-wayland-compositors.json \
    /etc/nvidia/nvidia-application-profiles-rc.d/50-limit-free-buffer-pool-in-wayland-compositors.json

# Com NVIDIA, o hook "kms" põe o nouveau no initramfs — remove ele.
sudo sed -i -E '/^HOOKS=/ s/ kms//' /etc/mkinitcpio.conf
sudo mkinitcpio -P

# Idioma e fuso (iguais ao ThinkPad)
sudo sed -i -E 's/^#(en_US.UTF-8 UTF-8)/\1/; s/^#(pt_BR.UTF-8 UTF-8)/\1/' /etc/locale.gen
sudo locale-gen
printf 'LANG=en_US.UTF-8\nLC_ALL=en_US.UTF-8\n' | sudo tee /etc/locale.conf >/dev/null
sudo timedatectl set-timezone America/Sao_Paulo || true

# ── 7. Serviços ──────────────────────────────────────────────────────────────
passo "Ativando serviços"
sudo systemctl enable NetworkManager bluetooth tuned ufw lm_sensors fstrim.timer systemd-timesyncd
sudo systemctl enable nvidia-suspend nvidia-resume nvidia-hibernate
sudo systemctl disable getty@tty1 2>/dev/null || true
sudo systemctl enable ly@tty1
sudo ufw default deny incoming && sudo ufw enable || true
sudo sensors-detect --auto >/dev/null || true

echo -e "\n${B}=== Pronto! Reinicie (sudo reboot) e escolha 'niri' no ly. ===${N}"
