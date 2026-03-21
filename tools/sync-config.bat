@echo off
setlocal enabledelayedexpansion

REM 同步 .claude、.gemini、.codex 和 .cursor 配置到用户根目录

set "HOME_DIR=%USERPROFILE%"
set "CODEX_MANAGED_START=<!-- cc-use-exp codex managed:start -->"
set "CODEX_MANAGED_END=<!-- cc-use-exp codex managed:end -->"
set "CODEX_PROFILE_START=# cc-use-exp codex profiles:start"
set "CODEX_PROFILE_END=# cc-use-exp codex profiles:end"

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

    REM --- Claude Code 插件检测 ---
    set "PLUGIN_JSON=%SCRIPT_DIR%\.claude\plugins.json"
    set "INSTALLED_JSON=%USERPROFILE%\.claude\plugins\installed_plugins.json"
    where claude >nul 2>nul
    if errorlevel 1 (
        echo.
        echo [Claude Code] 未检测到 claude 命令，跳过插件检测
        echo   安装方式: npm install -g @anthropic-ai/claude-code
    ) else (
        where python >nul 2>nul
        if errorlevel 1 (
            echo.
            echo [Claude Code] 未检测到 python，跳过插件检测
            echo   插件检测需要 python 解析 JSON，请安装后重试
            echo   下载: https://www.python.org/downloads/
        ) else if exist "!PLUGIN_JSON!" (
            echo.
            echo [Claude Code] 正在检测推荐插件...

            set "HAS_MISSING_PLUGIN=0"
            for /f "tokens=1,2,3 delims=|" %%a in ('python -c "import json,sys;r=json.load(open(sys.argv[1]));i={};[print(p['id']+'|'+p['name']+'|'+p['marketplace']) for p in r.get('recommendations',[]) if p['id']+'@'+p['marketplace'] not in (json.load(open(sys.argv[2])).get('plugins',{}) if __import__('os').path.exists(sys.argv[2]) else {})]" "!PLUGIN_JSON!" "!INSTALLED_JSON!" 2^>nul') do (
                if "!HAS_MISSING_PLUGIN!"=="0" (
                    echo 检测到以下推荐插件尚未安装：
                    set "HAS_MISSING_PLUGIN=1"
                )
                echo   - %%b ^(%%a^)
            )

            if "!HAS_MISSING_PLUGIN!"=="1" (
                echo.
                set /p "confirm=是否现在安装上述缺失的插件？[Y/n] "
                if /i "!confirm!"=="" set "confirm=Y"
                if /i "!confirm!"=="Y" (
                    for /f "tokens=1,2,3 delims=|" %%a in ('python -c "import json,sys;r=json.load(open(sys.argv[1]));i={};[print(p['id']+'|'+p['name']+'|'+p['marketplace']) for p in r.get('recommendations',[]) if p['id']+'@'+p['marketplace'] not in (json.load(open(sys.argv[2])).get('plugins',{}) if __import__('os').path.exists(sys.argv[2]) else {})]" "!PLUGIN_JSON!" "!INSTALLED_JSON!" 2^>nul') do (
                        echo 正在安装 %%b...
                        claude plugin install "%%a@%%c" || echo 警告: %%b 安装失败，请检查是否已登录（claude login）
                    )
                    echo [√] 插件安装完成
                ) else (
                    echo 已跳过插件安装。你可以之后手动安装。
                )
            ) else (
                echo [√] 所有推荐插件已安装
            )
        )
    )
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
    if exist "%HOME_DIR%\.gemini\policies" rmdir /s /q "%HOME_DIR%\.gemini\policies"

    echo   已清理旧配置目录

    if not exist "%HOME_DIR%\.gemini\policies" mkdir "%HOME_DIR%\.gemini\policies"

    if exist "%SCRIPT_DIR%\.gemini\commands" xcopy /y /e /i /q "%SCRIPT_DIR%\.gemini\commands" "%HOME_DIR%\.gemini\commands"
    if exist "%SCRIPT_DIR%\.gemini\skills" xcopy /y /e /i /q "%SCRIPT_DIR%\.gemini\skills" "%HOME_DIR%\.gemini\skills"
    if exist "%SCRIPT_DIR%\.gemini\rules" xcopy /y /e /i /q "%SCRIPT_DIR%\.gemini\rules" "%HOME_DIR%\.gemini\rules"

    if exist "%SCRIPT_DIR%\.gemini\GEMINI.md" copy /y "%SCRIPT_DIR%\.gemini\GEMINI.md" "%HOME_DIR%\.gemini\" >nul
    if exist "%SCRIPT_DIR%\.gemini\settings.json" copy /y "%SCRIPT_DIR%\.gemini\settings.json" "%HOME_DIR%\.gemini\" >nul
    
    if exist "%SCRIPT_DIR%\.gemini\policies" xcopy /y /e /i /q "%SCRIPT_DIR%\.gemini\policies" "%HOME_DIR%\.gemini\policies"

    REM 清理旧策略文件以防冲突
    if exist "%HOME_DIR%\.gemini\policy.toml" del /f /q "%HOME_DIR%\.gemini\policy.toml"
    if exist "%HOME_DIR%\.gemini\policy.json" move /y "%HOME_DIR%\.gemini\policy.json" "%HOME_DIR%\.gemini\policy.json.bak"

    echo   [√] commands/ skills/ rules/ policies/ GEMINI.md settings.json

    REM --- MCP 扩展检测 ---
    set "EXT_JSON=%SCRIPT_DIR%\.gemini\extensions.json"
    where gemini >nul 2>nul
    if errorlevel 1 (
        echo.
        echo [Gemini CLI] 未检测到 gemini 命令，跳过扩展检测
        echo   安装方式: brew install gemini-cli (详见 README^)
    ) else (
        where python >nul 2>nul
        if errorlevel 1 (
            echo.
            echo [Gemini CLI] 未检测到 python，跳过扩展检测
            echo   扩展检测需要 python 解析 JSON，请安装后重试
            echo   下载: https://www.python.org/downloads/
        ) else if exist "!EXT_JSON!" (
            echo.
            echo [Gemini CLI] 正在检测推荐扩展...

            REM 获取已安装扩展列表（gemini extensions list 输出走 stderr）
            set "INSTALLED_EXTS="
            for /f "delims=" %%a in ('gemini extensions list 2^>^&1') do (
                set "INSTALLED_EXTS=!INSTALLED_EXTS! %%a"
            )

            REM 使用 python 解析 JSON 检查缺失
            set "HAS_MISSING=0"
            for /f "tokens=1,2,3 delims=|" %%a in ('python -c "import json,sys,re;data=json.load(open(sys.argv[1]));installed=sys.argv[2];[print(e['id']+'|'+e['name']+'|'+e['url']) for e in data.get('recommendations',[]) if not re.search(r'\b'+re.escape(e['id'])+r'\b',installed)]" "!EXT_JSON!" "!INSTALLED_EXTS!" 2^>nul') do (
                if "!HAS_MISSING!"=="0" (
                    echo 检测到以下推荐扩展尚未安装：
                    set "HAS_MISSING=1"
                )
                echo   - %%b ^(%%a^)
            )

            if "!HAS_MISSING!"=="1" (
                echo.
                set /p "confirm=是否现在安装上述缺失的扩展？[Y/n] "
                if /i "!confirm!"=="" set "confirm=Y"
                if /i "!confirm!"=="Y" (
                    for /f "tokens=1,2,3 delims=|" %%a in ('python -c "import json,sys,re;data=json.load(open(sys.argv[1]));installed=sys.argv[2];[print(e['id']+'|'+e['name']+'|'+e['url']) for e in data.get('recommendations',[]) if not re.search(r'\b'+re.escape(e['id'])+r'\b',installed)]" "!EXT_JSON!" "!INSTALLED_EXTS!" 2^>nul') do (
                        echo 正在安装 %%b...
                        gemini extensions install "%%c" || echo 警告: %%b 安装失败，请检查是否已登录（gemini auth login）
                    )
                    echo [√] 扩展安装完成
                ) else (
                    echo 已跳过扩展安装。你可以之后手动安装。
                )
            ) else (
                echo [√] 所有推荐扩展已安装
            )
        )
    )
) else (
    echo [Gemini CLI] 源目录不存在，跳过
)

