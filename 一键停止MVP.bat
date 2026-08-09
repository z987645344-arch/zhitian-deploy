@echo off
chcp 936 >nul
setlocal EnableExtensions
cd /d "%~dp0"

echo [知天 MVP] 正在停止服务...
where docker >nul 2>nul
if errorlevel 1 goto :docker_missing

docker compose down
if errorlevel 1 goto :stop_failed

echo.
echo [成功] 知天 MVP 服务已停止。
echo 业务数据仍保留在 Docker 具名卷 zhitian-mvp-data 中，下次启动会自动恢复。
pause
exit /b 0

:docker_missing
echo.
echo [失败] 未找到 Docker 命令。请确认 Docker Desktop 已安装并加入 PATH。
pause
exit /b 1

:stop_failed
echo.
echo [失败] 服务停止未完成，请查看上方 Docker 错误信息。
echo 未执行 docker compose down -v，本脚本不会主动删除具名卷数据。
pause
exit /b 1
