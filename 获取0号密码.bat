@echo off
chcp 936 >nul
setlocal EnableExtensions
cd /d "%~dp0"

echo ================================================================
echo [重要] 0号账号的一次性密码只会在本窗口显示一次。
echo 请在生成后立即安全保存；脚本不会把明文密码写入文件。
echo ================================================================
echo.

where docker >nul 2>nul
if errorlevel 1 goto :docker_missing
docker info >nul 2>nul
if errorlevel 1 goto :docker_unavailable
docker compose config --quiet >nul 2>nul
if errorlevel 1 goto :config_failed

echo 正在检查并初始化生产0号developer账号，请稍候...
cmd.exe /d /v:on /c "chcp 65001>nul & docker compose run --rm zhitian-api python scripts/seed_prod_admin.py & set seed_code=!errorlevel! & chcp 936>nul & exit /b !seed_code!"
if errorlevel 1 goto :seed_rejected

echo.
echo [成功] 0号账号已创建。请确认已经保存上方显示的一次性密码。
pause
exit /b 0

:seed_rejected
echo.
echo [未生成新密码] 初始化脚本已明确拒绝本次操作，不是程序卡住。
echo 如果上方提示“生产默认账号0已存在”，说明0号已经初始化，脚本不会再次显示旧密码。
echo 如果提示存在真实developer或业务数据，请按上方安全检查原因处理，不要反复执行。
pause
exit /b 1

:docker_missing
echo [失败] 未找到 Docker 命令。请确认 Docker Desktop 已安装并加入 PATH。
goto :failed_end

:docker_unavailable
echo [失败] Docker Desktop 当前不可用，请先启动 Docker Desktop。
goto :failed_end

:config_failed
echo [失败] docker-compose.yml 校验失败，请检查部署目录和后端 .env 配置。

:failed_end
pause
exit /b 1
