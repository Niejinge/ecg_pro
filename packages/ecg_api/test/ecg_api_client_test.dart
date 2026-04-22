import 'package:ecg_api/ecg_api.dart';
import 'package:test/test.dart';

void main() {
  test('buildUri appends path and query parameters', () {
    const client = EcgApiClient(baseUrl: 'https://api.ecgpro.local');

    final uri = client.buildUri(
      '/api/v1/public/cases',
      {'page': 2, 'keyword': 'svt'},
    );

    expect(uri.toString(), 'https://api.ecgpro.local/api/v1/public/cases?page=2&keyword=svt');
  });
}
