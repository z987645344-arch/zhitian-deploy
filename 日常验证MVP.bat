@echo off
chcp 936 >nul
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"

rem 本脚本用于日常代码验证：增量构建并强制重建容器，但保留本地数据。
rem 如需无缓存重建并清空全部数据，请改用“重新构建并启动MVP.bat”。
echo [保留数据] 本次会增量构建镜像并重建容器，不带 -v，不删除具名卷。
echo [知天 MVP] 正在检查 Docker 与 Compose 配置，请稍候...
call :check_docker
if errorlevel 1 goto :start_failed

call :capture_image_ids BEFORE
echo.
echo ==================== 构建前镜像 ID ====================
call :print_image_ids BEFORE
echo ID 变化是重建发生的唯一凭证；仅看到 healthy 不能证明代码已进入镜像。
echo =======================================================

echo.
echo 正在增量构建并强制重建容器，本地数据卷会保留...
docker compose up -d --build --force-recreate
set "START_COMMAND_RESULT=!errorlevel!"

call :capture_image_ids AFTER
echo.
echo ==================== 构建后镜像 ID ====================
call :print_image_ids AFTER
echo ID 变化是重建发生的唯一凭证；请对照构建前后的相关镜像。
echo =======================================================

set "IMAGE_CHANGED=0"
for %%V in (API ADMIN WEB) do (
    if not "!BEFORE_%%V!"=="!AFTER_%%V!" set "IMAGE_CHANGED=1"
)
if "!IMAGE_CHANGED!"=="0" (
    echo [警告] 三个业务镜像 ID 均未变化。若源码确有改动，请检查构建上下文与缓存命中。
) else (
    echo [确认] 至少一个业务镜像 ID 已变化，重建证据成立。
)

if not "!START_COMMAND_RESULT!"=="0" goto :start_failed

echo.
echo 构建与容器重建命令已完成，正在等待健康检查（最长约 120 秒）...
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
echo [成功] 知天 MVP 已使用当前构建结果健康运行，本地数据卷保持不变。
echo 管理后台：http://localhost/
echo 客户 web 端：http://localhost/customer/（自动 301 到 /customer/login.html）
echo API：http://localhost/api/...
echo Flutter客户端配置后端地址请填 http://localhost/api（不要加:8000端口）
echo 提示：本机如被 301 跳转到 HTTPS，请在部署仓库 .env 设置 ZHITIAN_FORCE_HTTPS=off。
pause
exit /b 0

:start_failed
echo.
echo [失败] 知天 MVP 日常验证启动失败，请查看上方 Docker 错误信息。
echo 本脚本没有使用 -v，已有具名卷数据不会因本脚本被删除。
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

:capture_image_ids
set "%~1_API=不存在"
set "%~1_ADMIN=不存在"
set "%~1_WEB=不存在"
for /f "delims=" %%I in ('docker image inspect zhitian-api:dev-production --format "{{.Id}}" 2^>nul') do set "%~1_API=%%I"
for /f "delims=" %%I in ('docker image inspect zhitian-admin:dev-production --format "{{.Id}}" 2^>nul') do set "%~1_ADMIN=%%I"
for /f "delims=" %%I in ('docker image inspect zhitian-web:dev-production --format "{{.Id}}" 2^>nul') do set "%~1_WEB=%%I"
exit /b 0

:print_image_ids
echo zhitian-api:dev-production   = !%~1_API!
echo zhitian-admin:dev-production = !%~1_ADMIN!
echo zhitian-web:dev-production   = !%~1_WEB!
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
