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

# Hardcoded DISPLAY settings
GUI_DISPLAY=":10"
NON_GUI_DISPLAY=":0"


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

# 5. Install XFCE and LightDM (GUI Environment)
log_checkpoint "Installing XFCE and LightDM (GUI environment)..."
apt-get install -y xfce4 xfce4-goodies lightdm dbus-x11 xrdp || log_and_exit "Failed to install GUI components."
echo "lightdm shared/default-x-display-manager select lightdm" | debconf-set-selections
dpkg-reconfigure -f noninteractive lightdm || log_and_exit "Failed to configure LightDM as default display manager."
systemctl enable lightdm || log_and_exit "Failed to enable LightDM."
systemctl start lightdm || log_and_exit "Failed to start LightDM."
verify_service lightdm
systemctl enable xrdp || log_and_exit "Failed to enable XRDP."
systemctl start xrdp || log_and_exit "Failed to start XRDP."
verify_service xrdp
log_checkpoint "GUI environment installed and configured successfully."

# Ensure XRDP uses XFCE
echo "startxfce4" > /etc/skel/.xsession
echo "startxfce4" > ~/.xsession
sed -i 's/^exec .*/exec startxfce4/' /etc/xrdp/startwm.sh || log_and_exit "Failed to configure XRDP to use XFCE."
log_checkpoint "XRDP configured to use XFCE."

# 6. Add Mozilla PPA and Install Firefox
log_checkpoint "Adding Mozilla PPA and installing Firefox..."
apt-get install -y software-properties-common || log_and_exit "Failed to install software-properties-common."
add-apt-repository -y ppa:mozillateam/ppa || log_and_exit "Failed to add Mozilla PPA."
apt-get update -y || log_and_exit "Failed to update after adding Mozilla PPA."
apt-get install -y firefox || log_and_exit "Failed to install Firefox."
verify_command firefox
log_checkpoint "Firefox installed successfully."

# 7. Use hardcoded DISPLAY
export DISPLAY=$GUI_DISPLAY
log_checkpoint "Using hardcoded DISPLAY=$DISPLAY for GUI operations."

# Grant access to X server for root
xhost +SI:localuser:root || log_and_exit "Failed to configure X server permissions for DISPLAY=$DISPLAY."

# Grant access to the X server
xhost +SI:localuser:root || log_and_exit "Failed to configure X server permissions for DISPLAY=$DISPLAY."

# Grant access to the X server
xhost +SI:localuser:root || log_and_exit "Failed to configure X server permissions for DISPLAY=$DISPLAY."

# 8. Create 5 Firefox Profiles with Randomized Settings
log_checkpoint "Creating 5 Firefox profiles with randomized settings..."

PROFILE_NAMES=("profile1" "profile2" "profile3" "profile4" "profile5")
PROFILE_DIR="/root/.mozilla/firefox"


# Predefined user agents and screen resolutions
USER_AGENTS=(
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:92.0) Gecko/20100101 Firefox/92.0"
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:93.0) Gecko/20100101 Firefox/93.0"
    "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:94.0) Gecko/20100101 Firefox/94.0"
    "Mozilla/5.0 (Windows NT 10.0; WOW64; rv:91.0) Gecko/20100101 Firefox/91.0"
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0 Safari/537.36"
)
SCREEN_RESOLUTIONS=("1920x1080" "1366x768" "1280x1024" "1600x900" "1024x768")

