# 更新日志

## 2026-09-05 将8080入口按主机名隔离客户端与管理后台

- 将8080从单一`server_name _`块拆为与8443一致的客户端优先、管理后台独立两个主机名块；客户端块保持配置顺序第一，使未知Host默认落到客户端而非管理后台，不再依赖仓库外的上游代理提供该边界。
- `ZHITIAN_FORCE_HTTPS`仅继续控制HTTP跳转，不再决定站点分流；上游终止TLS且明文回源时也能按既有两个`SERVER_NAME`分流。仅当配置值确为`localhost/admin.localhost`组合时，Nginx `map`才保留本机根路径到管理后台；真实主机名配置下伪造`Host: localhost`仍倒向客户端。`/customer/`与`/api/`既有入口保持不变。
- 两个8080块各自保留无HTTPS跳转的精确`location = /api/ready`，确保Nginx先按Host选中任一块后健康检查仍可达；空的必填主机名刻意渲染为非法`server_name ;`并使Nginx退出码为1，不静默接受错误配置。
- `docker compose config --quiet`通过；旁路一次性容器的两组渲染配置均通过`nginx -t`，实测客户端/管理/陌生Host/真实配置下伪造`localhost`/`127.0.0.1`健康路径分别命中`CLIENT`/`ADMIN`/`CLIENT`/`CLIENT`/`API_READY`，本机三个既有入口行为不变。临时容器、网络和卷已全部清理，本轮未部署、未接触生产。

## 2026-09-04 找全部署README的端口、拓扑与证书权限旧口径

- 将宿主机入口改写为`${SERVER_PUBLIC_IP}:${SERVER_HTTP_PORT}`与`${SERVER_PUBLIC_IP}:${SERVER_HTTPS_PORT}`两条参数化映射；VPC NAT场景不再错误要求公网地址必须直接存在于宿主机网卡，并同步修正健康检查命令中的HTTP端口。
- 将本机证书脚本的权限说明从“uid 101可读”更正为实际依赖容器内gid 101组读权限，README保持简短并指向`.env.example`作为唯一详细验证口径。
- 清理固定Docker/Compose实测版本、Phase A称谓、旧标签组合、固定80/443描述及过时配置项数量，改为由部署单和`.env.example`提供实例值。
- 本轮只修改README与CHANGELOG，没有改变变量、默认值、占位符、Compose或Nginx指令，也未接触生产环境。

## 2026-09-04 说明8443占位证书与容器内组权限边界

- `.env.example`补充一种已知部署形态：TLS在上游终止、8443只绑定回环且无路由指向时，可为这两个独立部署TLS入口配置自签占位证书，不向容器开放正式私钥；该形态不影响对外服务，不能仅凭本机探测到自签证书判为故障。
- 更正证书权限说明：推荐的`root:101`与`0640`实际依赖容器内gid 101的组读权限，而非宿主机同号uid；权限结论必须在容器内以`101:101`身份验证，不能拿宿主机数字相同但主体不同的账号代替。
- 本轮只修改模板说明与CHANGELOG，没有改变变量名、默认值、占位符、Compose或Nginx运行指令，也没有接触生产环境；使用`docker compose config --quiet`验证配置结构，不输出任何环境变量值。

## 2026-08-23 存档补记（验证存档方）

- 手册九.1例行核对：IPv4字面量0处、密钥凭据形态0处、服务器绝对路径0处、二进制0处；`zhitian_admin`与`zhitian_app`均0处改动，无跨仓库误改。
- 新增的`日常验证MVP.bat`实测GBK可解码、非UTF-8、无BOM、CRLF 160/160，与既有两个批处理的编码约定完全一致——本仓批处理必须是CP936+CRLF，否则Windows CMD会把UTF-8中文注释误解析成命令。
- 本轮提交按用户决定合并，但CHANGELOG条目未合并：本仓两条、后端仓库两条，三轮跨两仓分布。
- 后端仓库同轮的存量数据结论已按生产实测更正：`enterprise_password_manual_refresh`为0行，`daily_role_headcount_snapshot`为3行且其中2行按旧UTC边界标注，切换后存在一次性口径不连续；经评估不迁移。**开发者界面的历史人数曲线在2026-08-23前后口径不同**，读图时需注意。本仓不含该表数据，此处仅作交叉引用。
- 本次未执行Docker层验证：改动为compose环境变量替换与批处理新增，未触碰Dockerfile、依赖或容器运行语义。上一轮（v3.4.2）已实测备份卷属主与写入权限，本轮不重复。

## 2026-08-23 v3.4.3：补齐保留数据的日常构建验证入口

