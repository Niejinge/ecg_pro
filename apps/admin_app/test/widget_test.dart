import 'dart:typed_data';

import 'package:admin_app/main.dart';
import 'package:ecg_api/ecg_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('admin app shows login page before authentication', (
    tester,
  ) async {
    await tester.pumpWidget(
      AdminApp(
        repository: _FakeAdminRepository(),
        sessionStore: _MemorySessionStore(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('管理员登录'), findsOneWidget);
    expect(find.text('进入后台'), findsOneWidget);
  });

  testWidgets('admin app restores dashboard from persisted session', (
    tester,
  ) async {
    final sessionStore = _MemorySessionStore(
      initialSession: const AdminSession(
        accessToken: 'demo-token',
        expiresIn: 7200,
        user: AuthUser(
          id: 'user-1',
          username: 'admin',
          displayName: 'Admin User',
          isActive: true,
          isSuperuser: true,
          roleCodes: ['admin'],
        ),
      ),
    );
    await tester.pumpWidget(
      AdminApp(repository: _FakeAdminRepository(), sessionStore: sessionStore),
    );
    await tester.pumpAndSettle();

    expect(find.text('数据概览'), findsNWidgets(2));
    expect(find.text('案例总数'), findsOneWidget);
    expect(find.text('分类与标签'), findsOneWidget);
    expect(find.text('案例管理'), findsOneWidget);
  });

  testWidgets('admin app clears expired session on dashboard 401', (
    tester,
  ) async {
    final sessionStore = _MemorySessionStore(
      initialSession: const AdminSession(
        accessToken: 'stale-token',
        expiresIn: 7200,
        user: AuthUser(
          id: 'user-1',
          username: 'admin',
          displayName: 'Admin User',
          isActive: true,
          isSuperuser: true,
          roleCodes: ['admin'],
        ),
      ),
    );

    await tester.pumpWidget(
      AdminApp(
        repository: _UnauthorizedDashboardRepository(),
        sessionStore: sessionStore,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('管理员登录'), findsOneWidget);
    expect(await sessionStore.read(), isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin app validates restored session before dashboard loads', (
    tester,
  ) async {
    final sessionStore = _MemorySessionStore(
      initialSession: const AdminSession(
        accessToken: 'expired-token',
        expiresIn: 7200,
        user: AuthUser(
          id: 'user-1',
          username: 'admin',
          displayName: 'Admin User',
          isActive: true,
          isSuperuser: true,
          roleCodes: ['admin'],
        ),
      ),
    );
    final repository = _ExpiredRestoreRepository();

    await tester.pumpWidget(
      AdminApp(repository: repository, sessionStore: sessionStore),
    );
    await tester.pumpAndSettle();

    expect(find.text('管理员登录'), findsOneWidget);
    expect(await sessionStore.read(), isNull);
    expect(repository.dashboardCalls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('case management keeps table actions readable', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final sessionStore = _MemorySessionStore(
      initialSession: const AdminSession(
        accessToken: 'demo-token',
        expiresIn: 7200,
        user: AuthUser(
          id: 'user-1',
          username: 'admin',
          displayName: 'Admin User',
          isActive: true,
          isSuperuser: true,
          roleCodes: ['admin'],
        ),
      ),
    );

    await tester.pumpWidget(
      AdminApp(repository: _FakeAdminRepository(), sessionStore: sessionStore),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('案例管理'));
    await tester.pumpAndSettle();

    expect(find.text('案例列表'), findsOneWidget);
    expect(find.text('编辑'), findsOneWidget);
    expect(find.text('下线'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('taxonomy tables use compact action menus', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final sessionStore = _MemorySessionStore(
      initialSession: const AdminSession(
        accessToken: 'demo-token',
        expiresIn: 7200,
        user: AuthUser(
          id: 'user-1',
          username: 'admin',
          displayName: 'Admin User',
          isActive: true,
          isSuperuser: true,
          roleCodes: ['admin'],
        ),
      ),
    );

    await tester.pumpWidget(
      AdminApp(repository: _FakeAdminRepository(), sessionStore: sessionStore),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('分类与标签'));
    await tester.pumpAndSettle();

    expect(find.text('分类管理'), findsOneWidget);
    expect(find.text('标签管理'), findsOneWidget);
    expect(find.text('操作'), findsWidgets);

    await tester.tap(find.text('操作').at(1));
    await tester.pumpAndSettle();

    expect(find.text('编辑'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _UnauthorizedDashboardRepository extends _FakeAdminRepository {
  @override
  Future<DashboardSummary> fetchDashboardSummary(AdminSession session) async {
    throw const EcgApiException(message: 'invalid token', statusCode: 401);
  }
}

class _ExpiredRestoreRepository extends _FakeAdminRepository {
  int dashboardCalls = 0;

  @override
  Future<AuthUser> fetchCurrentUser(AdminSession session) async {
    throw const EcgApiException(
      message: 'Invalid or expired token.',
      statusCode: 401,
    );
  }

  @override
  Future<DashboardSummary> fetchDashboardSummary(AdminSession session) async {
    dashboardCalls += 1;
    return super.fetchDashboardSummary(session);
  }
}

class _MemorySessionStore implements AdminSessionStore {
  _MemorySessionStore({AdminSession? initialSession})
    : _session = initialSession;

  AdminSession? _session;

  @override
  Future<void> clear() async {
    _session = null;
  }

  @override
  Future<AdminSession?> read() async {
    return _session;
  }

  @override
  Future<void> write(AdminSession session) async {
    _session = session;
  }
}

class _FakeAdminRepository implements AdminRepository {
  @override
  Future<AdminSession> login({
    required String username,
    required String password,
  }) async {
    return const AdminSession(
      accessToken: 'demo-token',
      expiresIn: 7200,
      user: AuthUser(
        id: 'user-1',
        username: 'admin',
        displayName: 'Admin User',
        isActive: true,
        isSuperuser: true,
        roleCodes: ['admin'],
      ),
    );
  }

  @override
  Future<AuthUser> fetchCurrentUser(AdminSession session) async {
    return session.user;
  }

  @override
  Future<CaseDetailItem> createCase(
    AdminSession session,
    AdminCaseUpsertInput input,
  ) async {
    return _caseDetail;
  }

  @override
  Future<CategoryItem> createCategory(
    AdminSession session,
    CategoryUpsertInput input,
  ) async {
    return const CategoryItem(
      id: 'cat-1',
      name: '快速性心律失常',
      slug: 'tachy',
      description: null,
      sortOrder: 1,
      isVisible: true,
      parentId: null,
    );
  }

  @override
  Future<AdminQuizQuestionItem> createQuestion(
    AdminSession session,
    String caseId,
    AdminQuizQuestionUpsertInput input,
  ) async {
    return _questions.first;
  }

  @override
  Future<TagItem> createTag(AdminSession session, TagUpsertInput input) async {
    return const TagItem(
      id: 'tag-1',
      name: '高危',
      slug: 'high-risk',
      description: null,
    );
  }

  @override
  Future<void> deleteCase(AdminSession session, String caseId) async {}

  @override
  Future<void> deleteCaseImage(AdminSession session, String imageId) async {}

  @override
  Future<void> deleteCategory(AdminSession session, String categoryId) async {}

  @override
  Future<void> deleteQuestion(AdminSession session, String questionId) async {}

  @override
  Future<void> deleteTag(AdminSession session, String tagId) async {}

  @override
  Future<List<CategoryItem>> fetchCategories(AdminSession session) async {
    return const [
      CategoryItem(
        id: 'cat-1',
        name: '快速性心律失常',
        slug: 'tachy',
        description: null,
        sortOrder: 1,
        isVisible: true,
        parentId: null,
      ),
    ];
  }

  @override
  Future<CaseDetailItem> fetchCaseDetail(
    AdminSession session,
    String caseId,
  ) async {
    return _caseDetail;
  }

  @override
  Future<AdminCaseListResponse> fetchCases(
    AdminSession session, {
    String? keyword,
    String? categoryId,
    String? tagId,
    DifficultyLevel? difficulty,
    RiskLevel? riskLevel,
    CaseStatus? status,
    bool? isFeatured,
    int page = 1,
    int pageSize = 20,
  }) async {
    return AdminCaseListResponse(
      items: [
        AdminCaseListItem(
          id: 'case-1',
          caseCode: 'ECG-001',
          title: '房颤识别',
          diagnosis: '心房颤动',
          difficulty: DifficultyLevel.intermediate,
          riskLevel: RiskLevel.high,
          categoryName: '快速性心律失常',
          status: CaseStatus.published,
          isFeatured: true,
          updatedAt: DateTime(2026, 4, 26, 12),
        ),
      ],
      total: 1,
      page: page,
      pageSize: pageSize,
      hasNext: false,
    );
  }

  @override
  Future<DashboardSummary> fetchDashboardSummary(AdminSession session) async {
    return const DashboardSummary(
      totalCases: 4,
      publishedCases: 3,
      totalQuestions: 8,
      totalUsers: 2,
    );
  }

  @override
  Future<List<AdminQuizQuestionItem>> fetchQuestions(
    AdminSession session,
    String caseId,
  ) async {
    return _questions;
  }

  @override
  Future<List<TagItem>> fetchTags(AdminSession session) async {
    return const [
      TagItem(
        id: 'tag-1',
        name: '高危',
        slug: 'high-risk',
        description: '需要重点关注',
      ),
    ];
  }

  @override
  Future<CaseDetailItem> offlineCase(
    AdminSession session,
    String caseId,
  ) async {
    return _caseDetail;
  }

  @override
  Future<CaseDetailItem> publishCase(
    AdminSession session,
    String caseId,
  ) async {
    return _caseDetail;
  }

  @override
  Future<List<UploadedImageItem>> reorderCaseImages(
    AdminSession session, {
    required String caseId,
    required List<ReorderCaseImageItemInput> items,
  }) async {
    return const [];
  }

  @override
  Future<CaseDetailItem> updateCase(
    AdminSession session,
    String caseId,
    AdminCaseUpsertInput input,
  ) async {
    return _caseDetail;
  }

  @override
  Future<UploadedImageItem> updateCaseImage(
    AdminSession session,
    String imageId,
    UpdateCaseImageInput input,
  ) async {
    return const UploadedImageItem(
      id: 'img-1',
      caseId: 'case-1',
      fileName: 'ecg.png',
      fileUrl: 'https://example.com/ecg.png',
      contentType: 'image/png',
      isPrimary: true,
      sortOrder: 0,
    );
  }

  @override
  Future<CategoryItem> updateCategory(
    AdminSession session,
    String categoryId,
    CategoryUpsertInput input,
  ) async {
    return const CategoryItem(
      id: 'cat-1',
      name: '快速性心律失常',
      slug: 'tachy',
      description: null,
      sortOrder: 1,
      isVisible: true,
      parentId: null,
    );
  }

  @override
  Future<AdminQuizQuestionItem> updateQuestion(
    AdminSession session,
    String questionId,
    AdminQuizQuestionUpsertInput input,
  ) async {
    return _questions.first;
  }

  @override
  Future<TagItem> updateTag(
    AdminSession session,
    String tagId,
    TagUpsertInput input,
  ) async {
    return const TagItem(
      id: 'tag-1',
      name: '高危',
      slug: 'high-risk',
      description: '需要重点关注',
    );
  }

  @override
  Future<UploadedImageItem> uploadCaseImage(
    AdminSession session, {
    required String caseId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    bool isPrimary = false,
    int sortOrder = 0,
  }) async {
    return const UploadedImageItem(
      id: 'img-1',
      caseId: 'case-1',
      fileName: 'ecg.png',
      fileUrl: 'https://example.com/ecg.png',
      contentType: 'image/png',
      isPrimary: true,
      sortOrder: 0,
    );
  }
}

final _caseDetail = CaseDetailItem(
  id: 'case-1',
  caseCode: 'ECG-001',
  title: '房颤识别',
  summary: '测试摘要',
  diagnosis: '心房颤动',
  rhythmType: '不规则快速心律',
  heartRate: '145 bpm',
  axisDescription: '电轴正常',
  prDescription: null,
  qrsDescription: 'QRS 窄',
  stTDescription: null,
  qtDescription: null,
  keyLeads: ['II', 'V1'],
  clinicalSignificance: '测试用临床意义',
  differentialDiagnosis: '房扑',
  treatmentPlan: '控制心率',
  urgentActions: '评估稳定性',
  followUpRecommendations: '抗凝评估',
  detailedDescription: '详细描述',
  interpretationSteps: ['看节律'],
  learningPoints: ['绝对不规则'],
  commonMistakes: ['误判为房扑'],
  memoryTips: ['先看 RR'],
  difficulty: DifficultyLevel.intermediate,
  riskLevel: RiskLevel.high,
  status: CaseStatus.published,
  isFeatured: true,
  publishedAt: null,
  category: CaseCategorySummary(id: 'cat-1', name: '快速性心律失常', slug: 'tachy'),
  tags: [CaseTagSummary(id: 'tag-1', name: '高危', slug: 'high-risk')],
  images: [],
  createdBy: 'user-1',
  createdAt: DateTime(2026, 4, 26, 12),
  updatedAt: DateTime(2026, 4, 26, 12),
);

final _questions = [
  AdminQuizQuestionItem(
    id: 'question-1',
    caseId: 'case-1',
    stem: '房颤最典型特征是什么？',
    explanation: 'RR 间期绝对不规则。',
    questionType: QuestionType.singleChoice,
    difficulty: DifficultyLevel.beginner,
    sortOrder: 1,
    isActive: true,
    options: [
      AdminQuizOptionItem(
        id: 'option-1',
        label: 'A',
        content: '绝对不规则 RR 间期',
        isCorrect: true,
        sortOrder: 1,
      ),
      AdminQuizOptionItem(
        id: 'option-2',
        label: 'B',
        content: '固定 PR 延长',
        isCorrect: false,
        sortOrder: 2,
      ),
    ],
  ),
];
