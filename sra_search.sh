#!/bin/bash
# NCBI SRA 数据检索自动化脚本
# 使用方法: ./sra_search.sh <物种关键词>
# 示例: ./sra_search.sh "O.meyeriana"

set -e

SPECIES="$1"

if [ -z "$SPECIES" ]; then
    echo "用法: $0 <物种关键词>"
    echo "示例: $0 O.meyeriana"
    exit 1
fi

echo "=============================================="
echo "NCBI SRA 数据检索"
echo "物种: $SPECIES"
echo "=============================================="

# 检查 agent-browser 是否可用
if ! command -v agent-browser &> /dev/null; then
    echo "正在安装 agent-browser..."
    npm install -g agent-browser
fi

echo "启动浏览器..."
agent-browser --headed open https://www.ncbi.nlm.nih.gov/sra/

echo "等待页面加载..."
agent-browser wait --load networkidle

echo "获取页面快照..."
agent-browser snapshot

echo ""
echo "=============================================="
echo "请手动完成以下步骤:"
echo "1. 选择数据库为 'SRA'"
echo "2. 输入检索式: ${SPECIES}[Organism]"
echo "3. 应用筛选器: Strategy=WGS, Source=GENOMIC"
echo "4. 选择 Run Selector 进入结果页"
echo "5. 记录符合条件的数据"
echo "=============================================="
