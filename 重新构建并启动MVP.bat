@echo off
chcp 936 >nul
setlocal EnableExtensions
cd /d "%~dp0"

rem 日常代码验证且要保留数据时，请使用“日常验证MVP.bat”。
rem 本脚本仅用于必须无缓存重建并清空全部数据的全新环境场景。
echo ================================================================
echo [危险警告] 本操作会清空所有数据，仅在代码更新或需要全新环境时使用
echo 它会删除具名卷 zhitian-mvp-data，现有账号、文档、向量和历史记录均会丢失。
echo ================================================================
echo.
set "CONFIRM="
set /p "CONFIRM=如已确认备份并愿意清空全部数据，请输入 yes 继续："
if /I not "%CONFIRM%"=="yes" (
    echo.
    echo [已取消] 输入内容不是 yes，未执行构建、停机、删卷或启动操作。
    pause
    exit /b 0
)

where docker >nul 2>nul
if errorlevel 1 goto :docker_missing
docker info >nul 2>nul
if errorlevel 1 goto :docker_unavailable
docker compose config --quiet >nul 2>nul
if errorlevel 1 goto :config_failed

echo.
echo [1/2] 正在无缓存重新构建全部镜像，这可能需要较长时间...
docker compose build --no-cache
if errorlevel 1 goto :build_failed
echo [成功] 镜像重新构建完成。

echo.
echo [2/2] 正在删除旧容器和具名卷，并以全新数据环境启动...
docker compose down -v && docker compose up -d
if errorlevel 1 goto :restart_failed

echo.
echo [成功] 旧数据已清空，知天 MVP 已使用新镜像启动。
docker compose ps
echo 建议随后运行“一键启动MVP.bat”查看完整中文健康检查结果。
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

:config_failed
echo.
echo [失败] docker-compose.yml 校验失败，请检查部署目录和后端 .env 配置。
goto :failed_end

:build_failed
echo.
echo [失败] 镜像构建失败；尚未执行删卷操作，原有数据仍保留。
goto :failed_end

:restart_failed
echo.
echo [失败] 删除旧环境或启动新环境时发生错误，请查看上方 Docker 信息。
echo 如果删卷已经完成，旧数据无法由本脚本自动恢复，请按备份恢复文档处理。

:failed_end
pause
exit /b 1
