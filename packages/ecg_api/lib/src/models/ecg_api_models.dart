import 'package:ecg_core/ecg_core.dart';

DifficultyLevel _difficultyLevelFromJson(String value) {
  switch (value) {
    case 'beginner':
      return DifficultyLevel.beginner;
    case 'intermediate':
      return DifficultyLevel.intermediate;
    case 'advanced':
      return DifficultyLevel.advanced;
  }
  throw ArgumentError.value(value, 'value', 'Unsupported difficulty level.');
}

RiskLevel _riskLevelFromJson(String value) {
  switch (value) {
    case 'low':
      return RiskLevel.low;
    case 'medium':
      return RiskLevel.medium;
    case 'high':
      return RiskLevel.high;
    case 'critical':
      return RiskLevel.critical;
  }
  throw ArgumentError.value(value, 'value', 'Unsupported risk level.');
}

CaseStatus _caseStatusFromJson(String value) {
  switch (value) {
    case 'draft':
      return CaseStatus.draft;
    case 'published':
      return CaseStatus.published;
    case 'offline':
      return CaseStatus.offline;
  }
  throw ArgumentError.value(value, 'value', 'Unsupported case status.');
}

QuestionType _questionTypeFromJson(String value) {
  switch (value) {
    case 'single_choice':
      return QuestionType.singleChoice;
    case 'multiple_choice':
      return QuestionType.multipleChoice;
    case 'true_false':
      return QuestionType.trueFalse;
    case 'image_recognition':
      return QuestionType.imageRecognition;
  }
  throw ArgumentError.value(value, 'value', 'Unsupported question type.');
}

String difficultyLevelToJson(DifficultyLevel value) {
  switch (value) {
    case DifficultyLevel.beginner:
      return 'beginner';
    case DifficultyLevel.intermediate:
      return 'intermediate';
    case DifficultyLevel.advanced:
      return 'advanced';
  }
}

String riskLevelToJson(RiskLevel value) {
  switch (value) {
    case RiskLevel.low:
      return 'low';
    case RiskLevel.medium:
      return 'medium';
    case RiskLevel.high:
      return 'high';
    case RiskLevel.critical:
      return 'critical';
  }
}

String caseStatusToJson(CaseStatus value) {
  switch (value) {
    case CaseStatus.draft:
      return 'draft';
    case CaseStatus.published:
      return 'published';
    case CaseStatus.offline:
      return 'offline';
  }
}

String questionTypeToJson(QuestionType value) {
  switch (value) {
    case QuestionType.singleChoice:
      return 'single_choice';
    case QuestionType.multipleChoice:
      return 'multiple_choice';
    case QuestionType.trueFalse:
      return 'true_false';
    case QuestionType.imageRecognition:
      return 'image_recognition';
  }
}

DateTime? _dateTimeFromJson(Object? value) {
  if (value == null) {
    return null;
  }
  return DateTime.parse(value as String).toLocal();
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.username,
    required this.displayName,
    required this.isActive,
    required this.isSuperuser,
    required this.roleCodes,
  });

  final String id;
  final String username;
  final String displayName;
  final bool isActive;
  final bool isSuperuser;
  final List<String> roleCodes;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String,
      username: json['username'] as String,
      displayName: json['display_name'] as String,
      isActive: json['is_active'] as bool,
      isSuperuser: json['is_superuser'] as bool,
      roleCodes: List<String>.from(json['role_codes'] as List<dynamic>),
    );
  }
}

class LoginResponse {
  const LoginResponse({
    required this.accessToken,
    required this.tokenType,
    required this.expiresIn,
    required this.user,
  });

  final String accessToken;
  final String tokenType;
  final int expiresIn;
  final AuthUser user;

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    return LoginResponse(
      accessToken: json['access_token'] as String,
      tokenType: json['token_type'] as String,
      expiresIn: json['expires_in'] as int,
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }
}

class DashboardSummary {
  const DashboardSummary({
    required this.totalCases,
    required this.publishedCases,
    required this.totalQuestions,
    required this.totalUsers,
  });

