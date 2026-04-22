import 'package:ecg_ui/ecg_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('EcgScaffold and EcgSectionCard render the shared layout', (tester) async {
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
}
