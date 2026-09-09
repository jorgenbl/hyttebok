import 'app_storages.dart';
import 'in_memory_book_storage.dart';
import 'web_text_key_value_store.dart';

/// Web: ingen filsystem – bøkene holdes i minnet under økten (banner i
/// biblioteket forklarer eksport/import), innstillingene i `localStorage`.
Future<AppStorages> createStorages() async {
  return AppStorages(
    books: InMemoryBookStorage(),
    settings: const WebLocalStorageTextStore(),
  );
}
