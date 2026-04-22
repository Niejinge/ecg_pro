class EcgApiClient {
  const EcgApiClient({
    required this.baseUrl,
  });

  final String baseUrl;

  Uri buildUri(String path, [Map<String, dynamic>? queryParameters]) {
    return Uri.parse(baseUrl).replace(
      path: path,
      queryParameters: queryParameters?.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
    );
  }
}
