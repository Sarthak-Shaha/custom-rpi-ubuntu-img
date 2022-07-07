#!/bin/bash

echo "START CUSTOMIZATION THE IMAGE"
sudo echo "$(whoami) ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers

echo "===================================="
echo "1. Update submoddules"
echo "===================================="
git submodule update --init --recursive &&
echo "===================================="
cp -f ./script/expand.sh ./docker-rpi-emu/scripts/
echo "2. Run bootstrap for Qemu"
echo "===================================="
sudo ./script/bootstrap.sh && 
echo "===================================="
echo "3. Start building"
echo "===================================="
./build.sh &&

rm -f /home/$(whoami)/.cache/tools/images/* /tmp/raspbian-ubuntu/*

sudo sed -i "/$(whoami) ALL=(ALL) NOPASSWD:ALL/d" /etc/sudoers

echo "Customization is done."
