@echo off
chcp 936 >nul
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"

echo [知天 MVP] 正在启动服务，请稍候...
call :check_docker
if errorlevel 1 goto :start_failed

docker compose up -d
if errorlevel 1 goto :start_failed

echo.
echo 服务启动命令已完成，正在等待健康检查（最长约 120 秒）...
set "ALL_READY=0"
for /L %%I in (1,1,40) do (
    call :all_services_healthy
    if not errorlevel 1 (
        set "ALL_READY=1"
        goto :health_report
    )
    ping 127.0.0.1 -n 4 >nul
)

:health_report
echo.
echo ==================== 服务健康检查 ====================
call :print_health
set "HEALTH_RESULT=!errorlevel!"
echo ======================================================

if "!ALL_READY!"=="1" if "!HEALTH_RESULT!"=="0" goto :start_success

echo.
echo [失败] 部分服务未在等待时间内进入健康状态。
echo 请运行 docker compose ps 查看状态，并用 docker compose logs 服务名 排查日志。
pause
exit /b 1

:start_success
echo.
echo [成功] 知天 MVP 全部服务已健康运行。
echo 管理后台请访问 http://localhost
echo Flutter客户端配置后端地址请填 http://localhost/api（不要加:8000端口）
pause
exit /b 0

:start_failed
echo.
echo [失败] 知天 MVP 启动失败，请查看上方 Docker 错误信息。
pause
exit /b 1

:check_docker
where docker >nul 2>nul
if errorlevel 1 (
    echo [失败] 未找到 Docker 命令。请确认 Docker Desktop 已安装并加入 PATH。
    exit /b 1
)
docker info >nul 2>nul
if errorlevel 1 (
    echo [失败] Docker Desktop 当前不可用，请先启动 Docker Desktop。
    exit /b 1
)
docker compose config --quiet >nul 2>nul
if errorlevel 1 (
    echo [失败] docker-compose.yml 校验失败，请检查部署目录和后端 .env 配置。
    exit /b 1
)
exit /b 0

:all_services_healthy
set /a "EXPECTED_SERVICES=0, HEALTHY_SERVICES=0"
for /f "delims=" %%S in ('docker compose config --services 2^>nul') do set /a EXPECTED_SERVICES+=1
for /f "tokens=1-3 delims=|" %%A in ('docker compose ps --format "{{.Service}}|{{.State}}|{{.Health}}" 2^>nul') do (
    if /I "%%B"=="running" (
        if /I "%%C"=="healthy" set /a HEALTHY_SERVICES+=1
        if "%%C"=="" set /a HEALTHY_SERVICES+=1
    )
)
if !EXPECTED_SERVICES! GTR 0 if !HEALTHY_SERVICES! EQU !EXPECTED_SERVICES! exit /b 0
exit /b 1

:print_health
set "HAS_UNHEALTHY=0"
for /f "delims=" %%S in ('docker compose config --services 2^>nul') do (
    set "SERVICE_FOUND=0"
    for /f "tokens=1-3 delims=|" %%A in ('docker compose ps --format "{{.Service}}|{{.State}}|{{.Health}}" "%%S" 2^>nul') do (
        set "SERVICE_FOUND=1"
        if /I "%%B"=="running" (
            if /I "%%C"=="healthy" (
                echo [健康] %%A：运行中，健康检查通过
            ) else if "%%C"=="" (
                echo [健康] %%A：运行中，未配置独立健康检查
            ) else (
                echo [不健康] %%A：运行中，健康状态为 %%C
                set "HAS_UNHEALTHY=1"
            )
        ) else (
            echo [不健康] %%A：容器状态为 %%B
            set "HAS_UNHEALTHY=1"
        )
    )
    if "!SERVICE_FOUND!"=="0" (
        echo [不健康] %%S：容器不存在或未启动
        set "HAS_UNHEALTHY=1"
    )
)
if "!HAS_UNHEALTHY!"=="1" exit /b 1
exit /b 0
