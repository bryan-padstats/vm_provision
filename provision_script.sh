#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Log files
LOGFILE="/var/log/provision_script.log"
CHECKPOINT_LOG="/var/log/provision_checkpoints.log"
ERROR_LOG="/var/log/provision_errors.log"

# Redirect stdout and stderr to the LOGFILE
exec > >(tee -a "$LOGFILE") 2>&1

# Trap errors and log them
trap 'log_and_exit "Script exited with error on line $LINENO. Exit code: $?"' ERR

# Helper functions
log_checkpoint() {
  echo "[CHECKPOINT] $(date +'%Y-%m-%d %H:%M:%S') $1" | tee -a "$CHECKPOINT_LOG"
}

log_and_exit() {
  echo "[ERROR] $(date +'%Y-%m-%d %H:%M:%S') $1" | tee -a "$ERROR_LOG" >&2
  log_checkpoint "FAILED: $1"
  exit 1
}

verify_command() {
  if ! command -v "$1" &> /dev/null; then
    log_and_exit "$1 is not installed or not available in PATH."
  else
    log_checkpoint "$1 is available."
  fi
}

verify_service() {
  if ! systemctl is-active --quiet "$1"; then
    log_and_exit "$1 service is not active."
  else
    log_checkpoint "$1 service is active."
  fi
}

# Set non-interactive mode for APT
export DEBIAN_FRONTEND=noninteractive

# Start logging
log_checkpoint "Provisioning script started at $(date)"

# 1. Verify OS version
log_checkpoint "Checking operating system version..."
OS_VERSION=$(lsb_release -rs)
if [[ "$OS_VERSION" != "24.04" ]]; then
  log_and_exit "Unsupported OS version: $OS_VERSION. This script is designed for Ubuntu 24.04 LTS."
else
  log_checkpoint "OS version verified: Ubuntu $OS_VERSION"
fi

# 2. Configure partially installed packages
log_checkpoint "Configuring any partially installed packages..."
dpkg --configure -a || log_and_exit "Failed to configure partially installed packages."

# 3. Update package lists
log_checkpoint "Updating package lists..."
apt-get update -y || log_and_exit "Failed to update package lists."

# 4. Install essential utilities
log_checkpoint "Installing essential utilities (wget, curl, sudo)..."
apt-get install -y wget curl sudo || log_and_exit "Failed to install essential utilities."
verify_command wget
verify_command curl
verify_command sudo

# 5. Remove Snap to avoid conflicts
log_checkpoint "Removing Snap to prevent conflicts with Firefox..."
apt-get purge -y snapd || log_checkpoint "Snap is already removed; skipping."
rm -rf /var/cache/snapd /snap || log_checkpoint "Failed to clean Snap directories."

# 6. Install Python pip
log_checkpoint "Installing python3-pip..."
apt-get install -y python3-pip || log_and_exit "Failed to install python3-pip."
verify_command pip3

# # 7. Install Ubuntu Desktop Environment
# log_checkpoint "Installing Ubuntu Desktop Environment..."
# apt-get install -y ubuntu-desktop || log_and_exit "Failed to install Ubuntu Desktop."
# if ! dpkg -l | grep -q ubuntu-desktop; then
#   log_and_exit "Ubuntu Desktop installation failed or incomplete."
# else
#   log_checkpoint "Ubuntu Desktop installed successfully."
# fi

# # 7. Install XFCE (lightweight desktop environment)
# log_checkpoint "Installing XFCE desktop environment..."
# timeout 600 apt-get install -y xfce4 lightdm || {
# #timeout 600 apt-get install -y xfce4 xfce4-goodies lightdm || {
#   log_and_exit "Failed to install XFCE. Attempting recovery..."
#   dpkg --configure -a || log_and_exit "Failed to recover from XFCE installation error."
#   apt-get install -f || log_and_exit "Failed to fix broken dependencies."
# }
# echo "lightdm shared/default-x-display-manager select lightdm" | debconf-set-selections
# dpkg-reconfigure -f noninteractive lightdm || log_and_exit "Failed to configure LightDM."
# systemctl restart lightdm || log_and_exit "Failed to restart LightDM."
# verify_service lightdm

# # 8. Install and configure LightDM
# log_checkpoint "Installing LightDM and setting it as default display manager..."
# apt-get install -y lightdm || log_and_exit "Failed to install LightDM."
# echo "lightdm shared/default-x-display-manager select lightdm" | debconf-set-selections
# dpkg-reconfigure -f noninteractive lightdm || log_and_exit "Failed to configure LightDM as default display manager."
# systemctl restart lightdm || log_and_exit "Failed to restart LightDM."
# verify_service lightdm

# # 9. Install GNOME Keyring
# log_checkpoint "Installing and configuring GNOME Keyring..."
# apt-get install -y libpam-gnome-keyring || log_and_exit "Failed to install libpam-gnome-keyring."
# mkdir -p /root/.local/share/keyrings
# cat <<EOF > /root/.local/share/keyrings/login.keyring
# [org.freedesktop.Secret.Collection.Login]
# Name=Login
# DefaultCollection=true
# Unlocked=true
# EOF
# log_checkpoint "GNOME Keyring installed and configured."

