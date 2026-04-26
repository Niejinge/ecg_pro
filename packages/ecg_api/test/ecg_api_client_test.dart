import 'dart:convert';

import 'package:ecg_api/ecg_api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  test('buildUri appends path and query parameters', () {
    final client = EcgApiClient(baseUrl: 'https://api.ecgpro.local');

    final uri = client.buildUri('/api/v1/public/cases', {
      'page': 2,
      'keyword': 'svt',
    });

    expect(
      uri.toString(),
      'https://api.ecgpro.local/api/v1/public/cases?page=2&keyword=svt',
    );
  });

  test('login sends credentials and parses auth payload', () async {
    late Map<String, dynamic> requestBody;
    final mockHttpClient = MockClient((request) async {
      requestBody = jsonDecode(request.body) as Map<String, dynamic>;
      expect(request.url.path, '/api/v1/auth/login');
      return http.Response(
        jsonEncode({
          'access_token': 'demo-token',
          'token_type': 'bearer',
          'expires_in': 7200,
          'user': {
            'id': 'user-1',
            'username': 'admin',
            'display_name': 'Admin User',
            'is_active': true,
            'is_superuser': true,
            'role_codes': ['admin'],
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final client = EcgApiClient(
      baseUrl: 'https://api.ecgpro.local',
      httpClient: mockHttpClient,
    );

    final response = await client.login(
      username: 'admin',
      password: 'Admin123456',
    );

    expect(requestBody['username'], 'admin');
    expect(requestBody['password'], 'Admin123456');
    expect(response.accessToken, 'demo-token');
    expect(response.user.roleCodes, ['admin']);
  });

  test('fetchCases passes filters and parses paginated items', () async {
    late Uri requestedUri;
    final mockHttpClient = MockClient((request) async {
      requestedUri = request.url;
      expect(request.headers['authorization'], 'Bearer demo-token');
      return http.Response(
        jsonEncode({
          'items': [
            {
              'id': 'case-1',
              'case_code': 'ECG-001',
              'title': '房颤识别',
              'diagnosis': '心房颤动',
              'difficulty': 'intermediate',
              'risk_level': 'high',
              'category_name': '快速性心律失常',
              'status': 'published',
              'is_featured': true,
              'updated_at': '2026-04-26T08:00:00+00:00',
            },
          ],
          'total': 1,
          'page': 2,
          'page_size': 10,
          'has_next': false,
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final client = EcgApiClient(
      baseUrl: 'https://api.ecgpro.local',
      httpClient: mockHttpClient,
    );

    final response = await client.fetchCases(
      'demo-token',
      keyword: '房颤',
      status: CaseStatus.published,
      difficulty: DifficultyLevel.intermediate,
      page: 2,
      pageSize: 10,
    );

    expect(requestedUri.queryParameters['keyword'], '房颤');
    expect(requestedUri.queryParameters['status'], 'published');
    expect(requestedUri.queryParameters['difficulty'], 'intermediate');
    expect(requestedUri.queryParameters['page'], '2');
    expect(response.total, 1);
    expect(response.page, 2);
    expect(response.items.single.caseCode, 'ECG-001');
    expect(response.items.single.status, CaseStatus.published);
  });
}
