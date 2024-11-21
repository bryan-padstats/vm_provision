#!/bin/bash

# Check if curl is installed, and install it if necessary
if ! command -v curl &> /dev/null; then
    echo "curl is not installed. Installing curl..."
    sudo apt-get update && sudo apt-get install curl -y
fi

# Step 1: Download the main provisioning script from GitHub
curl -fsSL https://raw.githubusercontent.com/bryan-padstats/vm_provision/main/provision_script.sh -o provision_script.sh

# Step 2: Make the script executable
chmod +x provision_script.sh

# Step 3: Execute the script
./provision_script.sh
