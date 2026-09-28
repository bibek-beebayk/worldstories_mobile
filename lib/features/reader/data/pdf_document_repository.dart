import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/api_client.dart';
import '../../../core/api_exception.dart';

final class PdfDocumentRepository {
  const PdfDocumentRepository(this._client);
  final ApiClient _client;

  Future<Uint8List> fetchBytes(String storySlug) async {
    try {
      final response = await _client.dio.get<List<int>>(
        'stories/${Uri.encodeComponent(storySlug)}/pdf-stream/',
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
