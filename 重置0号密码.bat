@echo off
rem Phase C商业化边界：本脚本仅按单人自用MVP设计，不具备企业级权限治理与审计能力。
rem 它绕过正常认证流程，直接调用后端内部函数修改数据库密码哈希；没有操作审计、没有权限分级，且新密码明文打印在终端。
rem Phase C白标/商业化启动前，禁止把本脚本原样随产品分发给企业客户。
rem 商业版必须改走受权限保护的管理端点或工单流程，审计操作者、时间、来源和理由，并明确由客户IT还是服务商发起重置。
rem 商业版新密码必须通过企业密钥管理机制分发，不得继续在终端明文显示。
setlocal EnableExtensions EnableDelayedExpansion
chcp 936 >nul
cd /d "%~dp0"

echo ============================================================
echo              知天 0号密码应急重置
echo ============================================================
echo [警告] 此操作会使当前0号密码立即失效。
echo [警告] 仅在密码丢失、且0号从未使用过正式身份接管的情况下使用。
echo [警告] 如果0号已经完成过引导使命，不应再使用此脚本；
echo        应直接使用你批准出的developer账号。
echo [提示] 每次成功重置都会生成新密码，上一次密码随即失效。
echo.

set "CONFIRM="
set /p "CONFIRM=确认立即重置0号密码请输入 yes，其他输入取消："
if /i not "!CONFIRM!"=="yes" (
    echo.
    echo [已取消] 未修改0号密码。
    echo.
    pause
    exit /b 0
)

echo.

where docker >nul 2>&1
if errorlevel 1 (
    echo [失败] 未找到Docker命令，请先启动Docker Desktop。
    echo.
    pause
    exit /b 1
)

docker info >nul 2>&1
if errorlevel 1 (
    echo [失败] Docker服务不可用，请确认Docker Desktop已经启动。
    echo.
    pause
    exit /b 1
)

docker compose config --quiet >nul 2>&1
if errorlevel 1 (
    echo [失败] docker-compose.yml无法解析，请检查部署目录和后端.env配置。
    echo.
    pause
    exit /b 1
)

echo [检查] 正在确认唯一0号账号、默认标记及真实developer接管状态……
echo [执行] 仅在全部安全条件通过后才会重置密码。
set "ZHITIAN_ZERO_RESET_MODE=reset"
call :run_zero_helper
set "NEW_PASSWORD="
for /f "tokens=1,* delims==" %%A in ("!ZERO_RESULT!") do (
    if "%%A"=="ZHITIAN_ZERO_RESET_OK" set "NEW_PASSWORD=%%B"
)

if defined NEW_PASSWORD (
    echo.
    echo [成功] 0号密码已重置，旧密码已经失效。
    echo ============================================================
    echo 新的0号密码：!NEW_PASSWORD!
    echo ============================================================
    echo [重要] 新密码只在本窗口显示，请立即保存到安全位置。
    echo [边界] 0号完成首个真实developer引导后会自动失效；此后请使用真实developer账号。
    echo.
    pause
    exit /b 0
)

call :print_zero_error
echo [结果] 重置未完成；若检查后账号状态发生变化，脚本会安全中止。
echo.
pause
exit /b 1