  final int totalCases;
  final int publishedCases;
  final int totalQuestions;
  final int totalUsers;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      totalCases: json['total_cases'] as int,
      publishedCases: json['published_cases'] as int,
      totalQuestions: json['total_questions'] as int,
      totalUsers: json['total_users'] as int,
    );
  }
}

class CategoryItem {
  const CategoryItem({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
    required this.sortOrder,
    required this.isVisible,
    required this.parentId,
  });

  final String id;
  final String name;
  final String slug;
  final String? description;
  final int sortOrder;
  final bool isVisible;
  final String? parentId;

  factory CategoryItem.fromJson(Map<String, dynamic> json) {
    return CategoryItem(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      description: json['description'] as String?,
      sortOrder: json['sort_order'] as int,
      isVisible: json['is_visible'] as bool,
      parentId: json['parent_id'] as String?,
    );
  }
}

class CategoryUpsertInput {
  const CategoryUpsertInput({
    required this.name,
    required this.slug,
    this.description,
    this.sortOrder = 0,
    this.isVisible = true,
    this.parentId,
  });

  final String name;
  final String slug;
  final String? description;
  final int sortOrder;
  final bool isVisible;
  final String? parentId;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'slug': slug,
      'description': description,
      'sort_order': sortOrder,
      'is_visible': isVisible,
      'parent_id': parentId,
    };
  }
}

class TagItem {
  const TagItem({
    required this.id,
    required this.name,
    required this.slug,
    required this.description,
  });

  final String id;
  final String name;
  final String slug;
  final String? description;

  factory TagItem.fromJson(Map<String, dynamic> json) {
    return TagItem(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      description: json['description'] as String?,
    );
  }
}

class TagUpsertInput {
  const TagUpsertInput({
    required this.name,
    required this.slug,
    this.description,
  });

  final String name;
  final String slug;
  final String? description;

  Map<String, dynamic> toJson() {
    return {'name': name, 'slug': slug, 'description': description};
  }
}

class CaseCategorySummary {
  const CaseCategorySummary({
    required this.id,
    required this.name,
    required this.slug,
  });

  final String id;
  final String name;
  final String slug;

  factory CaseCategorySummary.fromJson(Map<String, dynamic> json) {
    return CaseCategorySummary(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
    );
  }
}

class CaseTagSummary {
  const CaseTagSummary({
    required this.id,
    required this.name,
    required this.slug,
  });

  final String id;
  final String name;
  final String slug;

  factory CaseTagSummary.fromJson(Map<String, dynamic> json) {
    return CaseTagSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
    );
  }
}

class CaseImageItem {
  const CaseImageItem({
    required this.id,
    required this.fileName,
    required this.fileUrl,
    required this.contentType,
    required this.isPrimary,
    required this.sortOrder,
  });

  final String id;
  final String fileName;
  final String fileUrl;
  final String? contentType;
  final bool isPrimary;
  final int sortOrder;

  factory CaseImageItem.fromJson(Map<String, dynamic> json) {
    return CaseImageItem(
      id: json['id'] as String,
      fileName: json['file_name'] as String,
      fileUrl: json['file_url'] as String,
      contentType: json['content_type'] as String?,
      isPrimary: json['is_primary'] as bool,
      sortOrder: json['sort_order'] as int,
    );
  }
}

class AdminCaseListItem {
  const AdminCaseListItem({
    required this.id,
    required this.caseCode,
    required this.title,
    required this.diagnosis,
    required this.difficulty,
    required this.riskLevel,
    required this.categoryName,
    required this.status,
    required this.isFeatured,
    required this.updatedAt,
  });

  final String id;
  final String caseCode;
  final String title;
  final String diagnosis;
  final DifficultyLevel difficulty;
  final RiskLevel riskLevel;
  final String? categoryName;
  final CaseStatus status;
  final bool isFeatured;
  final DateTime updatedAt;

