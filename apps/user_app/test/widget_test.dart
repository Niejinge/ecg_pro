import 'package:flutter_test/flutter_test.dart';
import 'package:user_app/main.dart';

void main() {
  testWidgets('user app shows learning home skeleton', (tester) async {
    await tester.pumpWidget(const UserApp());
    await tester.pumpAndSettle();

    expect(find.text('ECG Pro 学习端'), findsOneWidget);
    expect(find.text('示例学习案例'), findsOneWidget);
    expect(find.text('房颤与不规则心律识别'), findsOneWidget);
  });
}
