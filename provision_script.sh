#!/bin/bash

# Update and upgrade
sudo apt-get update && sudo apt-get upgrade -y

# Install XFCE desktop environment
sudo apt-get install xfce4 xfce4-goodies -y

# Install XRDP
sudo apt-get install xrdp -y
sudo systemctl enable xrdp
sudo adduser xrdp ssl-cert

# Configure XFCE for XRDP
echo xfce4-session >~/.xsession

# Open RDP port
sudo ufw allow 3389

# Install a browser
sudo apt-get install firefox -y

# Reboot the system
sudo reboot
