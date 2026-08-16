@echo off
chcp 936 >nul
setlocal EnableExtensions
cd /d "%~dp0"

set "OUT_DIR=%~dp0local-tls"
set "CERT_FILE=%OUT_DIR%\local-origin.pem"
set "KEY_FILE=%OUT_DIR%\local-origin.key"

echo ================================================================
echo [知天 MVP] 生成本机自签证书
echo 用途：本机回环部署时让反向代理的 443 端口能够启动。
echo 边界：该证书不被任何浏览器信任，浏览器会提示不安全，属预期。
echo        生产环境必须使用真实签发的证书，禁止把本目录文件带到服务器。
echo 输出目录 local-tls 已被 .gitignore 排除，不会进入 Git。
echo ================================================================
echo.

if /I "%~1"=="force" goto :check_docker
if not exist "%CERT_FILE%" goto :check_docker
if not exist "%KEY_FILE%" goto :check_docker
echo [跳过] 证书与私钥已存在，未做任何修改：
echo   %CERT_FILE%
echo   %KEY_FILE%
echo 需要重新生成时执行：生成本机自签证书.bat force
echo.
pause
exit /b 0

:check_docker
where docker >nul 2>nul
if errorlevel 1 goto :docker_missing
docker info >nul 2>nul
if errorlevel 1 goto :docker_unavailable

if not exist "%OUT_DIR%" mkdir "%OUT_DIR%"
if not exist "%OUT_DIR%" goto :mkdir_failed

echo 正在用一次性容器生成证书，本机不需要安装 openssl，请稍候...
echo 首次运行需要联网下载 openssl 组件。
echo 下方将依次显示证书主题、SAN、有效期，以及两个文件的权限——
echo 反向代理以 uid 101 运行，私钥必须是 root:101 且对该 uid 可读。
echo.
rem 容器内命令保持纯 ASCII：容器输出 UTF-8，而本窗口是 CP936，中文会显示成乱码。
docker run --rm -v "%OUT_DIR%:/out" --entrypoint sh nginx:stable-alpine -c "set -e; apk add --no-cache openssl >/dev/null 2>&1 || { echo 'ERR_APK'; exit 1; }; openssl req -x509 -newkey rsa:2048 -sha256 -nodes -days 825 -subj '/CN=zhitian-local' -addext 'subjectAltName=DNS:localhost,DNS:admin.localhost,IP:127.0.0.1' -keyout /out/local-origin.key -out /out/local-origin.pem 2>/dev/null; chown 0:101 /out/local-origin.key /out/local-origin.pem; chmod 0640 /out/local-origin.key; chmod 0644 /out/local-origin.pem; openssl x509 -in /out/local-origin.pem -noout -subject -ext subjectAltName -enddate; ls -l /out/local-origin.key /out/local-origin.pem"
if errorlevel 1 goto :generate_failed

echo.
echo [成功] 已生成本机自签证书：
echo   证书：%CERT_FILE%
echo   私钥：%KEY_FILE%
echo.
echo 接下来在本目录的 .env 中填写以下六项，即可用本机回环方式启动：
echo   SERVER_PUBLIC_IP=127.0.0.1
echo   ZHITIAN_CUSTOMER_SERVER_NAME=localhost
echo   ZHITIAN_ADMIN_SERVER_NAME=admin.localhost
echo   ZHITIAN_TLS_CERT_PATH=./local-tls/local-origin.pem
echo   ZHITIAN_TLS_KEY_PATH=./local-tls/local-origin.key
echo   ZHITIAN_FORCE_HTTPS=off
echo.
echo 填好后运行「一键启动MVP.bat」，http://localhost 与 http://localhost/api 即可用。
pause
exit /b 0

:docker_missing
echo.
echo [失败] 未找到 Docker 命令。请确认 Docker Desktop 已安装并加入 PATH。
goto :failed_end

:docker_unavailable
echo.
echo [失败] Docker Desktop 当前不可用，请先启动 Docker Desktop。
goto :failed_end

:mkdir_failed
echo.
echo [失败] 无法创建输出目录 %OUT_DIR%，请检查磁盘权限。
goto :failed_end

:generate_failed
echo.
echo [失败] 证书生成未完成，请查看上方容器输出。
echo 若提示 ERR_APK，说明容器内下载 openssl 组件失败，通常是网络问题，可稍后重试。
echo 本次未产生可用证书；如目录中残留半成品文件，请删除 local-tls 后重试。

:failed_end
echo.
pause
exit /b 1