  factory AdminCaseListItem.fromJson(Map<String, dynamic> json) {
    return AdminCaseListItem(
      id: json['id'] as String,
      caseCode: json['case_code'] as String,
      title: json['title'] as String,
      diagnosis: json['diagnosis'] as String,
      difficulty: _difficultyLevelFromJson(json['difficulty'] as String),
      riskLevel: _riskLevelFromJson(json['risk_level'] as String),
      categoryName: json['category_name'] as String?,
      status: _caseStatusFromJson(json['status'] as String),
      isFeatured: json['is_featured'] as bool,
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
    );
  }
}

class AdminCaseListResponse {
  const AdminCaseListResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.hasNext,
  });

  final List<AdminCaseListItem> items;
  final int total;
  final int page;
  final int pageSize;
  final bool hasNext;

  factory AdminCaseListResponse.fromJson(Map<String, dynamic> json) {
    return AdminCaseListResponse(
      items: (json['items'] as List<dynamic>)
          .map(
            (item) => AdminCaseListItem.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
      total: json['total'] as int,
      page: json['page'] as int,
      pageSize: json['page_size'] as int,
      hasNext: json['has_next'] as bool,
    );
  }
}

class CaseDetailItem {
  const CaseDetailItem({
    required this.id,
    required this.caseCode,
    required this.title,
    required this.summary,
    required this.diagnosis,
    required this.rhythmType,
    required this.heartRate,
    required this.axisDescription,
    required this.prDescription,
    required this.qrsDescription,
    required this.stTDescription,
    required this.qtDescription,
    required this.keyLeads,
    required this.clinicalSignificance,
    required this.differentialDiagnosis,
    required this.treatmentPlan,
    required this.urgentActions,
    required this.followUpRecommendations,
    required this.detailedDescription,
    required this.interpretationSteps,
    required this.learningPoints,
    required this.commonMistakes,
    required this.memoryTips,
    required this.difficulty,
    required this.riskLevel,
    required this.status,
    required this.isFeatured,
    required this.publishedAt,
    required this.category,
    required this.tags,
    required this.images,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String caseCode;
  final String title;
  final String? summary;
  final String diagnosis;
  final String? rhythmType;
  final String? heartRate;
  final String? axisDescription;
  final String? prDescription;
  final String? qrsDescription;
  final String? stTDescription;
  final String? qtDescription;
  final List<String> keyLeads;
  final String? clinicalSignificance;
  final String? differentialDiagnosis;
  final String? treatmentPlan;
  final String? urgentActions;
  final String? followUpRecommendations;
  final String? detailedDescription;
  final List<String> interpretationSteps;
  final List<String> learningPoints;
  final List<String> commonMistakes;
  final List<String> memoryTips;
  final DifficultyLevel difficulty;
  final RiskLevel riskLevel;
  final CaseStatus status;
  final bool isFeatured;
  final DateTime? publishedAt;
  final CaseCategorySummary? category;
  final List<CaseTagSummary> tags;
  final List<CaseImageItem> images;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory CaseDetailItem.fromJson(Map<String, dynamic> json) {
    return CaseDetailItem(
      id: json['id'] as String,
      caseCode: json['case_code'] as String,
      title: json['title'] as String,
      summary: json['summary'] as String?,
      diagnosis: json['diagnosis'] as String,
      rhythmType: json['rhythm_type'] as String?,
      heartRate: json['heart_rate'] as String?,
      axisDescription: json['axis_description'] as String?,
      prDescription: json['pr_description'] as String?,
      qrsDescription: json['qrs_description'] as String?,
      stTDescription: json['st_t_description'] as String?,
      qtDescription: json['qt_description'] as String?,
      keyLeads: List<String>.from(json['key_leads'] as List<dynamic>),
      clinicalSignificance: json['clinical_significance'] as String?,
      differentialDiagnosis: json['differential_diagnosis'] as String?,
      treatmentPlan: json['treatment_plan'] as String?,
      urgentActions: json['urgent_actions'] as String?,
      followUpRecommendations: json['follow_up_recommendations'] as String?,
      detailedDescription: json['detailed_description'] as String?,
      interpretationSteps: List<String>.from(
        json['interpretation_steps'] as List<dynamic>,
      ),
      learningPoints: List<String>.from(
        json['learning_points'] as List<dynamic>,
      ),
      commonMistakes: List<String>.from(
        json['common_mistakes'] as List<dynamic>,
      ),
      memoryTips: List<String>.from(json['memory_tips'] as List<dynamic>),
      difficulty: _difficultyLevelFromJson(json['difficulty'] as String),
      riskLevel: _riskLevelFromJson(json['risk_level'] as String),
      status: _caseStatusFromJson(json['status'] as String),
      isFeatured: json['is_featured'] as bool,
      publishedAt: _dateTimeFromJson(json['published_at']),
      category: json['category'] == null
          ? null
          : CaseCategorySummary.fromJson(
              json['category'] as Map<String, dynamic>,
            ),
      tags: (json['tags'] as List<dynamic>)
          .map((item) => CaseTagSummary.fromJson(item as Map<String, dynamic>))
          .toList(),
      images: (json['images'] as List<dynamic>)
          .map((item) => CaseImageItem.fromJson(item as Map<String, dynamic>))
          .toList(),
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
    );
  }
}

class AdminCaseUpsertInput {
  const AdminCaseUpsertInput({
    required this.caseCode,
    required this.title,
    required this.diagnosis,
    required this.summary,
    required this.rhythmType,
    required this.heartRate,
    required this.axisDescription,
    required this.prDescription,
    required this.qrsDescription,
    required this.stTDescription,
    required this.qtDescription,
    required this.keyLeads,
    required this.clinicalSignificance,
    required this.differentialDiagnosis,
    required this.treatmentPlan,
    required this.urgentActions,
    required this.followUpRecommendations,
    required this.detailedDescription,
    required this.interpretationSteps,
    required this.learningPoints,
    required this.commonMistakes,
    required this.memoryTips,
    required this.difficulty,
    required this.riskLevel,
    required this.categoryId,
    required this.tagIds,
    required this.isFeatured,
  });

  final String caseCode;
  final String title;
  final String diagnosis;
  final String? summary;
  final String? rhythmType;
  final String? heartRate;
  final String? axisDescription;
  final String? prDescription;
  final String? qrsDescription;
  final String? stTDescription;
  final String? qtDescription;
  final List<String> keyLeads;
  final String? clinicalSignificance;
  final String? differentialDiagnosis;
  final String? treatmentPlan;
  final String? urgentActions;
  final String? followUpRecommendations;
  final String? detailedDescription;
  final List<String> interpretationSteps;
  final List<String> learningPoints;
  final List<String> commonMistakes;
  final List<String> memoryTips;
  final DifficultyLevel difficulty;
  final RiskLevel riskLevel;
  final String? categoryId;
  final List<String> tagIds;
  final bool isFeatured;

  Map<String, dynamic> toJson() {
    return {
      'case_code': caseCode,
      'title': title,
      'summary': summary,
      'diagnosis': diagnosis,
      'rhythm_type': rhythmType,
      'heart_rate': heartRate,
      'axis_description': axisDescription,
      'pr_description': prDescription,
      'qrs_description': qrsDescription,
      'st_t_description': stTDescription,
      'qt_description': qtDescription,
      'key_leads': keyLeads,
      'clinical_significance': clinicalSignificance,
      'differential_diagnosis': differentialDiagnosis,
      'treatment_plan': treatmentPlan,
      'urgent_actions': urgentActions,
      'follow_up_recommendations': followUpRecommendations,
      'detailed_description': detailedDescription,
      'interpretation_steps': interpretationSteps,
      'learning_points': learningPoints,
      'common_mistakes': commonMistakes,
      'memory_tips': memoryTips,
      'difficulty': difficultyLevelToJson(difficulty),
      'risk_level': riskLevelToJson(riskLevel),
      'category_id': categoryId,
      'tag_ids': tagIds,
      'is_featured': isFeatured,
    };
  }
}

class AdminQuizOptionItem {
  const AdminQuizOptionItem({
    required this.id,
    required this.label,
    required this.content,
    required this.isCorrect,
    required this.sortOrder,
  });

  final String id;
  final String label;
  final String content;
  final bool isCorrect;
  final int sortOrder;

  factory AdminQuizOptionItem.fromJson(Map<String, dynamic> json) {
    return AdminQuizOptionItem(
      id: json['id'] as String,
      label: json['label'] as String,
      content: json['content'] as String,
      isCorrect: json['is_correct'] as bool,
      sortOrder: json['sort_order'] as int,
    );
  }
}

class AdminQuizQuestionItem {
  const AdminQuizQuestionItem({
    required this.id,
    required this.caseId,
    required this.stem,
    required this.explanation,
    required this.questionType,
    required this.difficulty,
    required this.sortOrder,
    required this.isActive,
    required this.options,
  });

  final String id;
  final String caseId;
  final String stem;
  final String? explanation;
  final QuestionType questionType;
  final DifficultyLevel difficulty;
  final int sortOrder;
  final bool isActive;
  final List<AdminQuizOptionItem> options;

  factory AdminQuizQuestionItem.fromJson(Map<String, dynamic> json) {
    return AdminQuizQuestionItem(
      id: json['id'] as String,
      caseId: json['case_id'] as String,
      stem: json['stem'] as String,
      explanation: json['explanation'] as String?,
      questionType: _questionTypeFromJson(json['question_type'] as String),
      difficulty: _difficultyLevelFromJson(json['difficulty'] as String),
      sortOrder: json['sort_order'] as int,
      isActive: json['is_active'] as bool,
      options: (json['options'] as List<dynamic>)
          .map(
            (item) =>
                AdminQuizOptionItem.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class AdminQuizOptionUpsertInput {
  const AdminQuizOptionUpsertInput({
    required this.label,
    required this.content,
    required this.isCorrect,
    required this.sortOrder,
  });

  final String label;
  final String content;
  final bool isCorrect;
  final int sortOrder;

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'content': content,
      'is_correct': isCorrect,
      'sort_order': sortOrder,
    };
  }
}

class AdminQuizQuestionUpsertInput {
  const AdminQuizQuestionUpsertInput({
    required this.stem,
    required this.explanation,
    required this.questionType,
    required this.difficulty,
    required this.sortOrder,
    required this.isActive,
    required this.options,
  });

  final String stem;
  final String? explanation;
  final QuestionType questionType;
  final DifficultyLevel difficulty;
  final int sortOrder;
  final bool isActive;
  final List<AdminQuizOptionUpsertInput> options;

  Map<String, dynamic> toJson() {
    return {
      'stem': stem,
      'explanation': explanation,
      'question_type': questionTypeToJson(questionType),
      'difficulty': difficultyLevelToJson(difficulty),
      'sort_order': sortOrder,
      'is_active': isActive,
      'options': options.map((item) => item.toJson()).toList(),
    };
  }
}

class UploadedImageItem {
  const UploadedImageItem({
    required this.id,
    required this.caseId,
    required this.fileName,
    required this.fileUrl,
    required this.contentType,
    required this.isPrimary,
    required this.sortOrder,
  });

  final String id;
  final String caseId;
  final String fileName;
  final String fileUrl;
  final String? contentType;
  final bool isPrimary;
  final int sortOrder;

  factory UploadedImageItem.fromJson(Map<String, dynamic> json) {
    return UploadedImageItem(
      id: json['id'] as String,
      caseId: json['case_id'] as String,
      fileName: json['file_name'] as String,
      fileUrl: json['file_url'] as String,
      contentType: json['content_type'] as String?,
      isPrimary: json['is_primary'] as bool,
      sortOrder: json['sort_order'] as int,
    );
  }
}

class ReorderCaseImageItemInput {
  const ReorderCaseImageItemInput({
    required this.imageId,
    required this.sortOrder,
  });

  final String imageId;
  final int sortOrder;

  Map<String, dynamic> toJson() {
    return {'image_id': imageId, 'sort_order': sortOrder};
  }
}

class UpdateCaseImageInput {
  const UpdateCaseImageInput({this.isPrimary, this.sortOrder});

  final bool? isPrimary;
  final int? sortOrder;

  Map<String, dynamic> toJson() {
    return {
      if (isPrimary != null) 'is_primary': isPrimary,
      if (sortOrder != null) 'sort_order': sortOrder,
    };
  }
}
