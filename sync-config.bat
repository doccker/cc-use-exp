@echo off
setlocal enabledelayedexpansion

REM 同步 .claude 和 .gemini 配置到用户根目录

set "HOME_DIR=%USERPROFILE%"
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

echo === 配置同步工具 ===
echo 源目录: %SCRIPT_DIR%
echo 目标目录: %HOME_DIR%
echo.

REM --- Claude Code ---
if exist "%SCRIPT_DIR%\.claude" (
    echo [Claude Code] 开始同步

    REM 确保目标目录存在
    if not exist "%HOME_DIR%\.claude" mkdir "%HOME_DIR%\.claude"

    REM 删除旧配置目录（保留历史记录、projects 等）
    if exist "%HOME_DIR%\.claude\rules" rmdir /s /q "%HOME_DIR%\.claude\rules"
    if exist "%HOME_DIR%\.claude\skills" rmdir /s /q "%HOME_DIR%\.claude\skills"
    if exist "%HOME_DIR%\.claude\commands" rmdir /s /q "%HOME_DIR%\.claude\commands"
    if exist "%HOME_DIR%\.claude\templates" rmdir /s /q "%HOME_DIR%\.claude\templates"
    if exist "%HOME_DIR%\.claude\tasks" rmdir /s /q "%HOME_DIR%\.claude\tasks"
    echo   已清理旧配置目录

    REM 复制配置目录
    xcopy /e /i /q "%SCRIPT_DIR%\.claude\rules" "%HOME_DIR%\.claude\rules"
    xcopy /e /i /q "%SCRIPT_DIR%\.claude\skills" "%HOME_DIR%\.claude\skills"
    xcopy /e /i /q "%SCRIPT_DIR%\.claude\commands" "%HOME_DIR%\.claude\commands"
    xcopy /e /i /q "%SCRIPT_DIR%\.claude\templates" "%HOME_DIR%\.claude\templates"
    xcopy /e /i /q "%SCRIPT_DIR%\.claude\tasks" "%HOME_DIR%\.claude\tasks"
    copy /y "%SCRIPT_DIR%\.claude\CLAUDE.md" "%HOME_DIR%\.claude\CLAUDE.md" >nul

    echo   [√] rules/ skills/ commands/ templates/ tasks/ CLAUDE.md
) else (
    echo [Claude Code] 源目录不存在，跳过
)

echo.

REM --- Gemini CLI ---
if exist "%SCRIPT_DIR%\.gemini" (
    echo [Gemini CLI] 开始同步

    REM 确保目标目录存在
    if not exist "%HOME_DIR%\.gemini" mkdir "%HOME_DIR%\.gemini"

    REM 删除旧配置目录（保留认证信息）
    if exist "%HOME_DIR%\.gemini\commands" rmdir /s /q "%HOME_DIR%\.gemini\commands"
    echo   已清理旧配置目录

    REM 复制配置
    xcopy /e /i /q "%SCRIPT_DIR%\.gemini\commands" "%HOME_DIR%\.gemini\commands"
    copy /y "%SCRIPT_DIR%\.gemini\GEMINI.md" "%HOME_DIR%\.gemini\GEMINI.md" >nul
    copy /y "%SCRIPT_DIR%\.gemini\settings.json" "%HOME_DIR%\.gemini\settings.json" >nul

    echo   [√] commands/ GEMINI.md settings.json
) else (
    echo [Gemini CLI] 源目录不存在，跳过
)

echo.
echo === 同步完成 ===
pause
