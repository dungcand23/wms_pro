import 'dart:typed_data';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;

import 'appwrite_ids.dart';
import 'appwrite_service.dart';

class AttachmentsRemote {
  final AppwriteService remote;
  AttachmentsRemote(this.remote);

  Future<models.File> upload({
    required String fileId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final input = InputFile.fromBytes(bytes: bytes, filename: fileName);

    return remote.storage.createFile(
      bucketId: AppwriteIds.bucketAttachments,
      fileId: fileId,
      file: input,
    );
  }
}