:run_zero_helper
set "ZERO_RESULT="
rem 内部容器命令不读取任何标准输入；账号校验与密码重置在同一进程中完成。
for /f "usebackq delims=" %%R in (`docker compose run --rm -T -e ZHITIAN_ZERO_RESET_MODE zhitian-api python -c "import base64;exec(base64.b64decode('aW1wb3J0IG9zCmZyb20gbGF5ZXJzIGltcG9ydCBhdXRoCgptb2RlID0gb3MuZW52aXJvbi5nZXQoIlpISVRJQU5fWkVST19SRVNFVF9NT0RFIiwgIiIpCndpdGggYXV0aC5fY29ubmVjdCgpIGFzIGNvbm46CiAgICByb3dzID0gY29ubi5leGVjdXRlKAogICAgICAgICIiIgogICAgICAgIFNFTEVDVCB1c2VyX2lkLCB1c2VybmFtZSwgcm9sZSwgaXNfYWN0aXZlLCBpc19kZWZhdWx0X2FjY291bnQKICAgICAgICBGUk9NIHVzZXJzCiAgICAgICAgV0hFUkUgdXNlcm5hbWUgPSA/CiAgICAgICAgIiIiLAogICAgICAgICgiMCIsKSwKICAgICkuZmV0Y2hhbGwoKQogICAgcmVhbF9kZXZlbG9wZXJfY291bnQgPSBpbnQoCiAgICAgICAgY29ubi5leGVjdXRlKAogICAgICAgICAgICAiIiIKICAgICAgICAgICAgU0VMRUNUIENPVU5UKCopCiAgICAgICAgICAgIEZST00gdXNlcnMKICAgICAgICAgICAgV0hFUkUgcm9sZSA9ICdkZXZlbG9wZXInCiAgICAgICAgICAgICAgQU5EIGlzX2FjdGl2ZSA9IDEKICAgICAgICAgICAgICBBTkQgQ09BTEVTQ0UoaXNfZGVmYXVsdF9hY2NvdW50LCAwKSA9IDAKICAgICAgICAgICAgIiIiCiAgICAgICAgKS5mZXRjaG9uZSgpWzBdCiAgICApCgppZiBub3Qgcm93czoKICAgIHByaW50KCJaSElUSUFOX1pFUk9fRVJST1JfTUlTU0lORyIpCiAgICByYWlzZSBTeXN0ZW1FeGl0KDApCmlmIGxlbihyb3dzKSAhPSAxOgogICAgcHJpbnQoIlpISVRJQU5fWkVST19FUlJPUl9NVUxUSVBMRSIpCiAgICByYWlzZSBTeXN0ZW1FeGl0KDApCgpyb3cgPSByb3dzWzBdCmlmIG5vdCBib29sKHJvd1siaXNfZGVmYXVsdF9hY2NvdW50Il0pOgogICAgcHJpbnQoIlpISVRJQU5fWkVST19FUlJPUl9OT1RfREVGQVVMVCIpCiAgICByYWlzZSBTeXN0ZW1FeGl0KDApCmlmIHJvd1sicm9sZSJdICE9ICJkZXZlbG9wZXIiOgogICAgcHJpbnQoIlpISVRJQU5fWkVST19FUlJPUl9XUk9OR19ST0xFIikKICAgIHJhaXNlIFN5c3RlbUV4aXQoMCkKaWYgbm90IGJvb2wocm93WyJpc19hY3RpdmUiXSk6CiAgICBwcmludCgiWkhJVElBTl9aRVJPX0VSUk9SX0lOQUNUSVZFIikKICAgIHJhaXNlIFN5c3RlbUV4aXQoMCkKaWYgcmVhbF9kZXZlbG9wZXJfY291bnQ6CiAgICBwcmludCgiWkhJVElBTl9aRVJPX0VSUk9SX1JFQUxfREVWRUxPUEVSIikKICAgIHJhaXNlIFN5c3RlbUV4aXQoMCkKaWYgbW9kZSA9PSAiY2hlY2siOgogICAgcHJpbnQoIlpISVRJQU5fWkVST19DSEVDS19PSyIpCiAgICByYWlzZSBTeXN0ZW1FeGl0KDApCmlmIG1vZGUgIT0gInJlc2V0IjoKICAgIHByaW50KCJaSElUSUFOX1pFUk9fRVJST1JfSU5WQUxJRF9NT0RFIikKICAgIHJhaXNlIFN5c3RlbUV4aXQoMCkKCnBhc3N3b3JkID0gYXV0aC5yZXNldF91c2VyX3Bhc3N3b3JkKHJvd1sidXNlcl9pZCJdKQppZiBwYXNzd29yZCBpcyBOb25lOgogICAgcHJpbnQoIlpISVRJQU5fWkVST19FUlJPUl9SRVNFVF9GQUlMRUQiKQplbHNlOgogICAgcHJpbnQoIlpISVRJQU5fWkVST19SRVNFVF9PSz0iICsgcGFzc3dvcmQp'))" ^<nul`) do set "ZERO_RESULT=%%R"
if not defined ZERO_RESULT set "ZERO_RESULT=ZHITIAN_ZERO_ERROR_DOCKER"
exit /b 0

:print_zero_error
if "!ZERO_RESULT!"=="ZHITIAN_ZERO_ERROR_MISSING" echo [失败] 当前系统中不存在用户名为0的账号。若系统仍为空白，请改用“获取0号密码.bat”初始化。
if "!ZERO_RESULT!"=="ZHITIAN_ZERO_ERROR_MULTIPLE" echo [失败] 检测到多个用户名为0的账号，属于异常数据；为避免重置错误对象，脚本已中止。
if "!ZERO_RESULT!"=="ZHITIAN_ZERO_ERROR_NOT_DEFAULT" echo [失败] 用户名为0的账号不是默认账号，脚本拒绝处理。
if "!ZERO_RESULT!"=="ZHITIAN_ZERO_ERROR_WRONG_ROLE" echo [失败] 默认0号不是developer角色，脚本拒绝处理。
if "!ZERO_RESULT!"=="ZHITIAN_ZERO_ERROR_INACTIVE" echo [失败] 默认0号已经失效；请使用已批准的真实developer账号，不要重新启用0号。
if "!ZERO_RESULT!"=="ZHITIAN_ZERO_ERROR_REAL_DEVELOPER" echo [失败] 已检测到启用中的真实developer账号；0号引导使命已完成，请直接使用真实developer账号。
if "!ZERO_RESULT!"=="ZHITIAN_ZERO_ERROR_RESET_FAILED" echo [失败] 重置时未找到目标账号，未修改任何密码。
if "!ZERO_RESULT!"=="ZHITIAN_ZERO_ERROR_INVALID_MODE" echo [失败] 脚本内部执行模式异常，未修改任何密码。
if "!ZERO_RESULT!"=="ZHITIAN_ZERO_ERROR_DOCKER" echo [失败] 无法从后端容器读取检查结果，请查看上方Docker错误信息。
exit /b 0
