@echo off
setlocal enabledelayedexpansion

REM 同步 .claude 和 .gemini 配置到用户根目录

REM 获取用户根目录
set "HOME_DIR=%USERPROFILE%"

REM 当前脚本所在目录
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"

REM 需要同步的目录
set "SYNC_DIRS=.claude .gemini"

REM 全局覆盖策略（空表示每次询问，yes表示全部覆盖，no表示全部跳过）
set "OVERWRITE_ALL="

echo === 配置同步工具 ===
echo 源目录: %SCRIPT_DIR%
echo 目标目录: %HOME_DIR%
echo.

for %%d in (%SYNC_DIRS%) do (
    call :sync_directory "%%d"
)

echo.
echo === 同步完成 ===
pause
goto :eof

:sync_directory
    set "dir_name=%~1"
    set "src_dir=%SCRIPT_DIR%\%dir_name%"
    set "dest_dir=%HOME_DIR%\%dir_name%"

    if not exist "%src_dir%" (
        echo [警告] 源目录不存在，跳过: %src_dir%
        goto :eof
    )

    echo.
    echo [开始同步] %dir_name%

    REM 创建目标目录
    if not exist "%dest_dir%" (
        mkdir "%dest_dir%"
    )

    REM 复制所有文件（使用 xcopy）
    for /r "%src_dir%" %%f in (*) do (
        set "file=%%f"
        set "rel_path=!file:%src_dir%\=!"
        set "dest_file=%dest_dir%\!rel_path!"

        REM 创建目标子目录
        for %%p in ("!dest_file!") do (
            set "dest_subdir=%%~dpp"
            if not exist "!dest_subdir!" (
                mkdir "!dest_subdir!"
            )
        )

        REM 检查文件是否存在
        if exist "!dest_file!" (
            call :confirm_overwrite "!dest_file!" "%%f"
            if errorlevel 1 (
                echo [×] 已跳过: !dest_file!
            ) else (
                copy /y "%%f" "!dest_file!" >nul
                echo [√] 已覆盖: !dest_file!
            )
        ) else (
            copy "%%f" "!dest_file!" >nul
            echo [√] 已复制: !dest_file!
        )
    )
    goto :eof

:confirm_overwrite
    set "dest=%~1"
    set "src=%~2"

    REM 如果已设置全局策略，直接返回
    if "!OVERWRITE_ALL!"=="yes" (
        exit /b 0
    )
    if "!OVERWRITE_ALL!"=="no" (
        exit /b 1
    )

    REM 询问用户
    echo [!] 文件已存在: %dest%
    set /p "response=是否覆盖? [y/N/a(全部覆盖)/s(全部跳过)]: "

    REM 处理用户输入
    if /i "!response!"=="a" (
        set "OVERWRITE_ALL=yes"
        echo [√] 后续文件将全部覆盖
        exit /b 0
    )
    if /i "!response!"=="s" (
        set "OVERWRITE_ALL=no"
        echo [√] 后续文件将全部跳过
        exit /b 1
    )
    if /i "!response!"=="y" (
        exit /b 0
    )

    REM 默认不覆盖（空输入或其他输入）
    exit /b 1
