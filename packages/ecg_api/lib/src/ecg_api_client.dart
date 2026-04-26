import 'dart:convert';
import 'dart:typed_data';

import 'package:ecg_core/ecg_core.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'models/ecg_api_models.dart';

class EcgApiException implements Exception {
  const EcgApiException({required this.message, required this.statusCode});

  final String message;
  final int statusCode;

  @override
  String toString() => 'EcgApiException($statusCode): $message';
}

class EcgApiClient {
  EcgApiClient({required this.baseUrl, http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _httpClient;

  Uri buildUri(String path, [Map<String, dynamic>? queryParameters]) {
    final baseUri = Uri.parse(baseUrl);
    final query = queryParameters?.map(
      (key, value) => MapEntry(key, value.toString()),
    );

    return baseUri.replace(path: path, queryParameters: query);
  }

  void close() {
    _httpClient.close();
  }

  Future<LoginResponse> login({
    required String username,
    required String password,
  }) async {
    final response = await _sendJsonRequest(
      'POST',
      '/api/v1/auth/login',
      body: {'username': username, 'password': password},
    );
    return LoginResponse.fromJson(response);
  }

  Future<AuthUser> fetchCurrentUser(String authToken) async {
    final response = await _sendJsonRequest(
      'GET',
      '/api/v1/auth/me',
      authToken: authToken,
    );
    return AuthUser.fromJson(response);
  }

  Future<DashboardSummary> fetchDashboardSummary(String authToken) async {
    final response = await _sendJsonRequest(
      'GET',
      '/api/v1/admin/dashboard/summary',
      authToken: authToken,
    );
    return DashboardSummary.fromJson(response);
  }

  Future<List<CategoryItem>> fetchCategories(String authToken) async {
    final response = await _sendListRequest(
      'GET',
      '/api/v1/admin/categories',
      authToken: authToken,
    );
    return response
        .map((item) => CategoryItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<CategoryItem> createCategory(
    String authToken,
    CategoryUpsertInput input,
  ) async {
    final response = await _sendJsonRequest(
      'POST',
      '/api/v1/admin/categories',
      authToken: authToken,
      body: input.toJson(),
    );
    return CategoryItem.fromJson(response);
  }

  Future<CategoryItem> updateCategory(
    String authToken,
    String categoryId,
    CategoryUpsertInput input,
  ) async {
    final response = await _sendJsonRequest(
      'PUT',
      '/api/v1/admin/categories/$categoryId',
      authToken: authToken,
      body: input.toJson(),
    );
    return CategoryItem.fromJson(response);
  }

  Future<void> deleteCategory(String authToken, String categoryId) async {
    await _sendWithoutContent(
      'DELETE',
      '/api/v1/admin/categories/$categoryId',
      authToken: authToken,
    );
  }

  Future<List<TagItem>> fetchTags(String authToken) async {
    final response = await _sendListRequest(
      'GET',
      '/api/v1/admin/tags',
      authToken: authToken,
    );
    return response
        .map((item) => TagItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<TagItem> createTag(String authToken, TagUpsertInput input) async {
    final response = await _sendJsonRequest(
      'POST',
      '/api/v1/admin/tags',
      authToken: authToken,
      body: input.toJson(),
    );
    return TagItem.fromJson(response);
  }

  Future<TagItem> updateTag(
    String authToken,
    String tagId,
    TagUpsertInput input,
  ) async {
    final response = await _sendJsonRequest(
      'PUT',
      '/api/v1/admin/tags/$tagId',
      authToken: authToken,
      body: input.toJson(),
    );
    return TagItem.fromJson(response);
  }

  Future<void> deleteTag(String authToken, String tagId) async {
    await _sendWithoutContent(
      'DELETE',
      '/api/v1/admin/tags/$tagId',
      authToken: authToken,
    );
  }

  Future<AdminCaseListResponse> fetchCases(
    String authToken, {
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
    final featuredQuery = isFeatured == null
        ? null
        : <String, dynamic>{'is_featured': isFeatured};
    final response = await _sendJsonRequest(
      'GET',
      '/api/v1/admin/cases',
      authToken: authToken,
      queryParameters: {
        if (keyword != null && keyword.trim().isNotEmpty)
          'keyword': keyword.trim(),
        if (categoryId != null && categoryId.isNotEmpty)
          'category_id': categoryId,
        if (tagId != null && tagId.isNotEmpty) 'tag_id': tagId,
        if (difficulty != null) 'difficulty': difficultyLevelToJson(difficulty),
        if (riskLevel != null) 'risk_level': riskLevelToJson(riskLevel),
        if (status != null) 'status': caseStatusToJson(status),
        ...?featuredQuery,
        'page': page,
        'page_size': pageSize,
      },
    );
    return AdminCaseListResponse.fromJson(response);
  }

  Future<List<CategoryItem>> fetchPublicCategories() async {
    final response = await _sendListRequest('GET', '/api/v1/public/categories');
    return response
        .map((item) => CategoryItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<PublicCaseListResponse> fetchPublicCases({
    String? keyword,
    String? categoryId,
    String? tagId,
    DifficultyLevel? difficulty,
    RiskLevel? riskLevel,
    bool? isFeatured,
    int page = 1,
    int pageSize = 20,
  }) async {
    final featuredQuery = isFeatured == null
        ? null
        : <String, dynamic>{'is_featured': isFeatured};
    final response = await _sendJsonRequest(
      'GET',
      '/api/v1/public/cases',
      queryParameters: {
        if (keyword != null && keyword.trim().isNotEmpty)
          'keyword': keyword.trim(),
        if (categoryId != null && categoryId.isNotEmpty)
          'category_id': categoryId,
        if (tagId != null && tagId.isNotEmpty) 'tag_id': tagId,
        if (difficulty != null) 'difficulty': difficultyLevelToJson(difficulty),
        if (riskLevel != null) 'risk_level': riskLevelToJson(riskLevel),
        ...?featuredQuery,
        'page': page,
        'page_size': pageSize,
      },
    );
    return PublicCaseListResponse.fromJson(response);
  }

  Future<CaseDetailItem> fetchPublicCaseDetail(String caseId) async {
    final response = await _sendJsonRequest(
      'GET',
      '/api/v1/public/cases/$caseId',
    );
    return CaseDetailItem.fromJson(response);
  }

  Future<List<PublicQuizQuestionItem>> fetchPublicQuizQuestions(
    String caseId,
  ) async {
    final response = await _sendListRequest(
      'GET',
      '/api/v1/public/cases/$caseId/quiz',
    );
    return response
        .map(
          (item) =>
              PublicQuizQuestionItem.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<List<LearningProgressItem>> fetchLearningProgress(
    String authToken,
  ) async {
    final response = await _sendListRequest(
      'GET',
      '/api/v1/user/learning/progress',
      authToken: authToken,
    );
    return response
        .map(
          (item) => LearningProgressItem.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<LearningProgressItem> markCaseViewed(
    String authToken,
    String caseId,
  ) async {
    final response = await _sendJsonRequest(
      'POST',
      '/api/v1/user/learning/cases/$caseId/view',
      authToken: authToken,
    );
    return LearningProgressItem.fromJson(response);
  }

  Future<List<FavoriteItem>> fetchFavorites(String authToken) async {
    final response = await _sendListRequest(
      'GET',
      '/api/v1/user/favorites',
      authToken: authToken,
    );
    return response
        .map((item) => FavoriteItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<FavoriteItem> addFavorite(String authToken, String caseId) async {
    final response = await _sendJsonRequest(
      'POST',
      '/api/v1/user/favorites/$caseId',
      authToken: authToken,
    );
    return FavoriteItem.fromJson(response);
  }

  Future<void> removeFavorite(String authToken, String caseId) async {
    await _sendWithoutContent(
      'DELETE',
      '/api/v1/user/favorites/$caseId',
      authToken: authToken,
    );
  }

  Future<List<WrongQuestionItem>> fetchWrongQuestions(String authToken) async {
    final response = await _sendListRequest(
      'GET',
      '/api/v1/user/wrong-questions',
      authToken: authToken,
    );
    return response
        .map((item) => WrongQuestionItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<QuizSubmissionResponse> submitQuiz(
    String authToken,
    QuizSubmissionInput input,
  ) async {
    final response = await _sendJsonRequest(
      'POST',
      '/api/v1/user/quiz/submit',
      authToken: authToken,
      body: input.toJson(),
    );
    return QuizSubmissionResponse.fromJson(response);
  }

  Future<CaseDetailItem> createCase(
    String authToken,
    AdminCaseUpsertInput input,
  ) async {
    final response = await _sendJsonRequest(
      'POST',
      '/api/v1/admin/cases',
      authToken: authToken,
      body: input.toJson(),
    );
    return CaseDetailItem.fromJson(response);
  }

  Future<CaseDetailItem> fetchCaseDetail(
    String authToken,
    String caseId,
  ) async {
    final response = await _sendJsonRequest(
      'GET',
      '/api/v1/admin/cases/$caseId',
      authToken: authToken,
    );
    return CaseDetailItem.fromJson(response);
  }

  Future<CaseDetailItem> updateCase(
    String authToken,
    String caseId,
    AdminCaseUpsertInput input,
  ) async {
    final response = await _sendJsonRequest(
      'PUT',
      '/api/v1/admin/cases/$caseId',
      authToken: authToken,
      body: input.toJson(),
    );
    return CaseDetailItem.fromJson(response);
  }

  Future<void> deleteCase(String authToken, String caseId) async {
    await _sendWithoutContent(
      'DELETE',
      '/api/v1/admin/cases/$caseId',
      authToken: authToken,
    );
  }

  Future<CaseDetailItem> publishCase(String authToken, String caseId) async {
    final response = await _sendJsonRequest(
      'POST',
      '/api/v1/admin/cases/$caseId/publish',
      authToken: authToken,
    );
    return CaseDetailItem.fromJson(response);
  }

  Future<CaseDetailItem> offlineCase(String authToken, String caseId) async {
    final response = await _sendJsonRequest(
      'POST',
      '/api/v1/admin/cases/$caseId/offline',
      authToken: authToken,
    );
    return CaseDetailItem.fromJson(response);
  }

  Future<List<AdminQuizQuestionItem>> fetchQuestions(
    String authToken,
    String caseId,
  ) async {
    final response = await _sendListRequest(
      'GET',
      '/api/v1/admin/cases/$caseId/questions',
      authToken: authToken,
    );
    return response
        .map(
          (item) =>
              AdminQuizQuestionItem.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<AdminQuizQuestionItem> createQuestion(
    String authToken,
    String caseId,
    AdminQuizQuestionUpsertInput input,
  ) async {
    final response = await _sendJsonRequest(
      'POST',
      '/api/v1/admin/cases/$caseId/questions',
      authToken: authToken,
      body: input.toJson(),
    );
    return AdminQuizQuestionItem.fromJson(response);
  }

  Future<AdminQuizQuestionItem> updateQuestion(
    String authToken,
    String questionId,
    AdminQuizQuestionUpsertInput input,
  ) async {
    final response = await _sendJsonRequest(
      'PUT',
      '/api/v1/admin/questions/$questionId',
      authToken: authToken,
      body: input.toJson(),
    );
    return AdminQuizQuestionItem.fromJson(response);
  }

  Future<void> deleteQuestion(String authToken, String questionId) async {
    await _sendWithoutContent(
      'DELETE',
      '/api/v1/admin/questions/$questionId',
      authToken: authToken,
    );
  }

  Future<UploadedImageItem> uploadCaseImage(
    String authToken, {
    required String caseId,
    required Uint8List bytes,
    required String fileName,
    required String contentType,
    bool isPrimary = false,
    int sortOrder = 0,
  }) async {
    final uri = buildUri('/api/v1/admin/cases/$caseId/images');
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(
        _defaultHeaders(authToken: authToken, includeJson: false),
      )
      ..fields['is_primary'] = isPrimary.toString()
      ..fields['sort_order'] = sortOrder.toString()
      ..files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
          contentType: MediaType.parse(contentType),
        ),
      );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);
    final payload = _decodeBody(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw EcgApiException(
        message: _extractErrorMessage(payload),
        statusCode: response.statusCode,
      );
    }
    return UploadedImageItem.fromJson(payload as Map<String, dynamic>);
  }

  Future<UploadedImageItem> updateCaseImage(
    String authToken,
    String imageId,
    UpdateCaseImageInput input,
  ) async {
    final response = await _sendJsonRequest(
      'PATCH',
      '/api/v1/admin/case-images/$imageId',
      authToken: authToken,
      body: input.toJson(),
    );
    return UploadedImageItem.fromJson(response);
  }

  Future<List<UploadedImageItem>> reorderCaseImages(
    String authToken, {
    required String caseId,
    required List<ReorderCaseImageItemInput> items,
  }) async {
    final response = await _sendListRequest(
      'PUT',
      '/api/v1/admin/cases/$caseId/images/order',
      authToken: authToken,
      body: {'items': items.map((item) => item.toJson()).toList()},
    );
    return response
        .map((item) => UploadedImageItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> deleteCaseImage(String authToken, String imageId) async {
    await _sendWithoutContent(
      'DELETE',
      '/api/v1/admin/case-images/$imageId',
      authToken: authToken,
    );
  }

  Future<Map<String, dynamic>> _sendJsonRequest(
    String method,
    String path, {
    String? authToken,
    Map<String, dynamic>? queryParameters,
    Object? body,
  }) async {
    final response = await _sendRequest(
      method,
      path,
      authToken: authToken,
      queryParameters: queryParameters,
      body: body,
    );
    final payload = _decodeBody(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw EcgApiException(
        message: _extractErrorMessage(payload),
        statusCode: response.statusCode,
      );
    }
    if (payload is! Map<String, dynamic>) {
      throw const EcgApiException(
        message: 'Expected JSON object response.',
        statusCode: 500,
      );
    }
    return payload;
  }

  Future<List<dynamic>> _sendListRequest(
    String method,
    String path, {
    String? authToken,
    Map<String, dynamic>? queryParameters,
    Object? body,
  }) async {
    final response = await _sendRequest(
      method,
      path,
      authToken: authToken,
      queryParameters: queryParameters,
      body: body,
    );
    final payload = _decodeBody(response);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw EcgApiException(
        message: _extractErrorMessage(payload),
        statusCode: response.statusCode,
      );
    }
    if (payload is! List<dynamic>) {
      throw const EcgApiException(
        message: 'Expected JSON list response.',
        statusCode: 500,
      );
    }
    return payload;
  }

  Future<void> _sendWithoutContent(
    String method,
    String path, {
    String? authToken,
  }) async {
    final response = await _sendRequest(method, path, authToken: authToken);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final payload = _decodeBody(response);
      throw EcgApiException(
        message: _extractErrorMessage(payload),
        statusCode: response.statusCode,
      );
    }
  }

  Future<http.Response> _sendRequest(
    String method,
    String path, {
    String? authToken,
    Map<String, dynamic>? queryParameters,
    Object? body,
  }) {
    final uri = buildUri(path, queryParameters);
    final headers = _defaultHeaders(authToken: authToken);
    final encodedBody = body == null ? null : jsonEncode(body);

    switch (method) {
      case 'GET':
        return _httpClient.get(uri, headers: headers);
      case 'POST':
        return _httpClient.post(uri, headers: headers, body: encodedBody);
      case 'PUT':
        return _httpClient.put(uri, headers: headers, body: encodedBody);
      case 'PATCH':
        return _httpClient.patch(uri, headers: headers, body: encodedBody);
      case 'DELETE':
        return _httpClient.delete(uri, headers: headers, body: encodedBody);
    }
    throw UnsupportedError('Unsupported method: $method');
  }

  Map<String, String> _defaultHeaders({
    String? authToken,
    bool includeJson = true,
  }) {
    return {
      if (includeJson) 'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (authToken != null && authToken.isNotEmpty)
        'Authorization': 'Bearer $authToken',
    };
  }

  Object? _decodeBody(http.Response response) {
    if (response.bodyBytes.isEmpty) {
      return null;
    }

    final text = utf8.decode(response.bodyBytes);
    if (text.trim().isEmpty) {
      return null;
    }
    return jsonDecode(text);
  }

  String _extractErrorMessage(Object? payload) {
    if (payload is Map<String, dynamic>) {
      final detail = payload['detail'];
      if (detail is String && detail.trim().isNotEmpty) {
        return detail;
      }
    }
    return 'Request failed.';
  }
}
