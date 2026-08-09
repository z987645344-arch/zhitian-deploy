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

## 停止与数据边界

```bash
docker compose stop
docker compose start
docker compose down
```

普通 `down` 保留具名卷 `zhitian-mvp-data`。不要把 `docker compose down -v` 当作日常命令；它会删除持久数据，只有隔离测试明确清理且已有可验证备份时才可使用。

真实域名、HTTPS、服务器私有 Secret 注入、定时异地备份和镜像 registry 发布仍属于 Phase B，不在本仓库当前基线中伪装为已完成。
