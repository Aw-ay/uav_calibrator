@echo off
set PYTHONUTF8=1
cd /d "%~dp0"
python -X utf8 toolserify_all.py
exit /b %errorlevel%
