#!/bin/bash
#-------------------------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See https://go.microsoft.com/fwlink/?linkid=2090316 for license information.
#-------------------------------------------------------------------------------------------------------------
#
# Docs: https://github.com/microsoft/vscode-dev-containers/tree/main/script-library/docs/node.md
# Maintainer: The Dev Container spec maintainers

set -e

# Clean up
rm -rf /var/lib/apt/lists/*

# Get options
VERSION=${VERSION:-"lts"}
NVM_VERSION=${NVMVERSION:-"0.39.3"}
INSTALL_YARN=${INSTALLYARN:-"true"}
YARN_VERSION=${YARNVERSION:-"latest"}
INSTALL_PNPM=${INSTALLPNPM:-"false"}
GLOBAL_PACKAGES=${GLOBALPACKAGES:-""}

# Ensure we're running as root
if [ "$(id -u)" -ne 0 ]; then
    echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

# Determine the appropriate non-root user
if [ "${USERNAME}" = "" ]; then
    USERNAME=automatic
fi

if [ "${USERNAME}" = "automatic" ]; then
    USERNAME=""
    POSSIBLE_USERS=("vscode" "node" "codespace" "$(awk -v val=1000 -F ":" '$3==val{print $1}' /etc/passwd)")
    for CURRENT_USER in "${POSSIBLE_USERS[@]}"; do
        if id -u "${CURRENT_USER}" > /dev/null 2>&1; then
            USERNAME=${CURRENT_USER}
            break
        fi
    done
    if [ "${USERNAME}" = "" ]; then
        USERNAME=root
    fi
elif [ "${USERNAME}" = "none" ] || ! id -u ${USERNAME} > /dev/null 2>&1; then
    USERNAME=root
fi

# Function to call apt-get if needed
apt_get_update_if_needed()
{
    if [ ! -d "/var/lib/apt/lists" ] || [ "$(ls /var/lib/apt/lists/ | wc -l)" = "0" ]; then
        echo "Running apt-get update..."
        apt-get update
    else
        echo "Skipping apt-get update."
    fi
}

# Checks if packages are installed and installs them if not
check_packages() {
    if ! dpkg -s "$@" > /dev/null 2>&1; then
        apt_get_update_if_needed
        apt-get -y install --no-install-recommends "$@"
    fi
}

# Function to get architecture
get_architecture() {
    local architecture=""
    case $(uname -m) in
        x86_64) architecture="x64";;
        aarch64 | armv8*) architecture="arm64";;
        aarch32 | armv7* | armvhf*) architecture="armv7l";;
        i?86) architecture="x86";;
        *) architecture="";;
    esac
    echo $architecture
}

# Function to detect Linux distribution
detect_distro() {
    local distro=""
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        distro=$ID
    elif [ -f /etc/redhat-release ]; then
        distro="rhel"
    elif [ -f /etc/debian_version ]; then
        distro="debian"
    fi
    echo $distro
}

# Function to install dependencies based on distro
install_dependencies() {
    local distro=$(detect_distro)
    
    case $distro in
        ubuntu|debian)
            check_packages curl ca-certificates gnupg2 dirmngr
            ;;
        centos|rhel|fedora)
            if command -v yum > /dev/null 2>&1; then
                yum install -y curl ca-certificates gnupg2
            elif command -v dnf > /dev/null 2>&1; then
                dnf install -y curl ca-certificates gnupg2
            fi
            ;;
        alpine)
            apk add --no-cache curl ca-certificates gnupg
            ;;
        arch)
            pacman -Sy --noconfirm curl ca-certificates gnupg
            ;;
        *)
            echo "Unsupported distribution: $distro"
            exit 1
            ;;
    esac
}

# Ensure apt is in non-interactive to avoid prompts
export DEBIAN_FRONTEND=noninteractive

# Install dependencies
echo "Installing dependencies..."
install_dependencies

# Get architecture for NVM/Node installation
ARCHITECTURE=$(get_architecture)
if [ -z "$ARCHITECTURE" ]; then
    echo "Unsupported architecture: $(uname -m)"
    exit 1
fi

# Create nvm group and add user
if ! cat /etc/group | grep -e "^nvm:" > /dev/null 2>&1; then
    groupadd -r nvm
fi
usermod -a -G nvm ${USERNAME}

# Install NVM
umask 0002
if [ ! -d "/usr/local/share/nvm" ]; then
    mkdir -p /usr/local/share/nvm
    chown :nvm /usr/local/share/nvm
    chmod g+s /usr/local/share/nvm
fi

# Download and install NVM
echo "Downloading NVM version ${NVM_VERSION}..."
NVM_INSTALL_SCRIPT="https://raw.githubusercontent.com/nvm-sh/nvm/v${NVM_VERSION}/install.sh"
curl -so- ${NVM_INSTALL_SCRIPT} | NVM_DIR=/usr/local/share/nvm bash

# Set up NVM environment
export NVM_DIR=/usr/local/share/nvm
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# Install Node.js
echo "Installing Node.js version ${VERSION}..."
if [ "${VERSION}" = "latest" ]; then
    nvm install node
elif [ "${VERSION}" = "lts" ]; then
    nvm install --lts
else
    nvm install ${VERSION}
fi

# Set default version
if [ "${VERSION}" = "latest" ]; then
    nvm alias default node
elif [ "${VERSION}" = "lts" ]; then
    nvm alias default lts/*
else
    nvm alias default ${VERSION}
fi

nvm use default

# Create symlink for system-wide access
mkdir -p /usr/local/share/nvm/current
ln -sf /usr/local/share/nvm/versions/node/$(nvm version default)/* /usr/local/share/nvm/current/

# Install Yarn if requested
if [ "${INSTALL_YARN}" = "true" ]; then
    echo "Installing Yarn..."
    if [ "${YARN_VERSION}" = "latest" ] || [ "${YARN_VERSION}" = "stable" ]; then
        npm install -g yarn
    else
        npm install -g yarn@${YARN_VERSION}
    fi
fi

# Install pnpm if requested
if [ "${INSTALL_PNPM}" = "true" ]; then
    echo "Installing pnpm..."
    npm install -g pnpm
fi

# Create profile script for NVM
tee /etc/profile.d/00-nvm.sh > /dev/null \
<< 'EOF'
export NVM_DIR="/usr/local/share/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
EOF

# Set permissions
chmod +x /etc/profile.d/00-nvm.sh
chown -R :nvm /usr/local/share/nvm
find /usr/local/share/nvm -type d -exec chmod g+s {} \;
find /usr/local/share/nvm -type d -exec chmod g+w {} \;
find /usr/local/share/nvm -type f -exec chmod g+w {} \;

# Clean up
if command -v apt-get > /dev/null 2>&1; then
    apt-get autoremove -y
    apt-get clean -y
    rm -rf /var/lib/apt/lists/*
fi

# Display installed versions
echo ""
echo "Node.js installation completed!"
echo "Node.js version: $(node --version)"
echo "npm version: $(npm --version)"

if [ "${INSTALL_YARN}" = "true" ]; then
    echo "Yarn version: $(yarn --version)"
fi

if [ "${INSTALL_PNPM}" = "true" ]; then
    echo "pnpm version: $(pnpm --version)"
fi

echo ""
echo "To use NVM in new shells, run:"
echo "source /etc/profile.d/00-nvm.sh"