# 更新日志

## 2026-08-22 v3.4.1：反向代理宿主机端口参数化

- `docker-compose.yml`新增`SERVER_HTTP_PORT`与`SERVER_HTTPS_PORT`两个仅用于Compose端口发布的变量，默认仍将宿主机80/443映射到容器8080/8443，旧服务器行为不变。
- 单公网IP承载多个项目时，可只在不跟踪的`.env`中改用其他宿主机端口，再由宿主机Nginx按域名分流；变量刻意不加`ZHITIAN_`前缀，因为它们不进入Nginx模板，也不应混入`NGINX_ENVSUBST_FILTER`替换清单。
- 真实Compose验证覆盖默认端口与自定义8081/8444两组渲染，且均使用`docker compose config --quiet`完成语法检查；本轮未修改Nginx模板、容器内部端口或其他服务。

## 2026-08-18 放宽 `.gitignore` 的模板否定规则为 `!.env*.example`

- 本仓库的三行 env 规则是另外三个仓库的范本，但其中 `!.env.example` 只放行恰好同名的文件：`.env.local.example`、`.env.production.example` 这类模板会命中 `.env.*` 被静默忽略，提交时无声排除且 diff 与 CI 都不报异常。改为 `!.env*.example`，只动这一行（1 增 1 删）。
- 缺陷由知了hub 执行者在本机 Compose 验证时真实撞上（新建的 `.env.local.example` 差点消失），按「两个项目共同遵守的规则必须同时写进两份」四个仓库同批跟上。
- 落盘探针实测 7 项全过：`.env`、`.env.local`、`.env.bak-1`、`.env.production`、`nginx/.env` 归 `!!`；`.env.local.example` 归 `??`；已跟踪的 `.env.example` 仍是已跟踪、无改动、`--no-index` 下 `-q` 返回 1。实测口径按手册第十一章：不看退出码、用未跟踪探针文件加 `git status --ignored` 落盘判定。 探针已清理，仓库只剩 `.gitignore` 一处改动。

## 2026-08-16 恢复本机开发通道：8080的HTTPS强制开关与本机自签证书

- `nginx/compose-nginx.conf.template`的8080块新增`set $force_https ${ZHITIAN_FORCE_HTTPS};`，并恢复上一条改动删除的旧路由（`/api/`剥前缀、`= /customer`与`= /customer/`跳`login.html`、`/customer/`剥前缀、`/`到管理后台），每个location首行加`if ($force_https != off) { return 301 https://$host$request_uri; }`守卫——刻意不写成`= on`，这样`ON`、`true`、末尾多余空格等笔误都倒向生产行为，而不是落到else分支把企业管理后台重新摆回明文HTTP根路径。`location = /api/ready`刻意不加守卫——反代自身的健康检查打的就是它，加了跳转容器永远不会healthy、依赖它的服务也起不来。443两个块完全不受开关影响。
- 新增第六个批处理`生成本机自签证书.bat`（CP936+CRLF）：用一次性容器生成覆盖`localhost`/`admin.localhost`/`127.0.0.1`的自签证书到被Git忽略的`local-tls/`，并把私钥设成`root:101`+`0640`，不需要本机安装openssl；已存在则跳过，传参`force`强制重新生成。传给容器的命令保持纯ASCII——容器输出UTF-8而窗口是CP936，中文提示会变乱码，首版实测踩到后改为由批处理自己输出中文。
- **修正上一条改动的一个真实缺陷**：证书原按「宿主机路径＝容器内路径」挂载，该写法在Windows上根本用不了——实测报`invalid mount path: 'D:/...' mount path must be absolute`，容器内挂载目标只能是POSIX绝对路径。现固定挂到`/etc/nginx/tls/origin.pem`与`origin.key`，模板引用固定路径；`ZHITIAN_TLS_*_PATH`退化为纯宿主机源路径（本机可用`./local-tls/...`相对写法），不再注入模板。
- `.env.example`新增`ZHITIAN_FORCE_HTTPS=on`并说明两种模式；`.gitignore`新增`local-tls/`；README重写生产/本机两套健康检查命令，新增「两种运行模式」与本机首次配置一节，并同步目录树与批处理表格。Compose侧默认值写成`${ZHITIAN_FORCE_HTTPS:-on}`，`.env`漏配时按生产行为运行，不会静默把管理后台暴露在明文HTTP的根路径上；实测漏配时容器内收到的确实是`on`。
- 本机验证：两种取值各渲染一次，`nginx -t`均successful；桩上游12项路由实测（`off`时8080的`/`→管理后台、`/customer`与`/customer/`→301到`/customer/login.html`、`/customer/login.html`→web且剥前缀、`/api/health`→`/health`、`/api/ready`直通；`on`时除`/api/ready`外全部301到https；两种取值下443双主机名分流完全一致）。**并用真实四服务跑通完整本机流程**：`docker compose up -d`后四服务全部healthy，`off`下`http://localhost/`(200)、`/customer/login.html`(200)、`/api/health`与`/api/ready`均返回真实JSON，`https://localhost/login.html`与`https://admin.localhost/`同样200；切到`on`后HTTP全部301、`/api/ready`仍直通且反代仍healthy。证书脚本幂等与`force`两条路径均实跑通过，全仓库真实域名检索0命中。

## 2026-08-16 拆分双子域名并接入源站HTTPS

