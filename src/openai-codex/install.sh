#!/usr/bin/env bash
set -e

############################################
# 0. 基本信息
############################################
ARCH="$(uname -m)"            # x86_64 / aarch64 …
DISTRO_FAMILY=""              # debian / rhel / alpine / arch …
PKG_MANAGER=""

echo "🔧 Installing OpenAI Codex CLI …"
echo "   Detected architecture: $ARCH"
echo "   Detecting base distro …"

#-------------------------------------------
# 1. 发行版与包管理器自动探测
#-------------------------------------------
if [ -f /etc/os-release ]; then
    . /etc/os-release
    case "${ID_LIKE:-$ID}" in
        debian*) DISTRO_FAMILY="debian"; PKG_MANAGER="apt-get";;
        rhel*|fedora*) DISTRO_FAMILY="rhel"; PKG_MANAGER="$(command -v dnf || command -v yum)";;
        alpine*) DISTRO_FAMILY="alpine"; PKG_MANAGER="apk";;
        arch*) DISTRO_FAMILY="arch"; PKG_MANAGER="pacman";;
        *) DISTRO_FAMILY="unknown";;
    esac
fi

echo "   Distro family: ${DISTRO_FAMILY:-unknown}"

install_pkgs() {
    local pkgs="$*"
    case "$PKG_MANAGER" in
        apt-get)  apt-get update -y && apt-get install -y --no-install-recommends $pkgs && rm -rf /var/lib/apt/lists/* ;;
        dnf)      dnf install -y $pkgs ;;
        yum)      yum install -y $pkgs ;;
        apk)      apk add --no-cache $pkgs ;;
        pacman)   pacman -Sy --noconfirm $pkgs ;;
        *)        echo "Warning: unknown distro, please install $pkgs manually";;
    esac
}

############################################
# 2. 检查系统前置工具是否存在
############################################
for pkg in git curl; do
    if ! command -v $pkg >/dev/null 2>&1; then
        echo "❌ Required package '$pkg' is not installed."
        exit 1
    fi
done

############################################
# 3. Node.js 已由依赖 Feature 提供，直接用 npm 安装 Codex
############################################
if ! command -v npm >/dev/null 2>&1; then
    echo "❌  Node.js / npm not found. Make sure the Node Feature is installed before openai-codex."
    exit 1
fi

npm install -g @openai/codex              # 官方推荐安装方式 :contentReference[oaicite:1]{index=1}

############################################
# 4. 可选：为当前用户补全 PATH（某些基础镜像 npm 全局路径不在 PATH）
############################################
if ! command -v codex >/dev/null 2>&1; then
    NPM_PREFIX=$(npm config get prefix)
    echo "export PATH=\"${NPM_PREFIX}/bin:\$PATH\"" >> /etc/profile.d/codex.sh
fi

echo "✅ OpenAI Codex CLI installation finished!"
