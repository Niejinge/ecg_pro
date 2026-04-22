import 'package:ecg_core/ecg_core.dart';
import 'package:test/test.dart';

void main() {
  test('EcgCaseSummary keeps structured learning metadata', () {
    const summary = EcgCaseSummary(
      id: 'case-1',
      title: '窦性心律基础判读',
      diagnosis: '窦性心律',
      difficulty: DifficultyLevel.beginner,
      riskLevel: RiskLevel.low,
    );

    expect(summary.id, 'case-1');
    expect(summary.title, contains('窦性心律'));
    expect(summary.difficulty, DifficultyLevel.beginner);
    expect(summary.riskLevel, RiskLevel.low);
  });
}