- `nginx/compose-nginx.conf`改名为`compose-nginx.conf.template`并重写为三个server块：容器内8080只放行容器健康检查用的`location = /api/ready`，其余一律`301 https://$host$request_uri`；两个8443块按`${ZHITIAN_CUSTOMER_SERVER_NAME}`和`${ZHITIAN_ADMIN_SERVER_NAME}`分流到customer网页端与管理后台，共用同一份证书。客户端块排在前面因此同时是8443默认server，IP直连或未知Host落到客户端而不是权限最高的后台。`/customer`前缀的两条301与rewrite随之删除，客户端站点改为在自己域名根路径下直接转发；`/api/`的`proxy_buffering off`与180秒收发超时、三个块的`client_max_body_size 25m`与`absolute_redirect off`全部保留。
- `docker-compose.yml`的reverse-proxy新增`${SERVER_PUBLIC_IP}:443:8443`、按同一路径只读绑定挂载的证书与私钥，以及`NGINX_ENVSUBST_TEMPLATE_DIR/OUTPUT_DIR/FILTER`和四个`ZHITIAN_*`变量。另有两处由官方镜像真实行为倒逼的必需改动：入口脚本只把渲染结果写进输出目录、不会替换`/etc/nginx/nginx.conf`，因此`command`显式`nginx -c /tmp/nginx-conf/nginx.conf`；入口脚本也不创建输出目录、且遇到不可写目录只打一行ERROR就跳过渲染，因此`/tmp/nginx-conf`单独挂一块1MiB tmpfs。
- `.env.example`新增`ZHITIAN_CUSTOMER_SERVER_NAME`、`ZHITIAN_ADMIN_SERVER_NAME`、`ZHITIAN_TLS_CERT_PATH`、`ZHITIAN_TLS_KEY_PATH`四项`CHANGE_ME_*`占位符，并写明：真实值只进被Git忽略的`.env`；受版本控制的文件中不得出现任何真实域名；私钥默认`0600 root`会让以uid 101运行的反代直接以`cannot load certificate key ... Permission denied`启动失败（本轮实测复现），推荐`chown root:101` + `chmod 0640`而不是放宽为全局可读。
- `NGINX_ENVSUBST_FILTER=^ZHITIAN_`的真实作用已实测厘清：入口脚本把**容器内全部环境变量名**作为envsubst的替换清单，当前容器没有与nginx变量同名的环境变量，因此不加过滤时`$host`等**恰好不会**被清空；但只要注入一个名为`host`的变量，`proxy_set_header Host`就会被静默改写成该值且nginx照常加载、不报任何错。过滤器因此保留为必需的前置防线，今后需要注入的变量一律用`ZHITIAN_`前缀命名。
- 本机验证与遗留影响：`docker compose config --quiet`退出码0且未展开任何值；一次性容器渲染后`nginx -t`成功；渲染结果中4个`${ZHITIAN_*}`全部代入，`$host`/`$remote_addr`/`$proxy_add_x_forwarded_for`/`$scheme`/`$request_uri`及三个上游`set`变量全部原样保留；接入三个桩上游后8项路由实测全部符合预期（80端口任意路径301到https、`/api/ready`剥前缀直达API、客户端域名`/`返回相对Location `/login.html`、两个域名的`/api/`分别剥成`/chat/stream`与`/health`、`X-Forwarded-Proto=https`且XFF/X-Real-IP非空、未知Host落到客户端块）；全仓库检索真实域名字样0命中。**本机回环部署方式随之改变**：80端口除`/api/ready`外一律跳HTTPS，且Compose要求证书与私钥两个挂载源真实存在，本机验收需自备本地证书并改走https；README与五个`.bat`中的HTTP访问口径本轮未同步，与证书签发、DNS记录、真实`.env`、容器重建和线上验证一并属于服务器侧待办，不得视为已完成。

## 2026-08-15 补全专属IP配置模板说明

- `.env.example`明确`SERVER_PUBLIC_IP`只能填写当前知天实例专属的单个IP地址，不带协议、端口或路径；多IP服务器不得填写其他项目使用的地址。真实值继续只进入被Git忽略的部署仓库`.env`，Compose结构未改。

## 2026-08-13 v3.3：专属IP绑定与环境变量原样注入

- 反向代理端口从通配`80:8080`改为`${SERVER_PUBLIC_IP}:80:8080`，真实地址只写入不跟踪的`.env`，避免同一台多IP服务器上的知天占用全部网卡80端口，也不把实例IP写进Git历史。
- API服务的`env_file`改用`path + format: raw`长语法，防止密码哈希或轮换后的密钥中出现`$`时被Docker Compose再次插值并静默截断；对应最低Docker Compose版本为2.30.0。
- `v3.3`落在提交`d3eb9998aecf12a7bf2eb6fef7380d998cfcaa2d`，用于标记上述部署拓扑和密钥注入边界；本仓库仍不包含真实密钥、域名或服务器地址。

## 2026-08-09 MVP一键操作与0号应急引导

- 新增`一键启动MVP.bat`、`一键停止MVP.bat`、`重新构建并启动MVP.bat`和`获取0号密码.bat`，统一提供中文状态反馈；保卷停止与清卷重建明确分开，清空数据必须输入`yes`确认。
- 新增`重置0号密码.bat`，只允许在唯一默认0号尚未完成首个真实developer接管时应急使用，并通过身份、启用状态和真实developer存在性等检查阻止越界重置。
- 五个批处理统一使用CP936（GBK）与CRLF，避免Windows CMD把UTF-8中文注释误解析成命令；README同步记录Phase C商业化前禁止原样分发0号直改数据库脚本的安全边界。

## 2026-08-09 独立部署仓库建立

- 建立自包含的四服务Docker Compose编排：后端API、管理后台、customer网页端和唯一对外的Nginx反向代理。
- API、管理后台和customer站点只暴露Docker内部端口；SQLite、Chroma与用户文件统一持久化到具名卷，日志、资源限制、非root运行和健康检查纳入默认配置。
- 新增独立反向代理配置、`.gitignore`和部署README；仓库不依赖其他项目运行，Phase C可作为知天独立交付的一部分。
