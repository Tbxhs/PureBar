#!/bin/bash
set -e

echo "🔄 准备重置仓库..."

# 1. 备份当前分支名
BRANCH=$(git branch --show-current)
REMOTE_URL=$(git remote get-url origin)

echo "📦 当前分支: $BRANCH"
echo "🔗 远程地址: $REMOTE_URL"

# 2. 删除.git目录
echo "🗑️  删除旧的git历史..."
rm -rf .git

# 3. 重新初始化
echo "🆕 重新初始化仓库..."
git init
git branch -M $BRANCH

# 4. 添加远程仓库
echo "🔗 添加远程仓库..."
git remote add origin $REMOTE_URL

# 5. 添加所有文件（.gitignore会自动过滤）
echo "📝 添加所有文件..."
git add -A

# 6. 创建初始提交
echo "💾 创建初始提交..."
git commit -m "Initial commit

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"

echo "✅ 仓库重置完成！"
