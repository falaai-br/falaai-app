import 'package:falaai_app/core/database_key.dart';
import 'package:falaai_core/falaai_core.dart';
import 'package:flutter_test/flutter_test.dart';

/// Handle do core que não toca a biblioteca nativa.
class FakeCore extends Fake implements FalaaiCore {}

/// [SecretStore] em memória.
class MemorySecretStore implements SecretStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String name) async => values[name];

  @override
  Future<void> write(String name, String value) async => values[name] = value;
}
