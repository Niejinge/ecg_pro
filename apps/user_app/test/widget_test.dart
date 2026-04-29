import 'package:ecg_api/ecg_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:user_app/main.dart';

void main() {
  testWidgets('guest user can load public case list', (tester) async {
    final repository = _FakeUserRepository();

    await tester.pumpWidget(
      UserApp(repository: repository, sessionStore: _MemoryUserSessionStore()),
    );
    await tester.pumpAndSettle();

    expect(find.text('游客模式可浏览'), findsOneWidget);
    expect(find.text('快速开始'), findsOneWidget);
    expect(find.text('公开案例库'), findsOneWidget);
    expect(repository.fetchCaseFeaturedFilters.single, isNull);
    expect(find.text('学习内容加载失败，请检查接口服务是否可用。'), findsNothing);
    expect(find.text('进入案例'), findsOneWidget);
  });

  testWidgets('user can browse case list and detail page', (tester) async {
    await tester.pumpWidget(
      UserApp(
        repository: _FakeUserRepository(),
        sessionStore: _MemoryUserSessionStore(),
        initialSession: const UserSession(
          accessToken: 'demo-token',
          expiresIn: 7200,
          user: AuthUser(
            id: 'user-1',
            username: 'learner',
            displayName: '学习用户',
            isActive: true,
            isSuperuser: false,
            roleCodes: ['learner'],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('ECG Pro 学习端'), findsOneWidget);
    expect(find.text('公开案例库'), findsOneWidget);
    expect(find.text('已登录学习模式'), findsOneWidget);
    expect(find.text('退出登录'), findsOneWidget);
    expect(find.text('进入案例'), findsOneWidget);

    await tester.ensureVisible(find.text('进入案例'));
    await tester.tap(find.text('进入案例'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.text('案例详情'), findsOneWidget);
    expect(find.text('开始测验 (1 题)'), findsOneWidget);
    expect(find.text('学习要点'), findsOneWidget);
  });

  testWidgets('signed in user sees progress overview', (tester) async {
    await tester.pumpWidget(
      UserApp(
        repository: _FakeUserRepository(),
        sessionStore: _MemoryUserSessionStore(),
        initialSession: const UserSession(
          accessToken: 'demo-token',
          expiresIn: 7200,
          user: AuthUser(
            id: 'user-1',
            username: 'learner',
            displayName: '学习用户',
            isActive: true,
            isSuperuser: false,
            roleCodes: ['learner'],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.text('已登录学习模式'), findsOneWidget);
    expect(find.text('学习用户'), findsOneWidget);
    expect(find.text('最近浏览'), findsOneWidget);
    expect(find.text('继续学习'), findsWidgets);
    expect(find.text('复习案例'), findsOneWidget);
    expect(find.text('错题数'), findsOneWidget);
  });

  testWidgets('signed in user can switch public case pages', (tester) async {
    await tester.pumpWidget(
      UserApp(
        repository: _FakeUserRepository(),
        sessionStore: _MemoryUserSessionStore(),
        initialSession: const UserSession(
          accessToken: 'demo-token',
          expiresIn: 7200,
          user: AuthUser(
            id: 'user-1',
            username: 'learner',
            displayName: '学习用户',
            isActive: true,
            isSuperuser: false,
            roleCodes: ['learner'],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('第 1 页'), findsOneWidget);
    expect(find.text('下一页'), findsOneWidget);

    await tester.ensureVisible(find.text('下一页'));
    await tester.tap(find.text('下一页'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));

    expect(find.text('第 2 页'), findsOneWidget);
    expect(find.text('上一页'), findsOneWidget);
  });

  testWidgets('signed in user can start quiz from home shortcut', (
    tester,
  ) async {
    await tester.pumpWidget(
      UserApp(
        repository: _FakeUserRepository(),
        sessionStore: _MemoryUserSessionStore(),
        initialSession: const UserSession(
          accessToken: 'demo-token',
          expiresIn: 7200,
          user: AuthUser(
            id: 'user-1',
            username: 'learner',
            displayName: '学习用户',
            isActive: true,
            isSuperuser: false,
            roleCodes: ['learner'],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final startQuiz = find.text('进入测验');
    await tester.ensureVisible(startQuiz);
    await tester.tap(startQuiz);
    await tester.pumpAndSettle();

    expect(find.text('案例测验'), findsOneWidget);
    expect(find.text('共 1 题，提交后将记录本次成绩与错题。'), findsOneWidget);
  });

  testWidgets('home category shortcuts support long names', (tester) async {
    const longCategoryName = '临床心电图全解：案例分析与学习精要（原书第二版）';

    await tester.pumpWidget(
      UserApp(
        repository: _FakeUserRepository(
          categories: [
            CategoryItem(
              id: 'category-long-book',
              name: longCategoryName,
              slug: 'long-book',
              description: '长书名分类',
              sortOrder: 1,
              isVisible: true,
              parentId: null,
            ),
          ],
        ),
        sessionStore: _MemoryUserSessionStore(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(longCategoryName), findsOneWidget);
  });

  testWidgets('signed in user can submit quiz and open result page', (
    tester,
  ) async {
    await tester.pumpWidget(
      UserApp(
        repository: _FakeUserRepository(),
        sessionStore: _MemoryUserSessionStore(),
        initialSession: const UserSession(
          accessToken: 'demo-token',
          expiresIn: 7200,
          user: AuthUser(
            id: 'user-1',
            username: 'learner',
            displayName: '学习用户',
            isActive: true,
            isSuperuser: false,
            roleCodes: ['learner'],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final enterCase = find.text('进入案例');
    await tester.ensureVisible(enterCase);
    await tester.tap(enterCase);
    await tester.pumpAndSettle();

    await tester.tap(find.text('开始测验 (1 题)'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('A. 房颤'));
    await tester.pump();
    await tester.tap(find.text('提交测验'));
    await tester.pumpAndSettle();

    expect(find.text('测验结果'), findsOneWidget);
    expect(find.text('逐题解析'), findsOneWidget);
    expect(find.text('回答正确'), findsOneWidget);
  });
}

class _MemoryUserSessionStore implements UserSessionStore {
  _MemoryUserSessionStore();

  UserSession? session;

  @override
  Future<void> clear() async {
    session = null;
  }

  @override
  Future<UserSession?> read() async => session;

  @override
  Future<void> write(UserSession nextSession) async {
    session = nextSession;
  }
}

class _FakeUserRepository implements UserRepository {
  _FakeUserRepository({List<CategoryItem>? categories})
    : _categories = categories ?? _defaultCategories;

  static const _defaultCategories = [
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

  final List<CategoryItem> _categories;
  final List<bool?> fetchCaseFeaturedFilters = [];

  @override
  Future<FavoriteItem> addFavorite(UserSession session, String caseId) async {
    return const FavoriteItem(
      caseId: 'case-001',
      caseCode: 'ECG-001',
      title: '房颤与不规则心律识别',
      diagnosis: '房颤伴快速心室率',
    );
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
  Future<List<CategoryItem>> fetchCategories() async {
    return _categories;
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
    fetchCaseFeaturedFilters.add(isFeatured);

    if (page == 2) {
      return const PublicCaseListResponse(
        items: [
          PublicCaseListItem(
            id: 'case-002',
            caseCode: 'ECG-002',
            title: '室速与宽QRS鉴别',
            diagnosis: '单形性室速',
            difficulty: DifficultyLevel.intermediate,
            riskLevel: RiskLevel.high,
            categoryName: '快速性心律失常',
          ),
        ],
        total: 2,
        page: 2,
        pageSize: 20,
        hasNext: false,
      );
    }

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
      total: 2,
      page: 1,
      pageSize: 20,
      hasNext: true,
    );
  }

  @override
  Future<List<FavoriteItem>> fetchFavorites(UserSession session) async {
    return const [
      FavoriteItem(
        caseId: 'case-001',
        caseCode: 'ECG-001',
        title: '房颤与不规则心律识别',
        diagnosis: '房颤伴快速心室率',
      ),
    ];
  }

  @override
  Future<List<LearningProgressItem>> fetchLearningProgress(
    UserSession session,
  ) async {
    return [
      LearningProgressItem(
        caseId: 'case-002',
        caseCode: 'ECG-002',
        title: '室速与宽QRS鉴别',
        diagnosis: '单形性室速',
        status: LearningStatus.inProgress,
        completionRate: 60,
        bestScore: 80,
        lastViewedAt: DateTime(2026, 4, 28),
      ),
      LearningProgressItem(
        caseId: 'case-001',
        caseCode: 'ECG-001',
        title: '房颤与不规则心律识别',
        diagnosis: '房颤伴快速心室率',
        status: LearningStatus.completed,
        completionRate: 100,
        bestScore: 100,
        lastViewedAt: DateTime(2026, 4, 27),
      ),
    ];
  }

  @override
  Future<List<PublicQuizQuestionItem>> fetchQuizQuestions(String caseId) async {
    return const [
      PublicQuizQuestionItem(
        id: 'question-001',
        stem: '该心电图最符合哪种节律？',
        questionType: QuestionType.singleChoice,
        difficulty: DifficultyLevel.beginner,
        sortOrder: 0,
        options: [
          PublicQuizOptionItem(
            id: 'option-a',
            label: 'A',
            content: '房颤',
            sortOrder: 0,
          ),
          PublicQuizOptionItem(
            id: 'option-b',
            label: 'B',
            content: '窦性心律',
            sortOrder: 1,
          ),
        ],
      ),
    ];
  }

  @override
  Future<List<WrongQuestionItem>> fetchWrongQuestions(
    UserSession session,
  ) async {
    return const [
      WrongQuestionItem(
        questionId: 'question-001',
        caseId: 'case-001',
        caseCode: 'ECG-001',
        caseTitle: '房颤与不规则心律识别',
        stem: '该心电图最符合哪种节律？',
        wrongCount: 1,
        lastWrongAt: null,
      ),
    ];
  }

  @override
  Future<UserSession> login({
    required String username,
    required String password,
  }) async {
    return const UserSession(
      accessToken: 'demo-token',
      expiresIn: 7200,
      user: AuthUser(
        id: 'user-1',
        username: 'learner',
        displayName: '学习用户',
        isActive: true,
        isSuperuser: false,
        roleCodes: ['learner'],
      ),
    );
  }

  @override
  Future<LearningProgressItem> markCaseViewed(
    UserSession session,
    String caseId,
  ) async {
    return LearningProgressItem(
      caseId: caseId,
      caseCode: 'ECG-001',
      title: '房颤与不规则心律识别',
      diagnosis: '房颤伴快速心室率',
      status: LearningStatus.inProgress,
      completionRate: 50,
      bestScore: 80,
      lastViewedAt: DateTime(2026, 4, 27),
    );
  }

  @override
  Future<void> removeFavorite(UserSession session, String caseId) async {}

  @override
  Future<QuizSubmissionResponse> submitQuiz(
    UserSession session,
    QuizSubmissionInput input,
  ) async {
    return const QuizSubmissionResponse(
      attemptId: 'attempt-001',
      caseId: 'case-001',
      score: 100,
      totalQuestions: 1,
      correctCount: 1,
      items: [
        QuizSubmissionResultItem(
          questionId: 'question-001',
          selectedOptionIds: ['option-a'],
          correctOptionIds: ['option-a'],
          isCorrect: true,
          explanation: '房颤的 RR 间期绝对不规则。',
        ),
      ],
    );
  }
}
