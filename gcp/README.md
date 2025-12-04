# GCP 部署指南

本目录包含将 sora2api 部署到 Google Cloud Platform 的脚本和配置。

## 架构

```
┌─────────────────────────────────────────────┐
│           GCP Compute Engine                │
│  ┌───────────────────────────────────────┐  │
│  │          Docker Compose               │  │
│  │  ┌─────────────┐  ┌─────────────────┐ │  │
│  │  │  sora2api   │──│  WARP Proxy     │ │  │
│  │  │  :8000      │  │  :1080          │ │  │
│  │  └─────────────┘  └─────────────────┘ │  │
│  └───────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
```

- **sora2api**: 主服务，提供 OpenAI 兼容 API
- **WARP**: Cloudflare WARP 代理，用于访问 Sora API

## 前置要求

1. 安装 [gcloud CLI](https://cloud.google.com/sdk/docs/install)
2. 配置 GCP 项目和认证
3. 启用 Compute Engine API

```bash
# 认证
gcloud auth login

# 设置项目
gcloud config set project YOUR_PROJECT_ID
```

## 快速部署

```bash
# 1. 部署 VM
./deploy.sh --project YOUR_PROJECT_ID

# 2. 等待 2-3 分钟让服务启动

# 3. 查看服务状态
./operations.sh status

# 4. 获取 IP 地址
./operations.sh ip
```

## 脚本说明

### deploy.sh - 部署脚本

创建 GCP Compute Engine 实例并安装 sora2api。

```bash
./deploy.sh [options]

Options:
  --project PROJECT_ID       GCP 项目 ID
  --zone ZONE                区域 (默认: us-central1-a)
  --machine-type TYPE        机器类型 (默认: e2-small)
  --instance-name NAME       实例名称 (默认: sora2api-vm)
  --service-account-key FILE 服务账号密钥文件路径
```

### operations.sh - 运维脚本

管理已部署的 sora2api 服务。

```bash
./operations.sh <command>

Commands:
  ssh              SSH 登录到 VM
  logs [service]   查看日志 (sora2api 或 warp)
  restart          重启所有服务
  update           更新 Docker 镜像
  code-update      从 GitHub 拉取最新代码并重启
  backup           备份数据和配置
  status           查看服务状态
  ip               查看外部 IP 地址
  config           编辑配置文件
  stop             停止服务
  start            启动服务
```

### startup-script.sh - 启动脚本

VM 首次启动时自动执行，安装 Docker 和部署服务。

## 部署后配置

### 1. 修改 API Key

```bash
./operations.sh config
```

修改 `api_key` 字段，然后保存并重启服务。

### 2. 添加 Sora Token

访问管理面板：`http://YOUR_IP:8000`

使用默认凭据登录：
- 用户名: `admin`
- 密码: `admin`

在 Token 管理页面添加你的 Sora Access Token。

### 3. 配置代理 (已自动配置)

WARP 代理已预配置在 `socks5://warp:1080`。

## 更新代码

当有新功能或修复时：

```bash
# 方式一：使用运维脚本
./operations.sh code-update

# 方式二：手动更新
./operations.sh ssh
cd /opt/sora2api/repo
sudo git pull
cd /opt/sora2api
sudo docker compose restart sora2api
```

## 监控与日志

```bash
# 查看所有日志
./operations.sh logs

# 仅查看 sora2api 日志
./operations.sh logs sora2api

# 查看 WARP 代理日志
./operations.sh logs warp

# 查看服务状态和资源使用
./operations.sh status
```

## 备份与恢复

```bash
# 创建备份
./operations.sh backup
# 备份文件保存在 ./backups/ 目录

# 恢复配置
gcloud compute scp backups/sora2api_backup_XXXXXX_setting.toml \
    sora2api-vm:/opt/sora2api/config/setting.toml --zone=us-central1-a
```

## 费用估算

| 资源 | 配置 | 月费用 (估算) |
|------|------|---------------|
| Compute Engine | e2-small | ~$15 |
| 磁盘 | 20GB pd-balanced | ~$2 |
| 网络出口 | 按使用量 | 变动 |

总计约 **$17-25/月**（不含网络出口流量）。

## 安全建议

1. **修改默认密码**: 部署后立即修改 API key 和 admin 密码
2. **限制 IP 访问**: 配置防火墙规则限制来源 IP
3. **启用 HTTPS**: 使用负载均衡器或 nginx 配置 SSL
4. **定期备份**: 使用 `./operations.sh backup` 定期备份

## 故障排除

### 服务无法启动

```bash
# 检查 Docker 状态
./operations.sh ssh
sudo systemctl status docker
sudo docker compose logs
```

### WARP 代理不工作

```bash
# 检查 WARP 健康状态
./operations.sh logs warp
./operations.sh ssh
curl --socks5 localhost:1080 https://www.cloudflare.com/cdn-cgi/trace
```

### API 返回 401

确认 API key 配置正确：
```bash
./operations.sh config
# 检查 [global] 下的 api_key 配置
```

## 文件结构

```
/opt/sora2api/
├── config/
│   └── setting.toml    # 配置文件
├── data/
│   └── hancat.db       # SQLite 数据库
├── repo/               # Git 仓库 (代码更新)
│   └── src/            # 源代码 (挂载到容器)
├── warp-data/          # WARP 持久化数据
└── docker-compose.yml  # Docker 编排文件
```
