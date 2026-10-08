import 'dart:isolate';

import 'package:dio/dio.dart';

import '../../../core/api_client.dart';
import '../../../core/api_exception.dart';
import 'epub_book.dart';

final class EpubDocumentRepository {
  const EpubDocumentRepository(this._client);
  final ApiClient _client;

  /// Downloads the story's EPUB and parses it on a background isolate, so a
  /// large book doesn't freeze the UI while it unzips.
  Future<EpubBookData> fetch(String storySlug) async {
    final List<int> bytes;
    try {
      final response = await _client.dio.get<List<int>>(
        'stories/${Uri.encodeComponent(storySlug)}/epub-stream/',
        options: Options(responseType: ResponseType.bytes),
      );
      bytes = response.data!;
    } on DioException catch (error) {
      throw ApiException.fromDio(error);
    }
    return Isolate.run(() => parseEpubBook(bytes));
  }
}
