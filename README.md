# ECG Pro

ECG Pro 是一个面向心电图学习场景的多端平台，一期包含：

- Flutter 用户端：`Web + Android`
- Flutter 管理端：`Web`
- FastAPI 后端
- PostgreSQL 数据库
- MinIO / 本地文件存储
- Docker Compose 开发与演示环境

当前仓库已完成一期前两阶段的基础能力建设，详细文档见：

- [需求文档](D:/projects/ecg_pro/docs/requirements.md)
- [系统架构](D:/projects/ecg_pro/docs/architecture.md)
- [开发计划](D:/projects/ecg_pro/docs/development-plan.md)

## 目录结构

```text
apps/
  admin_app/      Flutter 管理端
  user_app/       Flutter 用户端
packages/
  ecg_api/        API 客户端与请求封装
  ecg_core/       公共模型与枚举
  ecg_ui/         共享 UI 组件与主题
services/
  api/            FastAPI 服务
infra/
  docker/         Docker Compose 与镜像配置
  nginx/          Nginx 路由与占位静态资源
  scripts/        本地辅助脚本
docs/
  *.md            产品、架构、计划文档
```

## 当前阶段

当前完成内容：

- Monorepo 目录初始化
- Flutter 用户端与管理端脚手架
- 共享 package 骨架
- FastAPI 服务入口与模块划分
- 后端认证、案例管理、分类标签、测验、学习记录与图片管理接口
- 案例筛选分页、答题历史查询与演示种子数据脚本
- Docker Compose 基础配置

下一步将按计划进入：

1. 管理端案例管理页面接入真实接口
2. 用户端学习页、详情页与测验页闭环
3. 共享 UI 组件库增强
4. Docker 联调与部署体验完善

## 本地启动建议

### 后端依赖

在仓库根目录准备 `.env` 后，可使用：

```powershell
docker compose -f infra/docker/docker-compose.yml up --build
```

如需快速生成演示数据，可使用：

```powershell
cd services/api
python scripts/seed_demo_data.py
```

### Flutter 用户端

```powershell
cd apps/user_app
flutter run -d chrome
```

Android 调试可使用：

```powershell
cd apps/user_app
flutter run -d android
```

### Flutter 管理端

```powershell
cd apps/admin_app
flutter run -d chrome
```

## 说明

- Docker 统一维护后端、数据库、对象存储和 Web 托管。
- Android 客户端通过 Flutter 构建 `APK/AAB`，不作为容器运行。
- 当前仓库已具备一期后端基础业务能力，前端页面与接口联调将在后续迭代中逐步补齐。
