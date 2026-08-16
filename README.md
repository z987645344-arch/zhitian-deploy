# zhitian-deploy

知天自用云端 MVP 的独立部署仓库。它只保存 Docker Compose 编排和反向代理配置，不保存业务代码、运行数据或真实密钥。

当前编排包含四个服务：

- `zhitian-api`：后端 API，源码和 Dockerfile 来自 `zhitian` 仓库；
- `zhitian-admin`：管理后台静态站点，来自 `zhitian_admin` 仓库；
- `zhitian-web`：customer 网页客户端，来自 `zhitian/web_client`；
- `reverse-proxy`：唯一映射宿主机端口的 Nginx 入口。443 按主机名分流——客户端主机名到 `zhitian-web`、企业管理后台主机名到 `zhitian-admin`，两者的 `/api/` 都到 `zhitian-api`；80 的行为由 `ZHITIAN_FORCE_HTTPS` 决定，见「两种运行模式」。

仓库默认保持私有。虽然配置文件本身不含密钥，但它会暴露服务拓扑和资源边界；如后续决定公开，应先重新做一次信息暴露审查。

## 使用前提

- 已安装 Docker 与 Docker Compose；由于API服务的`env_file`使用`format: raw`防止密钥中的`$`被Compose插值，Docker Compose必须为**2.30.0或更高版本**。本项目已在Docker Desktop 29.6.2、Docker Compose 5.3.1、WSL2环境验证。
- 当前Phase B服务器实例要求在本仓库同目录、且不进入Git的`.env`中设置`SERVER_PUBLIC_IP`；宿主机网卡必须真实拥有该地址，且该地址的TCP 80未被其他进程占用。Compose只把知天入口发布到`${SERVER_PUBLIC_IP}:80`，不再通配监听整机所有网卡。若云厂商只做公网NAT而未把该地址配置到网卡，启动前必须先处理网络映射，不能直接套用本绑定。
- 部署仓库同目录的`.env`还需要`ZHITIAN_CUSTOMER_SERVER_NAME`、`ZHITIAN_ADMIN_SERVER_NAME`、`ZHITIAN_TLS_CERT_PATH`、`ZHITIAN_TLS_KEY_PATH`和`ZHITIAN_FORCE_HTTPS`，含义与格式见`.env.example`。两个主机名共用同一张证书；证书与私钥按`.env`给出的宿主机路径只读挂到容器内固定的`/etc/nginx/tls/`，Nginx模板引用的是该固定路径。
- 三个仓库必须位于同一父目录，目录名保持如下：

```text
workspace/
├── zhitian/
├── zhitian_admin/
└── zhitian-deploy/
    ├── docker-compose.yml
    ├── local-tls/                       # 本机自签证书，被 .gitignore 排除
    └── nginx/compose-nginx.conf.template
```

- 后端运行配置位于 `zhitian/.env`。先从 `zhitian/.env.example`复制并在部署机器上填写，不要从开发机整目录拷贝真实 `.env`。
- 当前 Phase A CI 不向镜像仓库推送镜像。换机部署通常应从源码构建；如果本机已经有三个匹配标签的镜像，也可以显式复用。

## 获取仓库

```bash
git clone https://github.com/z987645344-arch/zhitian.git
git clone https://github.com/z987645344-arch/zhitian_admin.git
git clone https://github.com/z987645344-arch/zhitian-deploy.git
git -C zhitian fetch --tags origin
git -C zhitian checkout --detach v3.3
git -C zhitian_admin fetch --tags origin
git -C zhitian_admin checkout --detach v3.2
git -C zhitian-deploy fetch --tags origin
git -C zhitian-deploy checkout --detach v3.3
cd zhitian-deploy
```

`zhitian-deploy`是私有仓库，clone 前需要为 GitHub 配置有权访问该仓库的凭据。
生产服务器必须checkout运维单指定的精确标签，不使用`git pull`盲跟`master`或`main`。
上面是当前已确认组合；后续发布新版本时，应按新运维单同时更新三个目标标签。

## 准备配置

在 `zhitian-deploy` 目录执行：

```bash
cp ../zhitian/.env.example ../zhitian/.env
cp .env.example .env
```

分别填写后端运行配置，以及部署仓库`.env`中的`SERVER_PUBLIC_IP`、两个主机名、
两个证书路径和`ZHITIAN_FORCE_HTTPS`。四项`CHANGE_ME_*`占位符必须逐项填实：
`docker compose config`只会在`SERVER_PUBLIC_IP`仍是占位符时报`invalid IP address`，
证书路径带着占位符也照样通过语法检查，错误要到启动反向代理时才暴露。
两份`.env`都不会进入Git，也不得写进Compose、Dockerfile、镜像或日志。

