@echo off
setlocal enabledelayedexpansion

REM 同步 .claude 和 .gemini 配置到用户根目录

set "HOME_DIR=%USERPROFILE%"

REM 获取项目根目录（tools 上一级）
set "SCRIPT_DIR=%~dp0.."
for %%i in ("%SCRIPT_DIR%") do set "SCRIPT_DIR=%%~fi"

echo === 配置同步工具 ===
echo 源目录: %SCRIPT_DIR%
echo 目标目录: %HOME_DIR%
echo.

REM --- Claude Code ---
if exist "%SCRIPT_DIR%\.claude" (
    echo [Claude Code] 开始同步

    if not exist "%HOME_DIR%\.claude" mkdir "%HOME_DIR%\.claude"

    if exist "%HOME_DIR%\.claude\rules" rmdir /s /q "%HOME_DIR%\.claude\rules"
    if exist "%HOME_DIR%\.claude\skills" rmdir /s /q "%HOME_DIR%\.claude\skills"
    if exist "%HOME_DIR%\.claude\commands" rmdir /s /q "%HOME_DIR%\.claude\commands"
    if exist "%HOME_DIR%\.claude\templates" rmdir /s /q "%HOME_DIR%\.claude\templates"
    if exist "%HOME_DIR%\.claude\tasks" rmdir /s /q "%HOME_DIR%\.claude\tasks"

    echo   已清理旧配置目录

    if exist "%SCRIPT_DIR%\.claude\rules" xcopy /y /e /i /q "%SCRIPT_DIR%\.claude\rules" "%HOME_DIR%\.claude\rules"
    if exist "%SCRIPT_DIR%\.claude\skills" xcopy /y /e /i /q "%SCRIPT_DIR%\.claude\skills" "%HOME_DIR%\.claude\skills"
    if exist "%SCRIPT_DIR%\.claude\commands" xcopy /y /e /i /q "%SCRIPT_DIR%\.claude\commands" "%HOME_DIR%\.claude\commands"
    if exist "%SCRIPT_DIR%\.claude\templates" xcopy /y /e /i /q "%SCRIPT_DIR%\.claude\templates" "%HOME_DIR%\.claude\templates"
    if exist "%SCRIPT_DIR%\.claude\tasks" xcopy /y /e /i /q "%SCRIPT_DIR%\.claude\tasks" "%HOME_DIR%\.claude\tasks"

    if exist "%SCRIPT_DIR%\.claude\CLAUDE.md" copy /y "%SCRIPT_DIR%\.claude\CLAUDE.md" "%HOME_DIR%\.claude\" >nul

    echo   [√] rules/ skills/ commands/ templates/ tasks/ CLAUDE.md
) else (
    echo [Claude Code] 源目录不存在，跳过
)

echo.

REM --- Gemini CLI ---
if exist "%SCRIPT_DIR%\.gemini" (
    echo [Gemini CLI] 开始同步

    if not exist "%HOME_DIR%\.gemini" mkdir "%HOME_DIR%\.gemini"

    if exist "%HOME_DIR%\.gemini\commands" rmdir /s /q "%HOME_DIR%\.gemini\commands"
    if exist "%HOME_DIR%\.gemini\skills" rmdir /s /q "%HOME_DIR%\.gemini\skills"
    if exist "%HOME_DIR%\.gemini\rules" rmdir /s /q "%HOME_DIR%\.gemini\rules"

    echo   已清理旧配置目录

    if exist "%SCRIPT_DIR%\.gemini\commands" xcopy /y /e /i /q "%SCRIPT_DIR%\.gemini\commands" "%HOME_DIR%\.gemini\commands"
    if exist "%SCRIPT_DIR%\.gemini\skills" xcopy /y /e /i /q "%SCRIPT_DIR%\.gemini\skills" "%HOME_DIR%\.gemini\skills"
    if exist "%SCRIPT_DIR%\.gemini\rules" xcopy /y /e /i /q "%SCRIPT_DIR%\.gemini\rules" "%HOME_DIR%\.gemini\rules"

    if exist "%SCRIPT_DIR%\.gemini\GEMINI.md" copy /y "%SCRIPT_DIR%\.gemini\GEMINI.md" "%HOME_DIR%\.gemini\" >nul
    if exist "%SCRIPT_DIR%\.gemini\settings.json" copy /y "%SCRIPT_DIR%\.gemini\settings.json" "%HOME_DIR%\.gemini\" >nul

    echo   [√] commands/ skills/ rules/ GEMINI.md settings.json
) else (
    echo [Gemini CLI] 源目录不存在，跳过
)

echo.
echo === 同步完成 ===
pause
