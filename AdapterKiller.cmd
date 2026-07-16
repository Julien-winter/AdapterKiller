@echo off
chcp 1252 >nul
title Adapter Killer v3.0
cd /d "%~dp0"
powershell -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ""%~dp0AdapterKiller.ps1""' -Verb RunAs"
exit
