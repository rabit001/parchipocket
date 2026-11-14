import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

abstract interface class UpdateHttpTransport {
  Future<UpdateHttpResponse> get(Uri uri, {required bool followRedirects});

  void close();
}

class UpdateHttpResponse {
  const UpdateHttpResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
    this.redirectLocation,
  });

  final int statusCode;
  final Map<String, String> headers;
  final Stream<List<int>> body;
  final String? redirectLocation;

  int? get contentLength {
    final values = headers.entries
        .where(
          (entry) => entry.key.toLowerCase() == HttpHeaders.contentLengthHeader,
        )
        .map((entry) => entry.value)
        .toList(growable: false);
    return values.isEmpty ? null : int.tryParse(values.first);
  }
}

class UpdateHttpException implements Exception {
  const UpdateHttpException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => 'UpdateHttpException($statusCode): $message';
}

class UpdateNetworkException implements Exception {
  const UpdateNetworkException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DartIoUpdateHttpTransport implements UpdateHttpTransport {
  DartIoUpdateHttpTransport({HttpClient? client})
    : _client = client ?? HttpClient() {
    _client.connectionTimeout = const Duration(seconds: 12);
    _client.userAgent = 'ParchiPocket-Android-Updater';
  }

  final HttpClient _client;

  @override
  Future<UpdateHttpResponse> get(
    Uri uri, {
    required bool followRedirects,
  }) async {
    final request = await _client
        .getUrl(uri)
        .timeout(const Duration(seconds: 15));
    request.followRedirects = followRedirects;
    request.headers.set(
      HttpHeaders.acceptHeader,
      'application/vnd.github+json',
    );
    final response = await request.close().timeout(const Duration(seconds: 25));
    final headers = <String, String>{};
    response.headers.forEach((name, values) {
      headers[name] = values.join(',');
    });
    return UpdateHttpResponse(
      statusCode: response.statusCode,
      headers: headers,
      body: response,
      redirectLocation: response.headers.value(HttpHeaders.locationHeader),
    );
  }

  @override
  void close() => _client.close(force: true);
}

const Set<String> allowedGithubAssetHosts = <String>{
  'github.com',
  'release-assets.githubusercontent.com',
  'objects.githubusercontent.com',
};

bool isAllowedGithubAssetUri(Uri uri) =>
    uri.scheme == 'https' &&
    allowedGithubAssetHosts.contains(uri.host.toLowerCase()) &&
    (uri.port == 443 || !uri.hasPort) &&
    uri.userInfo.isEmpty;

Future<UpdateHttpResponse> getFollowingGithubRedirects(
  UpdateHttpTransport transport,
  Uri initialUri,
) async {
  if (!isAllowedGithubAssetUri(initialUri)) {
    throw const FormatException(
      'Update asset URL is not a trusted GitHub URL.',
    );
  }
  var uri = initialUri;
  for (var redirectCount = 0; redirectCount <= 4; redirectCount++) {
    final response = await transport
        .get(uri, followRedirects: false)
        .timeout(const Duration(seconds: 30));
    if (response.statusCode < 300 || response.statusCode >= 400) {
      return response;
    }
    final location = response.redirectLocation;
    await response.body.drain<void>();
    if (location == null || redirectCount == 4) {
      throw const UpdateNetworkException(
        'The GitHub download redirect failed.',
      );
    }
    uri = uri.resolve(location);
    if (!isAllowedGithubAssetUri(uri)) {
      throw const FormatException(
        'GitHub redirected to an untrusted download host.',
      );
    }
  }
  throw const UpdateNetworkException('Too many GitHub download redirects.');
}

Future<Uint8List> readUpdateResponse(
  UpdateHttpResponse response, {
  required int maxBytes,
}) async {
  final declaredLength = response.contentLength;
  if (declaredLength != null && declaredLength > maxBytes) {
    throw const FormatException('Update metadata is larger than expected.');
  }
  final bytes = BytesBuilder(copy: false);
  var length = 0;
  await for (final chunk in response.body.timeout(
    const Duration(seconds: 30),
  )) {
    length += chunk.length;
    if (length > maxBytes) {
      throw const FormatException('Update metadata is larger than expected.');
    }
    bytes.add(chunk);
  }
  return bytes.takeBytes();
}
