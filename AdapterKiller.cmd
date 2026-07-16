@echo off
chcp 1252 >nul
title Adapter Killer v3.0
cd /d "%~dp0"

echo ==========================================
echo         ADAPTER KILLER v3.0
echo ==========================================
echo.
echo  Launches PowerShell script with admin rights.
echo  The menu will appear in the PowerShell window.
echo.
pause

powershell -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ""%~dp0AdapterKiller.ps1""' -Verb RunAs"
exit
