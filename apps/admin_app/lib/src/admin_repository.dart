import 'dart:typed_data';
import 'dart:convert';

import 'package:ecg_api/ecg_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminSession {
  const AdminSession({
    required this.accessToken,
    required this.user,
    required this.expiresIn,
  });

  final String accessToken;
  final AuthUser user;
  final int expiresIn;

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'expires_in': expiresIn,
      'user': {
        'id': user.id,
        'username': user.username,
        'display_name': user.displayName,
        'is_active': user.isActive,
        'is_superuser': user.isSuperuser,
        'role_codes': user.roleCodes,
      },
    };
  }

  factory AdminSession.fromJson(Map<String, dynamic> json) {
    return AdminSession(
      accessToken: json['access_token'] as String,
      expiresIn: json['expires_in'] as int,
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

abstract class AdminSessionStore {
  Future<AdminSession?> read();

  Future<void> write(AdminSession session);

  Future<void> clear();
}

class SharedPreferencesAdminSessionStore implements AdminSessionStore {
  SharedPreferencesAdminSessionStore({SharedPreferences? preferences})
    : _preferences = preferences;

  static const _sessionKey = 'admin_session_v1';

  final SharedPreferences? _preferences;

  Future<SharedPreferences> _prefs() async {
    return _preferences ?? SharedPreferences.getInstance();
  }

  @override
  Future<AdminSession?> read() async {
    final prefs = await _prefs();
    final raw = prefs.getString(_sessionKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final payload = jsonDecode(raw) as Map<String, dynamic>;
      return AdminSession.fromJson(payload);
    } catch (_) {
      await prefs.remove(_sessionKey);
      return null;
    }
  }

  @override
  Future<void> write(AdminSession session) async {
    final prefs = await _prefs();
    await prefs.setString(_sessionKey, jsonEncode(session.toJson()));
  }

  @override
  Future<void> clear() async {
    final prefs = await _prefs();
    await prefs.remove(_sessionKey);
  }
}

abstract class AdminRepository {
  Future<AdminSession> login({
    required String username,
    required String password,
  });

  Future<DashboardSummary> fetchDashboardSummary(AdminSession session);

  Future<List<CategoryItem>> fetchCategories(AdminSession session);

  Future<CategoryItem> createCategory(
    AdminSession session,
    CategoryUpsertInput input,
  );

  Future<CategoryItem> updateCategory(
    AdminSession session,
    String categoryId,
    CategoryUpsertInput input,
  );

  Future<void> deleteCategory(AdminSession session, String categoryId);

  Future<List<TagItem>> fetchTags(AdminSession session);

  Future<TagItem> createTag(AdminSession session, TagUpsertInput input);

  Future<TagItem> updateTag(
    AdminSession session,
    String tagId,
    TagUpsertInput input,
  );

  Future<void> deleteTag(AdminSession session, String tagId);

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
  });

  Future<CaseDetailItem> fetchCaseDetail(AdminSession session, String caseId);

  Future<CaseDetailItem> createCase(
    AdminSession session,
    AdminCaseUpsertInput input,
  );

  Future<CaseDetailItem> updateCase(
    AdminSession session,
    String caseId,
    AdminCaseUpsertInput input,
  );

  Future<void> deleteCase(AdminSession session, String caseId);

  Future<CaseDetailItem> publishCase(AdminSession session, String caseId);

  Future<CaseDetailItem> offlineCase(AdminSession session, String caseId);

  Future<List<AdminQuizQuestionItem>> fetchQuestions(
    AdminSession session,
    String caseId,
  );

  Future<AdminQuizQuestionItem> createQuestion(
    AdminSession session,
    String caseId,
    AdminQuizQuestionUpsertInput input,
  );

  Future<AdminQuizQuestionItem> updateQuestion(
    AdminSession session,
    String questionId,
    AdminQuizQuestionUpsertInput input,
  );

  Future<void> deleteQuestion(AdminSession session, String questionId);

  Future<UploadedImageItem> uploadCaseImage(
    AdminSession session, {
    required String caseId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    bool isPrimary = false,
    int sortOrder = 0,
  });

  Future<UploadedImageItem> updateCaseImage(
    AdminSession session,
    String imageId,
    UpdateCaseImageInput input,
  );

  Future<List<UploadedImageItem>> reorderCaseImages(
    AdminSession session, {
    required String caseId,
    required List<ReorderCaseImageItemInput> items,
  });

  Future<void> deleteCaseImage(AdminSession session, String imageId);
}

class ApiAdminRepository implements AdminRepository {
  ApiAdminRepository(this._apiClient);

  final EcgApiClient _apiClient;

  @override
  Future<AdminSession> login({
    required String username,
    required String password,
  }) async {
    final response = await _apiClient.login(
      username: username,
      password: password,
    );
    return AdminSession(
      accessToken: response.accessToken,
      user: response.user,
      expiresIn: response.expiresIn,
    );
  }

