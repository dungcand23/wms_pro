import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;

import 'appwrite_config.dart';

class AppwriteService {
  final Client client;
  final Account account;
  final Databases db;
  final Realtime realtime;
  final Storage storage;
  final Functions functions;

  AppwriteService._(this.client, this.account, this.db, this.realtime, this.storage, this.functions);

  static AppwriteService fromConfig(AppwriteConfig cfg, {bool selfSigned = true}) {
    final client = Client()
      ..setEndpoint(cfg.endpoint)
      ..setProject(cfg.projectId);

    if (selfSigned) {
      client.setSelfSigned(status: true);
    }

    return AppwriteService._(
      client,
      Account(client),
      Databases(client),
      Realtime(client),
      Storage(client),
      Functions(client),
    );
  }

  Future<models.Session> loginEmail(String email, String password) {
    return account.createEmailPasswordSession(email: email, password: password);
  }

  Future<void> logout() => account.deleteSession(sessionId: 'current');

  Future<models.User> me() => account.get();
}
