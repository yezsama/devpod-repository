#!/usr/bin/env bash
set -euo pipefail

echo "Activating feature 'cli-tools'"

# 解析 Feature 选项（导出为大写环境变量）
: "${SETASDEFAULTSHELL:=true}"

echo "Installing Git, Neovim and Zsh ..."
if command -v apt-get >/dev/null 2>&1; then
    # Debian/Ubuntu
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y --no-install-recommends git neovim zsh
elif command -v yum >/dev/null 2>&1; then
    # RHEL/Fedora
    yum install -y git neovim zsh
else
    echo "Unsupported package manager. Please install git, neovim and zsh manually." >&2
    exit 1
fi

# 如选项开启，则切换 shell
if [ "${SETASDEFAULTSHELL}" = "true" ]; then
    user="$(whoami)"
    if command -v chsh >/dev/null 2>&1; then
        echo "Setting zsh as default shell for ${user}"
        chsh -s "$(command -v zsh)" "${user}" || echo "chsh failed; continuing."
    fi
fi

echo "cli-tools feature installation complete."
