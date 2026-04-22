import 'package:ecg_api/ecg_api.dart';
import 'package:ecg_core/ecg_core.dart';
import 'package:ecg_ui/ecg_ui.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const UserApp());
}

class UserApp extends StatelessWidget {
  const UserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ECG Pro',
      debugShowCheckedModeBanner: false,
      theme: EcgAppTheme.light(),
      home: const UserHomePage(),
    );
  }
}

class UserHomePage extends StatelessWidget {
  const UserHomePage({super.key});

  static const _demoCases = [
    EcgCaseSummary(
      id: 'case-001',
      title: '窦性心律基础判读',
      diagnosis: '窦性心律',
      difficulty: DifficultyLevel.beginner,
      riskLevel: RiskLevel.low,
    ),
    EcgCaseSummary(
      id: 'case-002',
      title: '房颤与不规则心律识别',
      diagnosis: '心房颤动',
      difficulty: DifficultyLevel.intermediate,
      riskLevel: RiskLevel.high,
    ),
    EcgCaseSummary(
      id: 'case-003',
      title: 'ST 段抬高型心肌梗死提示',
      diagnosis: 'STEMI',
      difficulty: DifficultyLevel.advanced,
      riskLevel: RiskLevel.critical,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    const apiClient = EcgApiClient(baseUrl: 'http://localhost:8000');

    return EcgScaffold(
      title: 'ECG Pro 学习端',
      subtitle: '一期骨架已经就绪，接下来会逐步补齐案例库、测验、错题本和学习记录。',
      actions: const [
        Padding(
          padding: EdgeInsets.only(right: AppSpacing.lg),
          child: Chip(label: Text('Web + Android')),
        ),
      ],
      child: Column(
        children: [
          EcgSectionCard(
            title: '当前已打通的主线',
            subtitle: '这一版先把平台骨架、共享主题和服务边界稳定下来。',
            child: Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: const [
                Chip(label: Text('用户端 Flutter Web')),
                Chip(label: Text('用户端 Flutter Android')),
                Chip(label: Text('共享 UI Theme')),
                Chip(label: Text('FastAPI API Skeleton')),
                Chip(label: Text('Docker Compose')),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          EcgSectionCard(
            title: '示例学习案例',
            subtitle: '后续这里会切换成真实接口和结构化案例内容。',
            trailing: Chip(
              label: Text(apiClient.buildUri('/api/v1/public/cases').path),
            ),
            child: Wrap(
              spacing: AppSpacing.lg,
              runSpacing: AppSpacing.lg,
              children: _demoCases
                  .map((item) => _CasePreviewCard(caseSummary: item))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _CasePreviewCard extends StatelessWidget {
  const _CasePreviewCard({
    required this.caseSummary,
  });

  final EcgCaseSummary caseSummary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                caseSummary.title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                caseSummary.diagnosis,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  Chip(label: Text(_difficultyLabel(caseSummary.difficulty))),
                  Chip(label: Text(_riskLabel(caseSummary.riskLevel))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _difficultyLabel(DifficultyLevel level) {
  return switch (level) {
    DifficultyLevel.beginner => '入门',
    DifficultyLevel.intermediate => '进阶',
    DifficultyLevel.advanced => '高级',
  };
}

String _riskLabel(RiskLevel level) {
  return switch (level) {
    RiskLevel.low => '低风险',
    RiskLevel.medium => '中风险',
    RiskLevel.high => '高风险',
    RiskLevel.critical => '危急',
  };
}
