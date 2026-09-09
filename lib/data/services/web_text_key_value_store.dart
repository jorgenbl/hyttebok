import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'text_key_value_store.dart';

/// [TextKeyValueStore] for web: bruker nettleserens `localStorage`.
///
/// Ligger i en egen fil (betinget import) siden `dart:js_interop` ikke
/// kompileres på mobile plattformer.
class WebLocalStorageTextStore implements TextKeyValueStore {
  const WebLocalStorageTextStore({this.key = 'hyttebok.settings'});

  /// Nøkkelen i `localStorage`.
  final String key;

  JSObject? get _storage => globalContext['localStorage'] as JSObject?;

  @override
  String? load() {
    final storage = _storage;
    if (storage == null) return null;
    return storage.callMethod<JSString?>('getItem'.toJS, key.toJS)?.toDart;
  }

  @override
  Future<void> save(String value) async {
    _storage?.callMethod('setItem'.toJS, key.toJS, value.toJS);
  }
}
