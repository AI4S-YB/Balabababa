#!/bin/bash
# NCBI SRA 数据检索自动化脚本 (PowerShell 版本)
# 使用方法: .\sra_search.ps1 -Species "<物种关键词>"
# 示例: .\sra_search.ps1 -Species "O.meyeriana"

param(
    [Parameter(Mandatory=$true)]
    [string]$Species
)

Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "NCBI SRA 数据检索" -ForegroundColor Cyan
Write-Host "物种: $Species" -ForegroundColor Cyan
Write-Host "==============================================" -ForegroundColor Cyan

# 检查 agent-browser 是否可用
$browserCmd = Get-Command agent-browser -ErrorAction SilentlyContinue
if (-not $browserCmd) {
    Write-Host "正在安装 agent-browser..." -ForegroundColor Yellow
    npm install -g agent-browser
}

Write-Host "启动浏览器..." -ForegroundColor Green
agent-browser --headed open https://www.ncbi.nlm.nih.gov/sra/

Write-Host "等待页面加载..." -ForegroundColor Green
Start-Sleep -Seconds 3

Write-Host "获取页面快照..." -ForegroundColor Green
agent-browser snapshot

Write-Host ""
Write-Host "==============================================" -ForegroundColor Cyan
Write-Host "请手动完成以下步骤:" -ForegroundColor Yellow
Write-Host "1. 选择数据库为 'SRA'"
Write-Host "2. 输入检索式: ${Species}[Organism]"
Write-Host "3. 应用筛选器: Strategy=WGS, Source=GENOMIC"
Write-Host "4. 选择 Run Selector 进入结果页"
Write-Host "5. 记录符合条件的数据"
Write-Host "==============================================" -ForegroundColor Cyan

# 打开浏览器后保持运行
Write-Host "按 Ctrl+C 退出" -ForegroundColor Gray
