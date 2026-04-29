# Linux 一键部署说明

当前生产部署默认使用本地文件系统保存心电图图片，目录由 `ECG_STORAGE_DIR` 控制。后续迁移对象存储时，只需要扩展后端 `STORAGE_BACKEND` 实现，不影响现有图片接口。

## 准备

1. 在 Linux 服务器安装 Docker 与 Docker Compose 插件。
2. 将项目代码放到服务器目录，例如 `/opt/ecg_pro`。
3. 首次运行部署脚本会生成 `.env`，需要修改其中的密码、密钥和访问域名。

```sh
sh infra/scripts/linux-deploy.sh
```

编辑 `.env` 后再次执行：

```sh
sh infra/scripts/linux-deploy.sh
```

## 关键配置

- `PUBLIC_BASE_URL`: 用户访问站点的完整地址，例如 `http://192.168.1.10` 或正式域名。
- `HTTP_PORT`: Nginx 对外端口，默认 `80`。
- `ECG_DATA_DIR`: PostgreSQL 数据目录，默认 `./data`。
- `ECG_STORAGE_DIR`: 心电图图片目录，默认 `./data/storage`。
- `SECRET_KEY`: 生产环境必须替换为足够长的随机字符串。
- `BOOTSTRAP_ADMIN_PASSWORD`: 首次启动自动创建管理员账号使用的密码。

## 服务组成

生产 Compose 文件为 `infra/docker/docker-compose.prod.yml`，包含：

- `postgres`: 数据库，数据持久化到 Linux 本地目录。
- `api`: FastAPI 服务，启动时自动等待数据库、执行迁移、初始化管理员。
- `nginx`: 构建 Flutter Web 用户端和管理端，并反向代理 `/api/`。

## 常用命令

```sh
docker compose --env-file .env -f infra/docker/docker-compose.prod.yml ps
docker compose --env-file .env -f infra/docker/docker-compose.prod.yml logs -f api
docker compose --env-file .env -f infra/docker/docker-compose.prod.yml down
```

图片文件位于 `ECG_STORAGE_DIR`，建议纳入服务器备份策略。
