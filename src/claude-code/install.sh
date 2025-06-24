#!/usr/bin/env bash
set -e

echo "🔧 Installing Claude Code CLI …"

############################################
# 1. Node.js 已由依赖 Feature 提供，直接用 npm 安装 Claude Code
############################################
if ! command -v npm >/dev/null 2>&1; then
    echo "❌  Node.js / npm not found. Make sure the Node Feature is installed before claude-code."
    exit 1
fi

npm install -g @anthropic-ai/claude-code

############################################
# 2. 可选：为当前用户补全 PATH（某些基础镜像 npm 全局路径不在 PATH）
############################################
if ! command -v claude >/dev/null 2>&1; then
    NPM_PREFIX=$(npm config get prefix)
    echo "export PATH=\"${NPM_PREFIX}/bin:\$PATH\"" >> /etc/profile.d/claude-code.sh
fi

echo "✅ Claude Code CLI installation finished!"