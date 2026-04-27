import 'package:ecg_ui/ecg_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('EcgScaffold and EcgSectionCard render the shared layout', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: EcgAppTheme.light(),
        home: const EcgScaffold(
          title: '测试标题',
          subtitle: '测试副标题',
          child: EcgSectionCard(
            title: '卡片标题',
            subtitle: '卡片副标题',
            child: Text('卡片内容'),
          ),
        ),
      ),
    );

    expect(find.text('测试标题'), findsOneWidget);
    expect(find.text('测试副标题'), findsOneWidget);
    expect(find.text('卡片标题'), findsOneWidget);
    expect(find.text('卡片内容'), findsOneWidget);
  });

  testWidgets('shared learning primitives render core content', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: EcgAppTheme.light(),
        home: Scaffold(
          body: Column(
            children: [
              const EcgBadge(
                label: '中风险',
                color: AppColors.warning,
                icon: Icons.warning_rounded,
              ),
              const EcgMetricCard(
                label: '已完成案例',
                value: '12',
                icon: Icons.check_circle_rounded,
                supportingText: '本周新增 3 个',
              ),
              EcgActionCard(
                title: '房颤识别',
                subtitle: '继续完成测验',
                actionLabel: '继续学习',
                icon: Icons.timeline_rounded,
                onPressed: () {},
              ),
              const EcgEmptyState(title: '暂无案例', message: '换个筛选条件再试试。'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('中风险'), findsOneWidget);
    expect(find.text('已完成案例'), findsOneWidget);
    expect(find.text('本周新增 3 个'), findsOneWidget);
    expect(find.text('房颤识别'), findsOneWidget);
    expect(find.text('暂无案例'), findsOneWidget);
  });
}