echo.
REM --- Codex ---
if exist "%SCRIPT_DIR%\.codex" (
    echo [Codex] 开始同步

    if not exist "%HOME_DIR%\.codex" mkdir "%HOME_DIR%\.codex"
    if not exist "%HOME_DIR%\.codex\rules" mkdir "%HOME_DIR%\.codex\rules"
    if not exist "%HOME_DIR%\.agents" mkdir "%HOME_DIR%\.agents"
    if not exist "%HOME_DIR%\.agents\skills" mkdir "%HOME_DIR%\.agents\skills"

    set "CODEX_RULES_SYNCED=0"
    set "CODEX_SKILLS_SYNCED=0"
    set "CODEX_AGENTS_SRC=%SCRIPT_DIR%\.codex\global\AGENTS.md"
    set "CODEX_AGENTS_DST=%HOME_DIR%\.codex\AGENTS.md"
    set "CODEX_RULES_SRC=%SCRIPT_DIR%\.codex\global\rules"
    set "CODEX_SKILLS_SRC=%SCRIPT_DIR%\.codex\skills"
    set "CODEX_PROFILES_SRC=%SCRIPT_DIR%\.codex\profiles"
    set "CODEX_CONFIG_DST=%HOME_DIR%\.codex\config.toml"
    set "RULES_MANIFEST=%HOME_DIR%\.codex\rules\.cc-use-exp-managed"
    set "SKILLS_MANIFEST=%HOME_DIR%\.agents\skills\.cc-use-exp-managed"

    if exist "!CODEX_AGENTS_SRC!" (
        powershell -NoProfile -Command "$start=$env:CODEX_MANAGED_START; $end=$env:CODEX_MANAGED_END; $srcPath=$env:CODEX_AGENTS_SRC; $dstPath=$env:CODEX_AGENTS_DST; $src=[IO.File]::ReadAllText($srcPath); $existing=if(Test-Path $dstPath){[IO.File]::ReadAllText($dstPath)} else {''}; $pattern='(?s)\r?\n?'+[regex]::Escape($start)+'.*?'+[regex]::Escape($end)+'\r?\n?'; $clean=[regex]::Replace($existing,$pattern,''); $clean=$clean.TrimEnd(); if($clean.Length -gt 0){$clean += [Environment]::NewLine + [Environment]::NewLine}; $content=$clean + $start + [Environment]::NewLine + $src.TrimEnd() + [Environment]::NewLine + $end + [Environment]::NewLine; [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($dstPath)) ^| Out-Null; [IO.File]::WriteAllText($dstPath,$content,[Text.UTF8Encoding]::new($false))" >nul
        if errorlevel 1 (
            echo   警告: AGENTS 同步失败，请检查 powershell 是否可用
        ) else (
            echo   [√] 已合并 ~/.codex/AGENTS.md 受管区块
        )
    ) else (
        echo   未找到 global\AGENTS.md，跳过 AGENTS 同步
    )

    if exist "!RULES_MANIFEST!" (
        for /f "usebackq delims=" %%f in ("!RULES_MANIFEST!") do (
            if exist "%HOME_DIR%\.codex\rules\%%f" del /f /q "%HOME_DIR%\.codex\rules\%%f"
        )
        del /f /q "!RULES_MANIFEST!" >nul 2>nul
    )
    if exist "!CODEX_RULES_SRC!" (
        for /f "delims=" %%f in ('dir /b /a-d "!CODEX_RULES_SRC!\*.rules" 2^>nul') do (
            copy /y "!CODEX_RULES_SRC!\%%f" "%HOME_DIR%\.codex\rules\%%f" >nul
            >> "!RULES_MANIFEST!" echo %%f
            set /a CODEX_RULES_SYNCED+=1
        )
    )

    if exist "!SKILLS_MANIFEST!" (
        for /f "usebackq delims=" %%d in ("!SKILLS_MANIFEST!") do (
            if exist "%HOME_DIR%\.agents\skills\%%d" rmdir /s /q "%HOME_DIR%\.agents\skills\%%d"
        )
        del /f /q "!SKILLS_MANIFEST!" >nul 2>nul
    )
    if exist "!CODEX_SKILLS_SRC!" (
        for /f "delims=" %%d in ('dir /b /ad "!CODEX_SKILLS_SRC!" 2^>nul') do (
            xcopy /y /e /i /q "!CODEX_SKILLS_SRC!\%%d" "%HOME_DIR%\.agents\skills\%%d" >nul
            >> "!SKILLS_MANIFEST!" echo %%d
            set /a CODEX_SKILLS_SYNCED+=1
        )
    )

    set "CODEX_PROFILES_SYNCED=0"
    if exist "!CODEX_PROFILES_SRC!" (
        for /f %%n in ('dir /b /a-d "!CODEX_PROFILES_SRC!\*.toml" 2^>nul ^| find /c /v ""') do set "CODEX_PROFILES_SYNCED=%%n"
        powershell -NoProfile -Command "$start=$env:CODEX_PROFILE_START; $end=$env:CODEX_PROFILE_END; $srcDir=$env:CODEX_PROFILES_SRC; $dstPath=$env:CODEX_CONFIG_DST; $existing=if(Test-Path $dstPath){[IO.File]::ReadAllText($dstPath)} else {''}; $pattern='(?s)\r?\n?'+[regex]::Escape($start)+'.*?'+[regex]::Escape($end)+'\r?\n?'; $clean=[regex]::Replace($existing,$pattern,''); $parts=Get-ChildItem -Path $srcDir -Filter '*.toml' | Sort-Object Name | ForEach-Object { [IO.File]::ReadAllText($_.FullName).TrimEnd() }; $body='# Managed Codex profiles from cc-use-exp'+[Environment]::NewLine+'# Use with: codex -p cc-fast-api | cc-balanced | cc-deep'+[Environment]::NewLine+[Environment]::NewLine+($parts -join ([Environment]::NewLine+[Environment]::NewLine)); $clean=$clean.TrimEnd(); if($clean.Length -gt 0){$clean += [Environment]::NewLine + [Environment]::NewLine}; $content=$clean + $start + [Environment]::NewLine + $body.TrimEnd() + [Environment]::NewLine + $end + [Environment]::NewLine; [IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($dstPath)) ^| Out-Null; [IO.File]::WriteAllText($dstPath,$content,[Text.UTF8Encoding]::new($false))" >nul
        if errorlevel 1 (
            echo   警告: profiles 同步失败，请检查 powershell 是否可用
        ) else (
            echo   [√] profiles: !CODEX_PROFILES_SYNCED! 个，已合并到 ~/.codex/config.toml
        )
    ) else (
        echo   未找到 profiles\，跳过 profile 同步
    )

    echo   [√] rules: !CODEX_RULES_SYNCED! 个，同步到 ~/.codex/rules/
    echo   [√] skills: !CODEX_SKILLS_SYNCED! 个，同步到 ~/.agents/skills/
    echo   已保留 ~/.codex 运行态文件（auth/history/logs/cache）
) else (
    echo [Codex] 源目录不存在，跳过
)

