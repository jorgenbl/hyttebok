import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Nøkkel i sikker lagring for AI-API-nøkkelen.
const String kAiApiKeyKey = 'ai.apiKey';

/// Abstraksjon over sikker lagring (Keychain på iOS, Keystore på Android).
///
/// API-nøkler lagres KUN her – aldri i klartekst-fil eller i boken.
/// Abstrahert for å kunne injisere en fake i tester.
abstract class SecureKeyStore {
  Future<String?> readKey(String key);
  Future<void> writeKey(String key, String value);
  Future<void> deleteKey(String key);
}

/// Standardimplementasjon over [FlutterSecureStorage].
class FlutterSecureKeyStore implements SecureKeyStore {
  FlutterSecureKeyStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> readKey(String key) => _storage.read(key: key);

  @override
  Future<void> writeKey(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> deleteKey(String key) => _storage.delete(key: key);
}
