import 'package:dio/dio.dart';
import 'package:epub_view/epub_view.dart';

import '../../../core/api_client.dart';
import '../../../core/api_exception.dart';

final class EpubDocumentRepository {
  const EpubDocumentRepository(this._client);
  final ApiClient _client;

  Future<EpubBook> fetch(String storySlug) async {
    try {
      final response = await _client.dio.get<List<int>>(
        'stories/${Uri.encodeComponent(storySlug)}/epub-stream/',
        options: Options(responseType: ResponseType.bytes),
      );
      return EpubReader.readBook(response.data!);
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
  }
}
