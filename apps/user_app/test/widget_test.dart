import 'package:ecg_api/ecg_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_app/main.dart';

void main() {
  testWidgets('user app renders public cases and opens detail', (tester) async {
    await tester.pumpWidget(UserApp(repository: _FakeUserRepository()));
    await tester.pumpAndSettle();

    expect(find.text('ECG Pro 学习端'), findsOneWidget);
    expect(find.text('示例学习案例'), findsOneWidget);
    expect(find.text('房颤与不规则心律识别'), findsOneWidget);

    await tester.ensureVisible(find.text('房颤与不规则心律识别'));
    await tester.tap(find.text('房颤与不规则心律识别'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 20));
    await tester.pumpAndSettle();

    expect(find.text('案例概览'), findsOneWidget);
  });
}

class _FakeUserRepository implements UserRepository {
  @override
  Future<List<CategoryItem>> fetchCategories() async {
    return const [
      CategoryItem(
        id: 'category-arrhythmia',
        name: '心律失常',
        slug: 'arrhythmia',
        description: '节律相关案例',
        sortOrder: 1,
        isVisible: true,
        parentId: null,
      ),
    ];
  }

  @override
  Future<CaseDetailItem> fetchCaseDetail(String caseId) async {
    return CaseDetailItem(
      id: caseId,
      caseCode: 'ECG-001',
      title: '房颤与不规则心律识别',
      summary: '通过 RR 间期和 P 波特征识别房颤伴快速心室率。',
      diagnosis: '房颤伴快速心室率',
      rhythmType: '不规则绝对不齐',
      heartRate: '148 bpm',
      axisDescription: '电轴大致正常',
      prDescription: null,
      qrsDescription: 'QRS 波群窄',
      stTDescription: '可见轻度继发性改变',
      qtDescription: 'QTc 轻度缩短',
      keyLeads: const ['II', 'V1', 'V5'],
      clinicalSignificance: '提示需要结合血流动力学状态评估。',
      differentialDiagnosis: '房扑伴可变传导、频发房早',
      treatmentPlan: '控制心室率，必要时抗凝评估。',
      urgentActions: '若伴低血压或胸痛需优先评估同步电复律。',
      followUpRecommendations: '完善超声心动图和 CHA2DS2-VASc 评估。',
      detailedDescription: 'P 波消失，基线可见细小纤颤波，RR 间期绝对不规则。',
      interpretationSteps: const ['先看节律是否规则', '再找 P 波是否存在'],
      learningPoints: const ['不规则绝对不齐高度提示房颤', 'V1 导联更容易看见纤颤波'],
      commonMistakes: const ['把频发房早误判为房颤'],
      memoryTips: const ['看到不规则绝对不齐，先想房颤'],
      difficulty: DifficultyLevel.beginner,
      riskLevel: RiskLevel.medium,
      status: CaseStatus.published,
      isFeatured: true,
      publishedAt: DateTime(2026, 4, 27),
      category: const CaseCategorySummary(
        id: 'category-arrhythmia',
        name: '心律失常',
        slug: 'arrhythmia',
      ),
      tags: const [
        CaseTagSummary(id: 'tag-af', name: '房颤', slug: 'atrial-fibrillation'),
      ],
      images: const [],
      createdBy: 'system',
      createdAt: DateTime(2026, 4, 27),
      updatedAt: DateTime(2026, 4, 27),
    );
  }

  @override
  Future<PublicCaseListResponse> fetchCases({
    String? keyword,
    String? categoryId,
    DifficultyLevel? difficulty,
    RiskLevel? riskLevel,
    bool? isFeatured,
    int page = 1,
    int pageSize = 20,
  }) async {
    return const PublicCaseListResponse(
      items: [
        PublicCaseListItem(
          id: 'case-001',
          caseCode: 'ECG-001',
          title: '房颤与不规则心律识别',
          diagnosis: '房颤伴快速心室率',
          difficulty: DifficultyLevel.beginner,
          riskLevel: RiskLevel.medium,
          categoryName: '心律失常',
        ),
      ],
      total: 1,
      page: 1,
      pageSize: 20,
      hasNext: false,
    );
  }
}
