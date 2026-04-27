# ECG Pro

ECG Pro 是一个面向心电图学习场景的多端平台，一期包含：

- Flutter 用户端：`Web + Android`
- Flutter 管理端：`Web`
- FastAPI 后端
- PostgreSQL 数据库
- MinIO / 本地文件存储
- Docker Compose 开发与演示环境

当前仓库已进入一期联调与演示环境收尾阶段，详细文档见：

- [需求文档](D:/projects/ecg_pro/docs/requirements.md)
- [系统架构](D:/projects/ecg_pro/docs/architecture.md)
- [开发计划](D:/projects/ecg_pro/docs/development-plan.md)
- [设计系统](D:/projects/ecg_pro/docs/design-system.md)
- [UI 工具链](D:/projects/ecg_pro/docs/ui-tooling.md)
- [演示运行手册](D:/projects/ecg_pro/docs/demo-runbook.md)

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
- 管理端案例、分类、标签、题目、图片与发布管理基础闭环
- 用户端案例浏览、详情、测验、收藏、错题与学习记录基础闭环
- `ecg_ui` 共享设计系统基础组件
- Docker Compose 基础配置与 Web 静态托管入口
- 本地统一验证、Web 构建与 Android APK 构建脚本

下一步将按计划进入：

1. Docker Compose 联调与演示环境 smoke check
2. Web 与 Android 构建稳定性验证
3. 核心页面体验修补与真实数据演示
4. 部署说明与阶段 5 测试覆盖完善

## 本地验证

运行后端、Dart package、Flutter package 与两个 Flutter 应用的分析和测试：

```powershell
.\infra\scripts\verify-all.ps1
```

如需同时验证 Web 构建：

```powershell
.\infra\scripts\verify-all.ps1 -IncludeBuilds
```

如需验证 Android debug APK 构建：

```powershell
.\infra\scripts\verify-all.ps1 -IncludeAndroidBuild
```

## 本地启动建议

### 后端依赖

启动 Docker Desktop 后，在仓库根目录准备 `.env`，可使用：

```powershell
.\infra\scripts\dev-up.ps1
```

如需快速生成演示数据，可使用：

```powershell
cd services/api
python scripts/seed_demo_data.py
```

### Web 演示构建

构建用户端和管理端 Web，并同步到 Nginx 静态目录：

```powershell
.\infra\scripts\build-web.ps1
```

随后启动 Docker 后可访问：

- 用户端：`http://localhost:8080/`
- 管理端：`http://localhost:8080/admin/`
- 健康检查：`http://localhost:8080/health`

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

Android APK 构建可使用：

```powershell
.\infra\scripts\build-android.ps1
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
