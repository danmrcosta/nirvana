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

# Tudo que aparece na tela também vai para um log, para achar erros depois
LOG="$HOME/nirvana-install-$(date +%F-%H%M).log"
exec > >(tee -a "$LOG") 2>&1
trap 'echo -e "\n\033[0;31m!! Parou na linha $LINENO. Log completo: $LOG\033[0m"' ERR

instalado() { [[ $(pacman -Qq "$1" 2>/dev/null) == "$1" ]]; }
ativo() { systemctl is-enabled "$1" &>/dev/null; }

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

# Se o Arch foi instalado com um perfil de desktop (KDE, GNOME…) ou com o
# driver NVIDIA do archinstall, há pacotes que conflitam com os do nirvana.
# Com --noconfirm o pacman recusa a troca e para tudo; então removemos antes
# (-dd: os substitutos abaixo fornecem o mesmo, nada fica quebrado).
passo "Resolvendo conflitos com o que já está instalado"
TROCAR=()
for p in power-profiles-daemon pulseaudio pulseaudio-bluetooth jack2; do
    instalado "$p" && TROCAR+=("$p")
done
if [[ $NVIDIA -eq 1 ]]; then
    for p in nvidia nvidia-lts nvidia-dkms nvidia-open nvidia-open-lts; do
        instalado "$p" && TROCAR+=("$p")
    done
fi
if [[ ${#TROCAR[@]} -gt 0 ]]; then
    echo "Trocando: ${TROCAR[*]}"
    sudo pacman -Rdd --noconfirm "${TROCAR[@]}"
else
    echo "Nenhum conflito."
fi
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
# atalhos quebrados (ex.: de um setup antigo) impediriam a cópia
(cd "$DIR/home" && find . -mindepth 1) | while read -r f; do
    if [[ -L $HOME/$f && ! -e $HOME/$f ]]; then echo "removendo atalho quebrado ~/${f#./}"; rm -f "$HOME/$f"; fi
done
cp -a "$DIR/home/." "$HOME/"
chmod +x "$HOME"/.local/bin/*
mkdir -p "$HOME/Pictures/Screenshots"
xdg-user-dirs-update || true
if [[ -d $BK ]]; then echo "Backup dos arquivos antigos: $BK"; fi

# sem aviso "Connection Established" do nm-applet ao conectar/desconectar
gsettings set org.gnome.nm-applet disable-connected-notifications true || true
gsettings set org.gnome.nm-applet disable-disconnected-notifications true || true

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
printf 'LANG=en_US.UTF-8\n' | sudo tee /etc/locale.conf >/dev/null
sudo timedatectl set-timezone America/Sao_Paulo || true

# ── 7. Serviços ──────────────────────────────────────────────────────────────
passo "Ativando serviços"
# Desliga o que o perfil do archinstall possa ter ativado e que brigaria
# com o nirvana: outro login gráfico, outro firewall, outra rede.
for s in sddm gdm lightdm lxdm greetd display-manager firewalld \
         systemd-networkd wpa_supplicant power-profiles-daemon; do
    if ativo "$s"; then echo "desativando $s"; sudo systemctl disable "$s" || true; fi
done
sudo rm -f /etc/systemd/system/display-manager.service
sudo systemctl enable NetworkManager bluetooth tuned ufw lm_sensors fstrim.timer systemd-timesyncd
sudo systemctl disable getty@tty1 2>/dev/null || true
sudo systemctl enable ly@tty1
sudo ufw default deny incoming && sudo ufw enable || true
sudo sensors-detect --auto >/dev/null 2>&1 || true

echo -e "\n${B}=== Pronto! Reinicie (sudo reboot) e entre no niri pelo ly. ===${N}"
echo "Log: $LOG"