# Install XFCE and LightDM with all necessary dependencies
log_checkpoint "Installing XFCE desktop environment and dependencies..."
apt-get install -y xfce4 xfce4-goodies lightdm dbus-x11 || log_and_exit "Failed to install XFCE or its dependencies."
echo "lightdm shared/default-x-display-manager select lightdm" | debconf-set-selections
dpkg-reconfigure -f noninteractive lightdm || log_and_exit "Failed to configure LightDM."
systemctl restart lightdm || log_and_exit "Failed to restart LightDM."
verify_service lightdm

# Configure XRDP to work with XFCE
log_checkpoint "Configuring XRDP for XFCE..."
apt-get install -y xrdp xorgxrdp || log_and_exit "Failed to install XRDP."
systemctl enable xrdp || log_and_exit "Failed to enable XRDP service."
systemctl start xrdp || log_and_exit "Failed to start XRDP service."
echo "startxfce4" > /etc/skel/.xsession
echo "startxfce4" > ~/.xsession
sed -i 's/^exec .*/exec startxfce4/' /etc/xrdp/startwm.sh
systemctl restart xrdp || log_and_exit "Failed to restart XRDP."
verify_service xrdp

# Ensure D-Bus is running
log_checkpoint "Ensuring D-Bus is active..."
systemctl enable dbus || log_and_exit "Failed to enable D-Bus."
systemctl start dbus || log_and_exit "Failed to start D-Bus."

log_checkpoint "XFCE and XRDP configuration completed successfully."


# 10. Add Mozilla PPA and install Firefox
log_checkpoint "Adding Mozilla PPA and installing Firefox..."
apt-get install -y software-properties-common || log_and_exit "Failed to install software-properties-common."
add-apt-repository -y ppa:mozillateam/ppa || log_and_exit "Failed to add Mozilla PPA."
cat <<EOF > /etc/apt/preferences.d/mozilla-firefox
Package: *
Pin: release o=LP-PPA-mozillateam
Pin-Priority: 1001
EOF
apt-get update -y || log_and_exit "Failed to update after adding Mozilla PPA."
apt-get install -y firefox || log_and_exit "Failed to install Firefox via APT."
verify_command firefox
log_checkpoint "Firefox installed successfully."

# 11. Configure random screen resolution
log_checkpoint "Configuring random screen resolution..."
RESOLUTION=$((RANDOM % 3))
if [ "$RESOLUTION" -eq 0 ]; then
  SCREEN_RES="1920x1080"
elif [ "$RESOLUTION" -eq 1 ]; then
  SCREEN_RES="1366x768"
else
  SCREEN_RES="1280x1024"
fi
log_checkpoint "Screen resolution set to ${SCREEN_RES}."
apt-get install -y xvfb || log_and_exit "Failed to install Xvfb."
Xvfb :99 -screen 0 ${SCREEN_RES}x24 &
export DISPLAY=:99
log_checkpoint "Xvfb configured and running."

# 12. Configure Firefox user agent and disable telemetry
log_checkpoint "Configuring Firefox user agent and disabling telemetry..."
USER_AGENTS=(
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:92.0) Gecko/20100101 Firefox/92.0"
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:93.0) Gecko/20100101 Firefox/93.0"
    "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:94.0) Gecko/20100101 Firefox/94.0"
)
RANDOM_USER_AGENT=${USER_AGENTS[$RANDOM % ${#USER_AGENTS[@]}]}
# Create Firefox profile directory if it doesn't exist
FIREFOX_PROFILE_DIR=$(find /root/.mozilla/firefox -maxdepth 1 -type d -name "*.default-release" | head -n 1)
if [ -z "$FIREFOX_PROFILE_DIR" ]; then
  log_checkpoint "Creating new Firefox profile."
  firefox -CreateProfile "default-release"
  FIREFOX_PROFILE_DIR=$(find /root/.mozilla/firefox -maxdepth 1 -type d -name "*.default-release" | head -n 1)
fi
cat <<EOF >> "$FIREFOX_PROFILE_DIR/prefs.js"
user_pref("general.useragent.override", "${RANDOM_USER_AGENT}");
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("toolkit.telemetry.enabled", false);
user_pref("browser.newtabpage.activity-stream.feeds.telemetry", false);
user_pref("browser.ping-centre.telemetry", false);
EOF
log_checkpoint "Firefox user agent configured."

# 13. Install and configure XRDP
log_checkpoint "Installing and configuring XRDP..."
apt-get install -y xrdp xorgxrdp || log_and_exit "Failed to install XRDP."
systemctl enable xrdp || log_and_exit "Failed to enable XRDP service."
systemctl start xrdp || log_and_exit "Failed to start XRDP service."
verify_service xrdp

# 14. Disable screen locking and blanking
log_checkpoint "Disabling screen locking and blanking..."
apt-get install -y dconf-cli || log_and_exit "Failed to install dconf-cli."
dconf write /org/gnome/desktop/screensaver/lock-enabled false || log_checkpoint "Failed to disable screen locking."
dconf write /org/gnome/desktop/session/idle-delay 0 || log_checkpoint "Failed to disable idle delay."
xset s off -dpms || log_checkpoint "Failed to disable display power management."

# 15. Clean up unnecessary files
log_checkpoint "Cleaning up unnecessary files..."
apt-get autoremove -y || log_checkpoint "No packages to autoremove."

# Log completion
log_checkpoint "Provisioning script completed successfully at $(date)"
