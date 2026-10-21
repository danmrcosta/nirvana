# Sistema do Dan → Acer Predator Helios Neo 16

Seu Arch + niri do ThinkPad, adaptado para o Helios Neo 16
(Intel Core HX, RTX 4070, IPS 16" 2560x1600 @ 240Hz, MUX).

## Como usar

1. No Helios, instale um Arch limpo (`archinstall`):
   - kernel **linux-zen**, rede **NetworkManager**, usuário `dan` com sudo
   - perfil "Minimal" (o script instala o resto)
2. Copie `sistema-helios.tar.gz` (pendrive, scp, etc.) e rode:
   ```bash
   tar xzf sistema-helios.tar.gz && cd sistema-helios
   ./install.sh               # tudo, igual ao ThinkPad
   ./install.sh --sem-extras  # sem XFCE/i3, só niri
   ```
3. Reinicie e escolha **niri** no ly.

## O que vem

| Pasta | Conteúdo |
|---|---|
| `home/` | niri, waybar, alacritty, nvim, pcmanfm, htop, xfce4, river/kwm/triad, `.bashrc`, `~/.local/bin`, wallpaper |
| `pacotes/` | pacotes oficiais, AUR, flatpak e os drivers do Helios |
| `sistema/` | zram, NetworkManager+iwd, ly, configs NVIDIA |

Não vêm: Downloads, Pictures, Documents, Projects, perfil do Firefox, Proton VPN.

## O que mudou em relação ao ThinkPad

- **Tela**: `2560x1600`, 240Hz, escala `1.5` (texto do mesmo tamanho físico de antes).
  VRR liga só em jogos (Steam/gamescope); o desktop fica sempre em 240Hz.
- **Drivers**: saiu AMD (`amd-ucode`, `vulkan-radeon`, `xf86-video-*`), entrou
  `intel-ucode`, `nvidia-open-dkms`, `vulkan-intel`, `intel-media-driver`, `nvidia-prime`.
  O hook `kms` sai do mkinitcpio, suspensão da NVIDIA ativada e o niri recebe
  o ajuste da wiki que evita gastar VRAM à toa.
- **Removido**: `fprintd` (o Helios não tem leitor de digital).
- **Corrigido**: no ThinkPad o niri chamava `hypridle` e um agente polkit
  que não estão instalados. Agora usa `swayidle` (trava em 5 min, apaga a
  tela em 10) e `polkit-gnome`.
- Atalhos, workspaces, gaps, cores, animações desligadas: tudo igual.

## Se algo não funcionar

- **Brilho não muda**: adicione `acpi_backlight=nvidia_wmi_ec` aos parâmetros
  do kernel (em `/boot/loader/entries/*.conf`).
- **Teclado ABNT2** (Helios comprado no Brasil): em `~/.config/niri/config.kdl`
  troque `layout "us"` / `variant "intl"` por `layout "br"` e apague o `variant`.
- **MUX** (BIOS / PredatorSense): *Híbrido* gasta menos bateria;
  *só dGPU* é melhor para jogos. Os dois funcionam (a config cobre eDP-1 e eDP-2).
  Para rodar um app na NVIDIA no modo híbrido: `prime-run <app>`.
- **Ventoinhas/RGB/modo Turbo**: opcional, `paru -S linuwu-sense-dkms`.
- **Firefox**: para levar favoritos/senhas, copie `~/.mozilla` do ThinkPad
  com o Firefox fechado.