- 新增`日常验证MVP.bat`，执行`docker compose up -d --build --force-recreate`：增量构建并强制重建容器，但不带`-v`，保留业务与备份具名卷；脚本完整复用`一键启动MVP.bat`的Docker可用性检查、`config --quiet`校验和最长约120秒健康等待逻辑。
- 构建前后分别打印`zhitian-api`、`zhitian-admin`、`zhitian-web`三个镜像ID，并明确“ID变化是重建发生的唯一凭证”；三者均未变化时给出构建上下文/缓存警告，避免把容器healthy误当作新代码已进入镜像。
- `一键启动MVP.bat`与新脚本统一补齐三个本机入口：管理后台`/`、customer网页端`/customer/`（301到`/customer/login.html`）及`/api/...`；依据Compose默认`ZHITIAN_FORCE_HTTPS=on`的真实配置，明确提示本机HTTP验收需在未跟踪`.env`中设为`off`。
- `重新构建并启动MVP.bat`与新脚本在开头互相说明适用场景：前者无缓存且会`down -v`清空数据，后者用于保留数据的日常验证。本轮不改Compose或Nginx模板、不部署。
- **真实本机验收**：Docker 29.6.2 / Compose 5.3.1下运行最终脚本，API镜像ID由`4bd070b1...`变为`fe59a063...`、管理后台由`19021dce...`变为`0075fcab...`、customer网页端由`4a00a2b9...`变为`1307e7e9...`，四服务均通过健康检查。具名卷只读计数前后均为`users=5 / documents=5 / conversations=10`；`/`返回200、`/customer/`返回301且目标为`/customer/login.html`、`/api/ready`返回200。
- 首次实跑因本机后端忽略文件`.env`尚缺另一功能轮新增的个人Key加密变量而如实失败，脚本没有误报成功；复测用一次性非秘密Compose覆盖值补齐环境，未读取、输出或修改真实凭据，验证后覆盖文件与临时回环`.env`均已删除。

## 2026-08-23 定时备份改为UTC+8每日零点触发

- Compose把旧的`SCHEDULED_BACKUP_INTERVAL_SECONDS=86400`替换为`SCHEDULED_BACKUP_LOCAL_TIME=00:00`，与后端固定时钟配置同步；时刻由后端显式按UTC+8解释，不依赖容器的UTC系统时区。
- 备份卷、保留3份、调度与手工归档前缀隔离及容器内部路径均不变；本轮不部署，生产`.env`未修改。
- 当前Codex会话的`docker`命令不在PATH，未把静态YAML审阅冒充成`docker compose config --quiet`通过；该项交由有Docker环境的验证存档方补验。

## 2026-08-23 备份卷的部署验证补记（验证存档方）

- 实施方会话无Docker CLI，把第2、3层交还验证存档方；本机Docker 29.6.2 + Compose v5.3.1可用，两层均已实跑。
- **第2层**：用全占位`.env`（回环IP、localhost主机名、相对证书路径，无真实凭据或域名）执行`docker compose config --quiet`，退出码0且无输出；按红线只用`--quiet`，全程未展开完整config。`config --volumes`列出`zhitian_data`与`zhitian_backups`两个卷，后者外部名`zhitian-mvp-backups`、挂载点`/app/backups`，与注入的`SCHEDULED_BACKUP_PATH`一致。占位`.env`验后即删。
- **第3层**：实际构建API镜像后，`/app/backups`属主为`appuser:appuser`（uid 999）；挂一个全新具名卷到该路径后属主**仍为**`appuser:appuser`，容器以`appuser`身份写入归档文件成功。「新建卷归root、非root容器写不进去」这个典型失败模式不存在。验证镜像与探针卷均已删除。
- **第4层未做**：真实部署不归验证存档方，服务器仍是v3.6，本轮不含部署；异地复制仍未具备，维持既有待办。

## 2026-08-23 独立备份卷承载进程内每日加密归档（实施方现场记录）

- `zhitian-api`新增独立具名卷`zhitian-mvp-backups`并挂载到`/app/backups`，与业务数据卷`zhitian-mvp-data`分离，避免把归档写回正在备份的数据卷；普通`docker compose down`保留两卷，`down -v`会同时删除业务数据和同机备份。
- Compose显式注入`SCHEDULED_BACKUP_ENABLED=true`、`SCHEDULED_BACKUP_PATH=/app/backups`、每日86400秒间隔与保留3份；保留数3由用户决定与另一项目保持一致，并非根据当前数据量推算。容器内部端口、反向代理、TLS模板和其他三个服务均未修改。后端镜像同步预建并授权`/app/backups`给非root `appuser`。
- 调度层复用后端既有`backup_data.py`，产物仍是可由`restore_data.py`读取的AES-256-GCM `.ztbackup`，不再维护明文快照或硬链接去重实现。自动异地复制仍未具备；手工归档可写入`/app/backups/manual`后立即导出卷外。
- **待验证边界**：实施方当前会话没有可用Docker CLI，未执行`docker compose config --quiet`、镜像构建或容器卷权限实测；这些项目必须由验证存档方在有Docker的环境补验，不能把静态配置审阅记成真实Compose通过。

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
