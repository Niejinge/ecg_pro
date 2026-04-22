import 'package:admin_app/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('admin app shows management home skeleton', (tester) async {
    await tester.pumpWidget(const AdminApp());
    await tester.pumpAndSettle();

    expect(find.text('ECG Pro 管理端'), findsOneWidget);
    expect(find.text('一期后台模块'), findsOneWidget);
    expect(find.text('案例管理'), findsOneWidget);
  });
}
