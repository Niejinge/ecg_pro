import '../enums/difficulty_level.dart';
import '../enums/risk_level.dart';

class EcgCaseSummary {
  const EcgCaseSummary({
    required this.id,
    required this.title,
    required this.diagnosis,
    required this.difficulty,
    required this.riskLevel,
  });

  final String id;
  final String title;
  final String diagnosis;
  final DifficultyLevel difficulty;
  final RiskLevel riskLevel;
}