验证 Compose 能解析且不打印展开后的环境变量：

```bash
docker compose config --quiet
```

后端`../zhitian/.env`必须使用不带引号的`KEY=value`格式。API服务通过长语法`env_file.path + format: raw`注入该文件，避免bcrypt哈希或未来轮换后的密钥中出现`$`时被Compose当成变量引用；`raw`也会把引号视为值本身，因此不要写成`KEY="value"`。部署仓库自己的`.env`仍由Compose用于`${SERVER_PUBLIC_IP}`等占位符插值，不属于该`raw`边界。

## 两种运行模式

`.env`的`ZHITIAN_FORCE_HTTPS`只决定容器内8080（宿主机80）的行为；443的双主机名分流在两种取值下完全一致。

| 取值 | 适用 | 80端口行为 |
|------|------|-----------|
| `on` | **生产必须** | 除`/api/ready`外一律`301`到`https://$host$request_uri` |
| `off` | 仅本机回环部署（`SERVER_PUBLIC_IP=127.0.0.1`） | 保留完整HTTP路由：`/`到管理后台、`/customer/`到客户端网页版、`/api/`到后端 |

`/api/ready`在两种取值下都不跳转：反代容器自身的健康检查打的就是这个路径，一旦跳转，容器永远不会healthy，依赖它的其余服务也起不来。

守卫写作`!= off`：只有精确的小写`off`才关闭跳转，其余任何取值（含`ON`、`true`、末尾多余空格等笔误）都按生产行为跳HTTPS。这是刻意让失败方向指向安全——若反过来写成`= on`，生产上一个大小写笔误就会把企业管理后台重新摆回明文HTTP的根路径。Compose侧默认值同样是`on`，`.env`漏配时亦按生产行为运行。

### 本机首次配置

443块的`ssl_certificate`找不到文件时nginx直接启动失败，Compose的绑定挂载也要求源文件存在，因此**本机同样必须有一张证书**——它只是占位，本机流量走HTTP，不会有客户端校验它。

1. 双击`生成本机自签证书.bat`。它用一次性容器生成，本机不需要安装openssl；证书写入被Git忽略的`local-tls/`，同时覆盖`localhost`、`admin.localhost`和`127.0.0.1`，并把私钥设为`root:101`、`0640`——反代以uid 101运行，权限不对会以`cannot load certificate key ... Permission denied`启动失败。已存在则跳过，需要重新生成时传参`force`。
2. 按脚本末尾提示填写`.env`六项（其中`ZHITIAN_FORCE_HTTPS=off`、两个证书路径可用`./local-tls/...`相对写法）。
3. 之后照常运行`一键启动MVP.bat`，`http://localhost`与`http://localhost/api`与以往一致。

本机也可以用`https://localhost`和`https://admin.localhost`走一遍**与生产同形**的双主机名路由，浏览器会提示证书不受信任，属预期。`*.localhost`由Chrome/Edge/Firefox自行解析到`127.0.0.1`，命令行工具则需要`--resolve`或hosts记录。

`local-tls/`只服务本机，**不得**带到服务器；生产证书在服务器现场签发和保存。

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

健康检查按`ZHITIAN_FORCE_HTTPS`取值二选一。

生产（`on`）：80除`/api/ready`外全部301，因此验收走两个主机名的HTTPS。

```bash
set -a
. ./.env
set +a
# 唯一保留在80的路径，反代容器的健康检查打的就是它
curl --fail --silent --show-error "http://${SERVER_PUBLIC_IP}/api/ready"
# 其余一律走443；两个主机名共用同一张证书
curl --fail --silent --show-error "https://${ZHITIAN_CUSTOMER_SERVER_NAME}/login.html"
curl --fail --silent --show-error "https://${ZHITIAN_CUSTOMER_SERVER_NAME}/api/health"
curl --fail --silent --show-error "https://${ZHITIAN_ADMIN_SERVER_NAME}/"
curl --fail --silent --show-error "https://${ZHITIAN_ADMIN_SERVER_NAME}/api/health"
# 80的其余路径应当返回301，而不是内容
curl --silent --output /dev/null --write-out '%{http_code} %{redirect_url}\n' "http://${SERVER_PUBLIC_IP}/"
```

本机回环（`off`）：80保留完整HTTP路由，443同形可选。

```bash
curl --fail --silent --show-error "http://localhost/"
curl --fail --silent --show-error "http://localhost/customer/login.html"
curl --fail --silent --show-error "http://localhost/api/health"
curl --fail --silent --show-error "http://localhost/api/ready"
# 自签证书不受信任，本机核对需要 -k
curl --fail --silent --show-error -k "https://localhost/login.html"
curl --fail --silent --show-error -k --resolve admin.localhost:443:127.0.0.1 "https://admin.localhost/"
```

