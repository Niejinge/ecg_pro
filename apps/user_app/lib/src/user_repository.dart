import 'package:ecg_api/ecg_api.dart';

abstract class UserRepository {
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
}

class ApiUserRepository implements UserRepository {
  ApiUserRepository(this._apiClient);

  final EcgApiClient _apiClient;

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
}
