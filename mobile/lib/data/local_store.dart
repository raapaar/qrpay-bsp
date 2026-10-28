import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as path;

String newId() {
  final r = Random.secure();
  return '${DateTime.now().microsecondsSinceEpoch}-${List.generate(12, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
}

class LocalStore extends ChangeNotifier {
  final Database? database;
  Map<String, dynamic> state;
  Future<void> _writes = Future.value();
  LocalStore._(this.database, this.state);
  factory LocalStore.memory() => LocalStore._(null, {});

  static Future<LocalStore> open({
    DatabaseFactory? factory,
    String? filename,
  }) async {
    final f = factory ?? databaseFactory;
    final db = await f.openDatabase(
      filename ?? path.join(await f.getDatabasesPath(), 'qrpay_v4.db'),
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async {
          await db.execute(
            'CREATE TABLE snapshot (id INTEGER PRIMARY KEY CHECK(id = 1), data TEXT NOT NULL)',
          );
        },
      ),
    );
    final rows = await db.query('snapshot', where: 'id = ?', whereArgs: [1]);
    return LocalStore._(
      db,
      rows.isEmpty
          ? {}
          : Map<String, dynamic>.from(
            jsonDecode(rows.first['data'] as String) as Map,
          ),
    );
  }

  List<Map<String, dynamic>> items(String key) =>
      (state[key] as List? ?? [])
          .map((x) => Map<String, dynamic>.from(x as Map))
          .toList();
  String setting(String key, [String fallback = '']) =>
      state[key] as String? ?? fallback;
  bool enabled(String key) => state[key] == true;

  Future<void> _change(Map<String, dynamic> Function() change) {
    final pending = _writes.then((_) async {
      final next = change();
      if (database != null) {
        await database!.insert('snapshot', {
          'id': 1,
          'data': jsonEncode(next),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      state = next;
      notifyListeners();
    });
    _writes = pending.catchError((Object _) {});
    return pending;
  }

  Future<void> set(String key, dynamic value) =>
      _change(() => {...state, key: value});
  Future<void> put(String key, Map<String, dynamic> value) => _change(() {
    final list = items(key)..removeWhere((x) => x['id'] == value['id']);
    list.insert(0, value);
    if (list.length > 2000) {
      throw StateError(
        'This collection is full. Export and remove older records before adding more.',
      );
    }
    return {...state, key: list};
  });
  Future<void> remove(String key, String id) => _change(
    () => {...state, key: items(key)..removeWhere((x) => x['id'] == id)},
  );
  Future<void> clear() => _change(() => {});
  Future<void> flush() => _writes;
  Future<void> close() async {
    await _writes;
    await database?.close();
    dispose();
  }
}