  @override
  Future<DashboardSummary> fetchDashboardSummary(AdminSession session) {
    return _apiClient.fetchDashboardSummary(session.accessToken);
  }

  @override
  Future<List<CategoryItem>> fetchCategories(AdminSession session) {
    return _apiClient.fetchCategories(session.accessToken);
  }

  @override
  Future<CategoryItem> createCategory(
    AdminSession session,
    CategoryUpsertInput input,
  ) {
    return _apiClient.createCategory(session.accessToken, input);
  }

  @override
  Future<CategoryItem> updateCategory(
    AdminSession session,
    String categoryId,
    CategoryUpsertInput input,
  ) {
    return _apiClient.updateCategory(session.accessToken, categoryId, input);
  }

  @override
  Future<void> deleteCategory(AdminSession session, String categoryId) {
    return _apiClient.deleteCategory(session.accessToken, categoryId);
  }

  @override
  Future<List<TagItem>> fetchTags(AdminSession session) {
    return _apiClient.fetchTags(session.accessToken);
  }

  @override
  Future<TagItem> createTag(AdminSession session, TagUpsertInput input) {
    return _apiClient.createTag(session.accessToken, input);
  }

  @override
  Future<TagItem> updateTag(
    AdminSession session,
    String tagId,
    TagUpsertInput input,
  ) {
    return _apiClient.updateTag(session.accessToken, tagId, input);
  }

  @override
  Future<void> deleteTag(AdminSession session, String tagId) {
    return _apiClient.deleteTag(session.accessToken, tagId);
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
  }) {
    return _apiClient.fetchCases(
      session.accessToken,
      keyword: keyword,
      categoryId: categoryId,
      tagId: tagId,
      difficulty: difficulty,
      riskLevel: riskLevel,
      status: status,
      isFeatured: isFeatured,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<CaseDetailItem> fetchCaseDetail(AdminSession session, String caseId) {
    return _apiClient.fetchCaseDetail(session.accessToken, caseId);
  }

  @override
  Future<CaseDetailItem> createCase(
    AdminSession session,
    AdminCaseUpsertInput input,
  ) {
    return _apiClient.createCase(session.accessToken, input);
  }

  @override
  Future<CaseDetailItem> updateCase(
    AdminSession session,
    String caseId,
    AdminCaseUpsertInput input,
  ) {
    return _apiClient.updateCase(session.accessToken, caseId, input);
  }

  @override
  Future<void> deleteCase(AdminSession session, String caseId) {
    return _apiClient.deleteCase(session.accessToken, caseId);
  }

  @override
  Future<CaseDetailItem> publishCase(AdminSession session, String caseId) {
    return _apiClient.publishCase(session.accessToken, caseId);
  }

  @override
  Future<CaseDetailItem> offlineCase(AdminSession session, String caseId) {
    return _apiClient.offlineCase(session.accessToken, caseId);
  }

  @override
  Future<List<AdminQuizQuestionItem>> fetchQuestions(
    AdminSession session,
    String caseId,
  ) {
    return _apiClient.fetchQuestions(session.accessToken, caseId);
  }

  @override
  Future<AdminQuizQuestionItem> createQuestion(
    AdminSession session,
    String caseId,
    AdminQuizQuestionUpsertInput input,
  ) {
    return _apiClient.createQuestion(session.accessToken, caseId, input);
  }

  @override
  Future<AdminQuizQuestionItem> updateQuestion(
    AdminSession session,
    String questionId,
    AdminQuizQuestionUpsertInput input,
  ) {
    return _apiClient.updateQuestion(session.accessToken, questionId, input);
  }

  @override
  Future<void> deleteQuestion(AdminSession session, String questionId) {
    return _apiClient.deleteQuestion(session.accessToken, questionId);
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
  }) {
    return _apiClient.uploadCaseImage(
      session.accessToken,
      caseId: caseId,
      bytes: bytes,
      fileName: fileName,
      contentType: contentType,
      isPrimary: isPrimary,
      sortOrder: sortOrder,
    );
  }

  @override
  Future<UploadedImageItem> updateCaseImage(
    AdminSession session,
    String imageId,
    UpdateCaseImageInput input,
  ) {
    return _apiClient.updateCaseImage(session.accessToken, imageId, input);
  }

  @override
  Future<List<UploadedImageItem>> reorderCaseImages(
    AdminSession session, {
    required String caseId,
    required List<ReorderCaseImageItemInput> items,
  }) {
    return _apiClient.reorderCaseImages(
      session.accessToken,
      caseId: caseId,
      items: items,
    );
  }

  @override
  Future<void> deleteCaseImage(AdminSession session, String imageId) {
    return _apiClient.deleteCaseImage(session.accessToken, imageId);
  }
}
