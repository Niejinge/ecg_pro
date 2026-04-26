import 'dart:convert';

import 'package:ecg_api/ecg_api.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserSession {
  const UserSession({
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

  factory UserSession.fromJson(Map<String, dynamic> json) {
    return UserSession(
      accessToken: json['access_token'] as String,
      expiresIn: json['expires_in'] as int,
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

abstract class UserSessionStore {
  Future<UserSession?> read();

  Future<void> write(UserSession session);

  Future<void> clear();
}

class SharedPreferencesUserSessionStore implements UserSessionStore {
  SharedPreferencesUserSessionStore({SharedPreferences? preferences})
    : _preferences = preferences;

  static const _sessionKey = 'user_session_v1';

  final SharedPreferences? _preferences;

  Future<SharedPreferences> _prefs() async {
    return _preferences ?? SharedPreferences.getInstance();
  }

  @override
  Future<UserSession?> read() async {
    final prefs = await _prefs();
    final raw = prefs.getString(_sessionKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final payload = jsonDecode(raw) as Map<String, dynamic>;
      return UserSession.fromJson(payload);
    } catch (_) {
      await prefs.remove(_sessionKey);
      return null;
    }
  }

  @override
  Future<void> write(UserSession session) async {
    final prefs = await _prefs();
    await prefs.setString(_sessionKey, jsonEncode(session.toJson()));
  }

  @override
  Future<void> clear() async {
    final prefs = await _prefs();
    await prefs.remove(_sessionKey);
  }
}

abstract class UserRepository {
  Future<UserSession> login({
    required String username,
    required String password,
  });

  Future<List<CategoryItem>> fetchCategories();

  Future<PublicCaseListResponse> fetchCases({
    String? keyword,
    String? categoryId,
    DifficultyLevel? difficulty,
    RiskLevel? riskLevel,
    bool? isFeatured,
    int page = 1,
    int pageSize = 20,
  });

  Future<CaseDetailItem> fetchCaseDetail(String caseId);

  Future<List<PublicQuizQuestionItem>> fetchQuizQuestions(String caseId);

  Future<List<LearningProgressItem>> fetchLearningProgress(UserSession session);

  Future<LearningProgressItem> markCaseViewed(
    UserSession session,
    String caseId,
  );

  Future<List<FavoriteItem>> fetchFavorites(UserSession session);

  Future<FavoriteItem> addFavorite(UserSession session, String caseId);

  Future<void> removeFavorite(UserSession session, String caseId);

  Future<List<WrongQuestionItem>> fetchWrongQuestions(UserSession session);

  Future<QuizSubmissionResponse> submitQuiz(
    UserSession session,
    QuizSubmissionInput input,
  );
}

class ApiUserRepository implements UserRepository {
  ApiUserRepository(this._apiClient);

  final EcgApiClient _apiClient;

  @override
  Future<UserSession> login({
    required String username,
    required String password,
  }) async {
    final response = await _apiClient.login(
      username: username,
      password: password,
    );
    return UserSession(
      accessToken: response.accessToken,
      user: response.user,
      expiresIn: response.expiresIn,
    );
  }

  @override
  Future<List<CategoryItem>> fetchCategories() {
    return _apiClient.fetchPublicCategories();
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
  }) {
    return _apiClient.fetchPublicCases(
      keyword: keyword,
      categoryId: categoryId,
      difficulty: difficulty,
      riskLevel: riskLevel,
      isFeatured: isFeatured,
      page: page,
      pageSize: pageSize,
    );
  }

  @override
  Future<CaseDetailItem> fetchCaseDetail(String caseId) {
    return _apiClient.fetchPublicCaseDetail(caseId);
  }

  @override
  Future<List<PublicQuizQuestionItem>> fetchQuizQuestions(String caseId) {
    return _apiClient.fetchPublicQuizQuestions(caseId);
  }

  @override
  Future<List<LearningProgressItem>> fetchLearningProgress(
    UserSession session,
  ) {
    return _apiClient.fetchLearningProgress(session.accessToken);
  }

  @override
  Future<LearningProgressItem> markCaseViewed(
    UserSession session,
    String caseId,
  ) {
    return _apiClient.markCaseViewed(session.accessToken, caseId);
  }

  @override
  Future<List<FavoriteItem>> fetchFavorites(UserSession session) {
    return _apiClient.fetchFavorites(session.accessToken);
  }

  @override
  Future<FavoriteItem> addFavorite(UserSession session, String caseId) {
    return _apiClient.addFavorite(session.accessToken, caseId);
  }

  @override
  Future<void> removeFavorite(UserSession session, String caseId) {
    return _apiClient.removeFavorite(session.accessToken, caseId);
  }

  @override
  Future<List<WrongQuestionItem>> fetchWrongQuestions(UserSession session) {
    return _apiClient.fetchWrongQuestions(session.accessToken);
  }

  @override
  Future<QuizSubmissionResponse> submitQuiz(
    UserSession session,
    QuizSubmissionInput input,
  ) {
    return _apiClient.submitQuiz(session.accessToken, input);
  }
}
