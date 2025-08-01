#!/bin/bash
echo "Updating Pacman packages..."
sudo pacman -Syu --noconfirm

echo "Updating AUR packages..."
yay -Syu --noconfirm

echo "Cleaning orphaned packages..."
sudo pacman -Rns $(pacman -Qdtq) --noconfirm

echo "Cleaning cache..."
sudo pacman -Sc --noconfirm
chmod +x ~/update-system.sh