echo.
REM --- Cursor ---
if exist "%SCRIPT_DIR%\.cursor" (
    echo [Cursor] 开始同步

    if not exist "%HOME_DIR%\.cursor" mkdir "%HOME_DIR%\.cursor"
    if not exist "%HOME_DIR%\.cursor\rules" mkdir "%HOME_DIR%\.cursor\rules"
    if not exist "%HOME_DIR%\.cursor\skills" mkdir "%HOME_DIR%\.cursor\skills"
    if not exist "%HOME_DIR%\.cursor\templates" mkdir "%HOME_DIR%\.cursor\templates"

    set "CURSOR_RULES_SRC=%SCRIPT_DIR%\.cursor\rules"
    set "CURSOR_SKILLS_SRC=%SCRIPT_DIR%\.cursor\skills"
    set "CURSOR_COMMANDS_SRC=%SCRIPT_DIR%\.cursor\commands"
    set "CURSOR_TEMPLATES_SRC=%SCRIPT_DIR%\.cursor\templates"
    set "CURSOR_RULES_MANIFEST=%HOME_DIR%\.cursor\rules\.cc-use-exp-managed"
    set "CURSOR_SKILLS_MANIFEST=%HOME_DIR%\.cursor\skills\.cc-use-exp-managed"
    set "CURSOR_RULES_SYNCED=0"
    set "CURSOR_SKILLS_SYNCED=0"
    set "CURSOR_COMMANDS_SYNCED=0"

    REM rules
    if exist "!CURSOR_RULES_MANIFEST!" (
        for /f "usebackq delims=" %%f in ("!CURSOR_RULES_MANIFEST!") do (
            if exist "%HOME_DIR%\.cursor\rules\%%f" del /f /q "%HOME_DIR%\.cursor\rules\%%f"
        )
        del /f /q "!CURSOR_RULES_MANIFEST!" >nul 2>nul
    )
    if exist "!CURSOR_RULES_SRC!" (
        for /f "delims=" %%f in ('dir /b /a-d "!CURSOR_RULES_SRC!\*.mdc" "!CURSOR_RULES_SRC!\*.md" 2^>nul') do (
            copy /y "!CURSOR_RULES_SRC!\%%f" "%HOME_DIR%\.cursor\rules\%%f" >nul
            >> "!CURSOR_RULES_MANIFEST!" echo %%f
            set /a CURSOR_RULES_SYNCED+=1
        )
    )

    REM skills（目录） → ~/.cursor/skills/
    if exist "!CURSOR_SKILLS_MANIFEST!" (
        for /f "usebackq delims=" %%d in ("!CURSOR_SKILLS_MANIFEST!") do (
            if exist "%HOME_DIR%\.cursor\skills\%%d" rmdir /s /q "%HOME_DIR%\.cursor\skills\%%d"
        )
        del /f /q "!CURSOR_SKILLS_MANIFEST!" >nul 2>nul
    )
    if exist "!CURSOR_SKILLS_SRC!" (
        for /f "delims=" %%d in ('dir /b /ad "!CURSOR_SKILLS_SRC!" 2^>nul') do (
            xcopy /y /e /i /q "!CURSOR_SKILLS_SRC!\%%d" "%HOME_DIR%\.cursor\skills\%%d" >nul
            >> "!CURSOR_SKILLS_MANIFEST!" echo %%d
            set /a CURSOR_SKILLS_SYNCED+=1
        )
    )

    REM commands（.md 文件） → ~/.cursor/skills/{name}/SKILL.md
    if exist "!CURSOR_COMMANDS_SRC!" (
        for /f "delims=" %%f in ('dir /b /a-d "!CURSOR_COMMANDS_SRC!\*.md" 2^>nul') do (
            set "CMD_NAME=%%~nf"
            if not exist "%HOME_DIR%\.cursor\skills\!CMD_NAME!" mkdir "%HOME_DIR%\.cursor\skills\!CMD_NAME!"
            copy /y "!CURSOR_COMMANDS_SRC!\%%f" "%HOME_DIR%\.cursor\skills\!CMD_NAME!\SKILL.md" >nul
            >> "!CURSOR_SKILLS_MANIFEST!" echo !CMD_NAME!
            set /a CURSOR_COMMANDS_SYNCED+=1
        )
    )

    REM templates
    if exist "!CURSOR_TEMPLATES_SRC!" (
        for /f "delims=" %%d in ('dir /b /ad "!CURSOR_TEMPLATES_SRC!" 2^>nul') do (
            if not exist "%HOME_DIR%\.cursor\templates\%%d" mkdir "%HOME_DIR%\.cursor\templates\%%d"
            xcopy /y /e /i /q "!CURSOR_TEMPLATES_SRC!\%%d" "%HOME_DIR%\.cursor\templates\%%d" >nul
        )
    )

    echo   [√] rules: !CURSOR_RULES_SYNCED! 个，同步到 ~/.cursor/rules/
    echo   [√] skills: !CURSOR_SKILLS_SYNCED! 个，同步到 ~/.cursor/skills/
    echo   [√] commands: !CURSOR_COMMANDS_SYNCED! 个，同步到 ~/.cursor/skills/
    echo   [√] templates: 同步到 ~/.cursor/templates/
    echo   已保留 ~/.cursor 运行态文件（settings/extensions/cache）
) else (
    echo [Cursor] 源目录不存在，跳过
)

echo.
echo === 同步完成 ===
pause
