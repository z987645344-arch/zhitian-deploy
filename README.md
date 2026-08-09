# zhitian-deploy

知天自用云端 MVP 的独立部署仓库。它只保存 Docker Compose 编排和反向代理配置，不保存业务代码、运行数据或真实密钥。

当前编排包含四个服务：

- `zhitian-api`：后端 API，源码和 Dockerfile 来自 `zhitian` 仓库；
- `zhitian-admin`：管理后台静态站点，来自 `zhitian_admin` 仓库；
- `zhitian-web`：customer 网页客户端，来自 `zhitian/web_client`；
- `reverse-proxy`：唯一映射宿主机端口的 Nginx 入口，统一转发 `/`、`/customer/` 和 `/api/`。

仓库默认保持私有。虽然配置文件本身不含密钥，但它会暴露服务拓扑和资源边界；如后续决定公开，应先重新做一次信息暴露审查。

## 使用前提

- 已安装 Docker 与 Docker Compose；本项目已在 Docker Desktop 29.6.2、Docker Compose 5.3.1、WSL2 环境验证。
- 三个仓库必须位于同一父目录，目录名保持如下：

```text
workspace/
├── zhitian/
├── zhitian_admin/
└── zhitian-deploy/
    ├── docker-compose.yml
    └── nginx/compose-nginx.conf
```

- 后端运行配置位于 `zhitian/.env`。先从 `zhitian/.env.example`复制并在部署机器上填写，不要从开发机整目录拷贝真实 `.env`。
- 当前 Phase A CI 不向镜像仓库推送镜像。换机部署通常应从源码构建；如果本机已经有三个匹配标签的镜像，也可以显式复用。

## 获取仓库

```bash
git clone https://github.com/z987645344-arch/zhitian.git
git clone https://github.com/z987645344-arch/zhitian_admin.git
git clone https://github.com/z987645344-arch/zhitian-deploy.git
cd zhitian-deploy
```

`zhitian-deploy`是私有仓库，clone 前需要为 GitHub 配置有权访问该仓库的凭据。

## 准备配置

在 `zhitian-deploy` 目录执行：

```bash
cp ../zhitian/.env.example ../zhitian/.env
```

将占位值替换为部署实例自己的真实配置。`.env`不会进入本仓库，也不得写进 Compose、Dockerfile、镜像或日志。

验证 Compose 能解析且不打印展开后的环境变量：

```bash
docker compose config --quiet
```

## 构建与启动

从三个源码目录构建并启动：

```bash
docker compose up -d --build
docker compose ps
```

若 `zhitian-api:dev-production`、`zhitian-admin:dev-production` 和 `zhitian-web:dev-production` 已在本机完成构建，可复用已有镜像：

```bash
docker compose up -d --no-build
```

健康检查：

```bash
curl --fail --silent --show-error http://127.0.0.1/
curl --fail --silent --show-error http://127.0.0.1/customer/login.html
curl --fail --silent --show-error http://127.0.0.1/api/health
curl --fail --silent --show-error http://127.0.0.1/api/ready
```

只有反向代理映射宿主机 `80` 端口；API、管理后台和 customer 网页端的内部端口不会直接暴露。

## Windows 一键操作脚本

在 `zhitian-deploy` 根目录双击以下脚本即可操作。脚本会先切换到自身目录，不依赖打开窗口时的当前路径；所有脚本执行结束后都会保留窗口，便于阅读成功或失败信息。

| 脚本 | 用途与安全边界 |
|------|----------------|
| `一键启动MVP.bat` | 执行 `docker compose up -d`，等待后逐项打印四个服务的中文健康状态。日常启动使用；它不会自动重建旧标签镜像。成功后从 `http://localhost` 访问管理后台，Flutter后端地址同样填写 `http://localhost`，不要添加 `:8000`。 |
| `一键停止MVP.bat` | 执行不带 `-v` 的 `docker compose down`。容器和网络会停止并移除，业务数据继续保留在具名卷 `zhitian-mvp-data` 中。 |
| `重新构建并启动MVP.bat` | 代码或依赖更新后执行无缓存镜像构建，再运行 `docker compose down -v && docker compose up -d`。**该脚本会清空全部账号、文档、向量和历史记录**，只有输入完整的 `yes` 才会继续；普通升级若需要保留数据，不得使用此脚本。 |
| `获取0号密码.bat` | 人工运行生产初始化脚本，创建0号developer并显示一次性密码。密码只显示一次，必须立即保存；0号、真实developer或业务数据已经存在时会拒绝重复初始化。 |
| `重置0号密码.bat` | 仅用于“0号密码已遗失、且尚未完成首个真实developer接管”的应急恢复。脚本只处理唯一、启用、`is_default_account=1`的用户名0，并在没有其他启用中真实developer时才允许继续；必须输入`yes`确认，成功后旧密码立即失效。它不接受任意用户ID，也不能用于重置其他账号。 |

`docker compose up -d`只会按现有镜像标签启动容器，不代表镜像已经包含最新源码。完成代码、依赖、Dockerfile、模型资产或静态前端更新后，必须先重新构建镜像；是否删除数据卷应依据实际升级方案和可验证备份单独决定。

五个 `.bat` 文件使用 Windows 中文命令行兼容的 CP936（GBK）编码和 CRLF 换行。后续编辑时必须保留该编码；直接转换成UTF-8无BOM或UTF-8 BOM都可能让`cmd.exe`把中文拆成错误命令。`获取0号密码.bat`只在运行容器命令期间临时切换到UTF-8，结束前会恢复CP936，以同时保证批处理提示和容器输出不乱码。

0号只承担空白生产实例的首个developer引导。它批准出第一个真实developer后会自动失效，届时应使用真实developer账号及正式找回流程，**不得**用`重置0号密码.bat`恢复0号。若脚本报告同名0号不止一个、0号已失效、身份标记异常或真实developer已经存在，应保留现场并排查数据，而不是绕过检查直接修改数据库。

### 0号应急重置的Phase C商业化边界

`重置0号密码.bat`的设计前提是开发者单人自用MVP，只解决“唯一默认0号在首次接管前遗失密码”的本机应急问题，**不具备企业级权限治理与审计能力**。它绕过正常登录、找回密码和审批认证流程，从容器内直接调用后端内部函数修改SQLite密码哈希；整个过程没有操作审计、没有权限分级，新密码还会以明文打印在当前终端。

因此，Phase C白标或商业化启动前，禁止把该脚本原样打入交付包或分发给企业客户。商业版必须重新设计为受权限保护的管理端点或正式工单流程，并同时满足：

- 审计日志完整记录操作者、操作时间、请求来源和重置理由；
- 在产品与服务协议中明确谁有权发起重置，是客户IT部门自行处理，还是由服务商在授权工单下代为处理；
- 新密码或恢复凭据通过企业密钥管理、受控Secret通道或等价机制分发，不再在终端直接显示明文。

## 停止与数据边界

```bash
docker compose stop
docker compose start
docker compose down
```

普通 `down` 保留具名卷 `zhitian-mvp-data`。不要把 `docker compose down -v` 当作日常命令；它会删除持久数据，只有隔离测试明确清理且已有可验证备份时才可使用。

真实域名、HTTPS、服务器私有 Secret 注入、定时异地备份和镜像 registry 发布仍属于 Phase B，不在本仓库当前基线中伪装为已完成。
