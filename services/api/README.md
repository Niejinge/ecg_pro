# ECG Pro API

FastAPI 后端服务，负责：

- 用户与管理员认证
- 心电图案例管理
- 分类与标签管理
- 测验与学习记录
- 图片上传与资源访问

当前阶段已经完成基础服务骨架和模块划分，后续将在此基础上逐步补充数据库模型、业务逻辑与接口实现。

## 当前已具备

- SQLAlchemy 数据模型骨架
- JWT 鉴权与密码哈希工具
- Alembic 迁移配置
- 默认管理员引导脚本
- 后台概览与公开案例查询服务层

## 默认管理员初始化

在完成数据库迁移后，可执行：

```powershell
cd services/api
python scripts/bootstrap_admin.py
```

脚本会根据环境变量中的 `BOOTSTRAP_ADMIN_*` 配置创建默认管理员账号与基础角色。