只有反向代理映射宿主机`${SERVER_PUBLIC_IP}`的80与443；API、管理后台和customer网页端的内部端口不会直接暴露。容器健康检查仍在各容器内部访问`127.0.0.1:8080/8000`，不依赖宿主机发布地址，也不受`ZHITIAN_FORCE_HTTPS`影响。

> 当前`docker-compose.yml`通过未跟踪的`SERVER_PUBLIC_IP`接收实例专属IP。下面的Windows批处理不会自动猜测地址；在其他主机使用前必须先从`.env.example`复制并填写本机值。Phase C交付时同样由客户填写自己的地址，不携带个人服务器IP。

## Windows 一键操作脚本

在 `zhitian-deploy` 根目录双击以下脚本即可操作。脚本会先切换到自身目录，不依赖打开窗口时的当前路径；所有脚本执行结束后都会保留窗口，便于阅读成功或失败信息。

| 脚本 | 用途与安全边界 |
|------|----------------|
| `生成本机自签证书.bat` | **仅本机回环部署使用**。用一次性容器生成覆盖`localhost`/`admin.localhost`/`127.0.0.1`的自签证书到`local-tls/`，并设好uid 101可读的私钥权限。已存在则跳过，传参`force`可强制重新生成。该证书不被任何浏览器信任，也**不得**带到服务器；生产证书在服务器现场签发。 |
| `一键启动MVP.bat` | 执行 `docker compose up -d`，等待后逐项打印四个服务的中文健康状态。日常启动使用；它不会自动重建旧标签镜像。脚本最后打印的`http://localhost`与`http://localhost/api`只在**本机回环部署且`ZHITIAN_FORCE_HTTPS=off`**时有效；生产（`on`）一律改用两个正式主机名的HTTPS地址，`http://`除`/api/ready`外都会301。Flutter调试客户端在本机回环时填`http://localhost/api`，不要加`:8000`；远程客户端填客户端主机名的`https://<客户端主机名>/api`，不要填裸IP。 |
| `一键停止MVP.bat` | 执行不带 `-v` 的 `docker compose down`。容器和网络会停止并移除，业务数据继续保留在具名卷 `zhitian-mvp-data` 中。 |
| `重新构建并启动MVP.bat` | 代码或依赖更新后执行无缓存镜像构建，再运行 `docker compose down -v && docker compose up -d`。**该脚本会清空全部账号、文档、向量和历史记录**，只有输入完整的 `yes` 才会继续；普通升级若需要保留数据，不得使用此脚本。 |
| `获取0号密码.bat` | 人工运行生产初始化脚本，创建0号developer并显示一次性密码。密码只显示一次，必须立即保存；0号、真实developer或业务数据已经存在时会拒绝重复初始化。 |
| `重置0号密码.bat` | 仅用于“0号密码已遗失、且尚未完成首个真实developer接管”的应急恢复。脚本只处理唯一、启用、`is_default_account=1`的用户名0，并在没有其他启用中真实developer时才允许继续；必须输入`yes`确认，成功后旧密码立即失效。它不接受任意用户ID，也不能用于重置其他账号。 |

`docker compose up -d`只会按现有镜像标签启动容器，不代表镜像已经包含最新源码。完成代码、依赖、Dockerfile、模型资产或静态前端更新后，必须先重新构建镜像；是否删除数据卷应依据实际升级方案和可验证备份单独决定。

六个 `.bat` 文件使用 Windows 中文命令行兼容的 CP936（GBK）编码和 CRLF 换行。后续编辑时必须保留该编码；直接转换成UTF-8无BOM或UTF-8 BOM都可能让`cmd.exe`把中文拆成错误命令。`获取0号密码.bat`只在运行容器命令期间临时切换到UTF-8，结束前会恢复CP936，以同时保证批处理提示和容器输出不乱码；`生成本机自签证书.bat`走的是另一条路——传给容器的命令保持纯ASCII，中文提示全部由批处理自己输出，因此不需要切换代码页。

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

服务器私有`.env`注入已经具备：后端凭据通过`env_file.path + format: raw`进入API容器，
不写入Git或镜像。企业级密钥管理、自动轮换和受控分发机制仍未具备；定时异地备份和镜像
registry发布也仍待后续Phase B工作完成，不能把当前`.env`机制等同于完整的企业密钥治理。
双主机名与443监听在本仓库已经就位，但真实证书签发、DNS记录和线上验证属于服务器现场
工作，本仓库只提供配置骨架和占位符。
