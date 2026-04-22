import 'package:ecg_api/ecg_api.dart';
import 'package:ecg_ui/ecg_ui.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const AdminApp());
}

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ECG Pro Admin',
      debugShowCheckedModeBanner: false,
      theme: EcgAppTheme.light(),
      home: const AdminHomePage(),
    );
  }
}

class AdminHomePage extends StatelessWidget {
  const AdminHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    const apiClient = EcgApiClient(baseUrl: 'http://localhost:8000');
    final dashboardUri = apiClient.buildUri('/api/v1/admin/dashboard/summary');
    final loginUri = apiClient.buildUri('/api/v1/auth/login');

    return EcgScaffold(
      title: 'ECG Pro 管理端',
      subtitle: '这一版先把后台的内容管理中台、共享主题和接口边界搭起来。',
      actions: const [
        Padding(
          padding: EdgeInsets.only(right: AppSpacing.lg),
          child: Chip(label: Text('Web Admin')),
        ),
      ],
      child: Column(
        children: [
          EcgSectionCard(
            title: '一期后台模块',
            subtitle: '后续会依次填充案例管理、分类标签、题目管理和发布能力。',
            child: Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: const [
                Chip(label: Text('管理员登录')),
                Chip(label: Text('案例管理')),
                Chip(label: Text('分类标签')),
                Chip(label: Text('测验题管理')),
                Chip(label: Text('发布与下线')),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          EcgSectionCard(
            title: '后端对接占位',
            subtitle: '基础接口已经预留，接下来会逐步落认证、案例 CRUD 和图片上传。',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dashboard: $dashboardUri'),
                const SizedBox(height: AppSpacing.sm),
                Text('Login: $loginUri'),
                const SizedBox(height: AppSpacing.lg),
                const Text(
                  '当前目标是先把后台录入闭环做通，再进入用户端学习和测验闭环。',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
