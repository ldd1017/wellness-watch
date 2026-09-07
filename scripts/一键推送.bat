@echo off
:: scripts/一键推送.bat
:: 双击这个文件即可启动 PowerShell 脚本
:: 等价于右键 → 用 PowerShell 运行

chcp 65001 >nul
title WellnessWatch 一键推送

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0一键推送.ps1"

pause