for ((i=0; i<${#PROFILE_NAMES[@]}; i++)); do
    PROFILE=${PROFILE_NAMES[i]}
    RANDOM_USER_AGENT=${USER_AGENTS[i]}
    RANDOM_RESOLUTION=${SCREEN_RESOLUTIONS[i]}

    log_checkpoint "Creating Firefox profile: $PROFILE with resolution $RANDOM_RESOLUTION and user agent $RANDOM_USER_AGENT..."
    firefox -CreateProfile "$PROFILE $PROFILE_DIR/$PROFILE" || log_and_exit "Failed to create Firefox profile: $PROFILE."

    PREF_FILE="$PROFILE_DIR/$PROFILE/prefs.js"
    mkdir -p "$PROFILE_DIR/$PROFILE"
    

    # Configure preferences
    cat <<EOF >> "$PREF_FILE"
user_pref("browser.shell.checkDefaultBrowser", false);
user_pref("browser.startup.homepage", "about:blank");
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("toolkit.telemetry.enabled", false);
user_pref("browser.newtabpage.activity-stream.feeds.telemetry", false);
user_pref("browser.ping-centre.telemetry", false);
user_pref("general.useragent.override", "$RANDOM_USER_AGENT");
user_pref("layout.css.devPixelsPerPx", "1.0");
EOF
    log_checkpoint "Configured preferences for $PROFILE."
done

log_checkpoint "All Firefox profiles created and configured successfully."

# 9. Create Desktop Shortcuts
DESKTOP_DIR="/home/$(whoami)/Desktop"
mkdir -p "$DESKTOP_DIR"

# Create a shared directory for Firefox profile shortcuts
SHARED_DIR="/home/shared/FirefoxProfiles"
mkdir -p "$SHARED_DIR"
chmod 777 "$SHARED_DIR"  # Make it accessible to all users
# Save shortcuts directly in the /home directory
SHORTCUT_DIR="/home/FirefoxProfiles"
mkdir -p "$SHORTCUT_DIR"
chmod 755 "$SHORTCUT_DIR"  # Set appropriate permissions



# Create shortcuts for all profiles in the /home directory
for PROFILE in "${PROFILE_NAMES[@]}"; do
    SHORTCUT_FILE="$SHORTCUT_DIR/firefox-$PROFILE.desktop"

    log_checkpoint "Creating shortcut for $PROFILE in /home..."
    cat <<EOF > "$SHORTCUT_FILE"
[Desktop Entry]
Version=1.0
Name=Firefox - $PROFILE
Comment=Launch Firefox with $PROFILE
Exec=firefox --no-remote -P "$PROFILE"
Icon=firefox
Terminal=false
Type=Application
Categories=Network;WebBrowser;
EOF

    chmod +x "$SHORTCUT_FILE"
    log_checkpoint "Shortcut created: $SHORTCUT_FILE"
done



# for PROFILE in "${PROFILE_NAMES[@]}"; do
#     SHORTCUT_FILE="$DESKTOP_DIR/firefox-$PROFILE.desktop"

#     log_checkpoint "Creating desktop shortcut for $PROFILE..."
#     cat <<EOF > "$SHORTCUT_FILE"
# [Desktop Entry]
# Version=1.0
# Name=Firefox - $PROFILE
# Comment=Launch Firefox with $PROFILE
# Exec=firefox --no-remote -P "$PROFILE"
# Icon=firefox
# Terminal=false
# Type=Application
# Categories=Network;WebBrowser;
# EOF

#     chmod +x "$SHORTCUT_FILE"
#     log_checkpoint "Desktop shortcut created: $SHORTCUT_FILE"
# done

log_checkpoint "All Firefox desktop shortcuts created successfully."

# 10. Disable Screen Locking and Blanking
log_checkpoint "Disabling screen locking and blanking..."
apt-get install -y dconf-cli || log_and_exit "Failed to install dconf-cli."
dconf write /org/gnome/desktop/screensaver/lock-enabled false || log_checkpoint "Failed to disable screen locking."
dconf write /org/gnome/desktop/session/idle-delay 0 || log_checkpoint "Failed to disable idle delay."
xset s off -dpms || log_checkpoint "Failed to disable display power management."

# 11. Clean Up
log_checkpoint "Cleaning up unnecessary files..."
apt-get autoremove -y || log_checkpoint "No packages to autoremove."

log_checkpoint "Provisioning script completed successfully."
