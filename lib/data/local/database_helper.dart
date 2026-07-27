import 'dart:math';

import 'package:ahs/data/models/app_notification.dart';
import 'package:ahs/data/models/harvest_event.dart';
import 'package:ahs/data/models/plant_model.dart';
import 'package:ahs/data/models/plant_slot.dart';
import 'package:ahs/data/models/sensor_snapshot.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

// ─────────────────────────────────────────────
//  DatabaseHelper  (singleton)
// ─────────────────────────────────────────────
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static Database? _db;

  Future<Database> get _database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'ahs.db');
    return openDatabase(
      path,
      version: 3,
      onCreate: (db, _) async {
        // ── plants ──
        await db.execute('''
          CREATE TABLE plants (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            name        TEXT    NOT NULL,
            description TEXT    NOT NULL,
            imagePath   TEXT,
            addedDate   TEXT    NOT NULL,
            harvestDate TEXT,
            actualHarvestDate TEXT,
            quantity    INTEGER NOT NULL DEFAULT 1,
            plantType   TEXT    NOT NULL DEFAULT 'single',
            totalHarvestWeight REAL NOT NULL DEFAULT 0,
            harvestCount INTEGER NOT NULL DEFAULT 0,
            isActive    INTEGER NOT NULL DEFAULT 0,
            isHarvested INTEGER NOT NULL DEFAULT 0
          )
        ''');

        // ── sensor logs ──
        await db.execute('''
          CREATE TABLE sensor_logs (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            plantId     INTEGER,
            plantName   TEXT,
            timestamp   TEXT    NOT NULL,
            temperature REAL,
            humidity    REAL,
            ph          REAL,
            tds         REAL,
            waterLevel  REAL
          )
        ''');
        await _createPlantSlotsTable(db);
        await _createHarvestEventsTable(db);
        await _createNotificationsTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _addColumnIfMissing(
            db,
            table: 'plants',
            column: 'actualHarvestDate',
            definition: 'TEXT',
          );
        }
        if (oldVersion < 3) {
          await _addColumnIfMissing(
            db,
            table: 'plants',
            column: 'quantity',
            definition: 'INTEGER NOT NULL DEFAULT 1',
          );
          await _addColumnIfMissing(
            db,
            table: 'plants',
            column: 'plantType',
            definition: "TEXT NOT NULL DEFAULT 'single'",
          );
          await _addColumnIfMissing(
            db,
            table: 'plants',
            column: 'totalHarvestWeight',
            definition: 'REAL NOT NULL DEFAULT 0',
          );
          await _addColumnIfMissing(
            db,
            table: 'plants',
            column: 'harvestCount',
            definition: 'INTEGER NOT NULL DEFAULT 0',
          );
          await _createPlantSlotsTable(db);
          await _createHarvestEventsTable(db);
        }
      },
      onOpen: (db) async {
        await _createBatteryStateTable(db);
        await _createAppSettingsTable(db);
        await _createPlantSlotsTable(db);
        await _createHarvestEventsTable(db);
        await _createNotificationsTable(db);
        await _ensureSchema(db);
        await _createIndexes(db);
        await _ensureSlotsForExistingPlants(db);
      },
    );
  }

  Future<void> _ensureSchema(Database db) async {
    await _addColumnIfMissing(
      db,
      table: 'plants',
      column: 'actualHarvestDate',
      definition: 'TEXT',
    );
    await _addColumnIfMissing(
      db,
      table: 'plants',
      column: 'quantity',
      definition: 'INTEGER NOT NULL DEFAULT 1',
    );
    await _addColumnIfMissing(
      db,
      table: 'plants',
      column: 'plantType',
      definition: "TEXT NOT NULL DEFAULT 'single'",
    );
    await _addColumnIfMissing(
      db,
      table: 'plants',
      column: 'totalHarvestWeight',
      definition: 'REAL NOT NULL DEFAULT 0',
    );
    await _addColumnIfMissing(
      db,
      table: 'plants',
      column: 'harvestCount',
      definition: 'INTEGER NOT NULL DEFAULT 0',
    );
    await _addColumnIfMissing(
      db,
      table: 'sensor_logs',
      column: 'plantId',
      definition: 'INTEGER',
    );
    await _addColumnIfMissing(
      db,
      table: 'sensor_logs',
      column: 'plantName',
      definition: 'TEXT',
    );
    await _addColumnIfMissing(
      db,
      table: 'app_notifications',
      column: 'sourceTimestamp',
      definition: 'TEXT',
    );
  }

  Future<void> _addColumnIfMissing(
    Database db, {
    required String table,
    required String column,
    required String definition,
  }) async {
    final columns = await db.rawQuery('PRAGMA table_info($table)');
    final exists = columns.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  Future<void> _createBatteryStateTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS battery_state (
        id             INTEGER PRIMARY KEY CHECK (id = 1),
        lastFullCharge TEXT    NOT NULL
      )
    ''');
    await _ensureBatteryRow(db);
  }

  Future<void> _createAppSettingsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_settings (
        settingKey   TEXT PRIMARY KEY,
        settingValue TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createPlantSlotsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS plant_slots (
        plantId   INTEGER NOT NULL,
        position  INTEGER NOT NULL,
        status    TEXT    NOT NULL DEFAULT 'empty',
        updatedAt TEXT    NOT NULL,
        PRIMARY KEY (plantId, position)
      )
    ''');
  }

  Future<void> _createHarvestEventsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS harvest_events (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        plantId       INTEGER NOT NULL,
        plantName     TEXT    NOT NULL,
        harvestedAt   TEXT    NOT NULL,
        weightKg      REAL    NOT NULL DEFAULT 0,
        survivedCount INTEGER NOT NULL DEFAULT 0,
        totalCount    INTEGER NOT NULL DEFAULT 0,
        lifeRate      REAL    NOT NULL DEFAULT 0,
        markedDone    INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _createNotificationsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_notifications (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        plantId         INTEGER,
        title           TEXT    NOT NULL,
        message         TEXT    NOT NULL,
        type            TEXT    NOT NULL,
        createdAt       TEXT    NOT NULL,
        isRead          INTEGER NOT NULL DEFAULT 0,
        sourceTimestamp TEXT
      )
    ''');
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS notification_source_idx
      ON app_notifications(type, sourceTimestamp)
      WHERE sourceTimestamp IS NOT NULL
    ''');
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute('''
      CREATE INDEX IF NOT EXISTS sensor_logs_plant_time_idx
      ON sensor_logs(plantId, timestamp)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS harvest_events_plant_time_idx
      ON harvest_events(plantId, harvestedAt)
    ''');
  }

  Future<void> _ensureSlotsForExistingPlants(Database db) async {
    final rows = await db.query('plants');
    for (final row in rows) {
      await _ensurePlantSlots(
        db,
        plantId: row['id'] as int,
        quantity: ((row['quantity'] as int?) ?? 1).clamp(1, 6),
      );
    }
  }

  Future<void> _ensurePlantSlots(
    DatabaseExecutor db, {
    required int plantId,
    required int quantity,
  }) async {
    final now = DateTime.now().toIso8601String();
    for (var position = 1; position <= 6; position++) {
      await db.insert('plant_slots', {
        'plantId': plantId,
        'position': position,
        'status': position <= quantity
            ? PlantSlotStatus.alive.name
            : PlantSlotStatus.empty.name,
        'updatedAt': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }

  Future<void> _ensureBatteryRow(Database db) async {
    await db.insert('battery_state', {
      'id': 1,
      'lastFullCharge': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<String?> getAppSetting(String key) async {
    final db = await _database;
    final rows = await db.query(
      'app_settings',
      columns: ['settingValue'],
      where: 'settingKey = ?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['settingValue'] as String;
  }

  Future<void> setAppSetting(String key, String value) async {
    final db = await _database;
    await db.insert('app_settings', {
      'settingKey': key,
      'settingValue': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, int>> getStorageStats() async {
    final db = await _database;
    Future<int> count(String table) async {
      final result = await db.rawQuery('SELECT COUNT(*) AS total FROM $table');
      return Sqflite.firstIntValue(result) ?? 0;
    }

    return {
      'plants': await count('plants'),
      'sensorLogs': await count('sensor_logs'),
      'harvests': await count('harvest_events'),
      'notifications': await count('app_notifications'),
    };
  }

  Future<int?> insertNotification(AppNotification notification) async {
    final db = await _database;
    final values = notification.toMap()..remove('id');
    final id = await db.insert(
      'app_notifications',
      values,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    return id == 0 ? null : id;
  }

  Future<List<AppNotification>> getNotifications({int limit = 60}) async {
    final db = await _database;
    final rows = await db.query(
      'app_notifications',
      orderBy: 'createdAt DESC',
      limit: limit,
    );
    return rows.map(AppNotification.fromMap).toList();
  }

  Future<int> getUnreadNotificationCount() async {
    final db = await _database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM app_notifications WHERE isRead = 0',
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> markNotificationRead(int id) async {
    final db = await _database;
    await db.update(
      'app_notifications',
      {'isRead': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markAllNotificationsRead() async {
    final db = await _database;
    await db.update('app_notifications', {'isRead': 1});
  }

  // ══════════════════════════════════════════
  //  PLANTS
  // ══════════════════════════════════════════

  Future<int> insertPlant(PlantModel plant) async {
    final db = await _database;
    final id = await db.insert('plants', plant.toMap());
    await _ensurePlantSlots(db, plantId: id, quantity: plant.quantity);
    return id;
  }

  Future<List<PlantModel>> getAllPlants() async {
    final db = await _database;
    final rows = await db.query('plants', orderBy: 'addedDate DESC');
    return rows.map(PlantModel.fromMap).toList();
  }

  Future<PlantModel?> getActivePlant() async {
    final db = await _database;
    final rows = await db.query('plants', where: 'isActive = 1', limit: 1);
    return rows.isEmpty ? null : PlantModel.fromMap(rows.first);
  }

  Future<void> updatePlant(PlantModel plant) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.update(
        'plants',
        plant.toMap(),
        where: 'id = ?',
        whereArgs: [plant.id],
      );
      if (plant.id != null) {
        await _ensurePlantSlots(
          txn,
          plantId: plant.id!,
          quantity: plant.quantity,
        );
        await _syncSlotQuantity(
          txn,
          plantId: plant.id!,
          quantity: plant.quantity,
        );
      }
    });
  }

  Future<void> deletePlant(int id) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.delete('plants', where: 'id = ?', whereArgs: [id]);
      await txn.delete('plant_slots', where: 'plantId = ?', whereArgs: [id]);
      await txn.delete('harvest_events', where: 'plantId = ?', whereArgs: [id]);
    });
  }

  /// Deactivate all plants, then mark the given one active.
  Future<void> setActivePlant(int plantId) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.update('plants', {'isActive': 0});
      final changed = await txn.update(
        'plants',
        {'isActive': 1},
        where: 'id = ? AND isHarvested = 0',
        whereArgs: [plantId],
      );
      if (changed == 0) {
        throw StateError('Only growing plants can be active.');
      }
    });
  }

  Future<void> markHarvested(int plantId) async {
    final db = await _database;
    await db.update(
      'plants',
      {
        'isHarvested': 1,
        'isActive': 0,
        'actualHarvestDate': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [plantId],
    );
  }

  Future<void> _syncSlotQuantity(
    DatabaseExecutor db, {
    required int plantId,
    required int quantity,
  }) async {
    final now = DateTime.now().toIso8601String();
    await db.update(
      'plant_slots',
      {'status': PlantSlotStatus.empty.name, 'updatedAt': now},
      where: 'plantId = ? AND position > ?',
      whereArgs: [plantId, quantity],
    );
    await db.update(
      'plant_slots',
      {'status': PlantSlotStatus.alive.name, 'updatedAt': now},
      where: 'plantId = ? AND position <= ? AND status = ?',
      whereArgs: [plantId, quantity, PlantSlotStatus.empty.name],
    );
  }

  Future<List<PlantSlot>> getPlantSlots(int plantId) async {
    final db = await _database;
    final plantRows = await db.query(
      'plants',
      where: 'id = ?',
      whereArgs: [plantId],
      limit: 1,
    );
    final quantity = plantRows.isEmpty
        ? 1
        : ((plantRows.first['quantity'] as int?) ?? 1).clamp(1, 6);
    await _ensurePlantSlots(db, plantId: plantId, quantity: quantity);
    final rows = await db.query(
      'plant_slots',
      where: 'plantId = ?',
      whereArgs: [plantId],
      orderBy: 'position ASC',
    );
    return rows.map(PlantSlot.fromMap).toList();
  }

  Future<void> updatePlantSlotStatus(
    int plantId,
    int position,
    PlantSlotStatus status,
  ) async {
    final db = await _database;
    await db.update(
      'plant_slots',
      {'status': status.name, 'updatedAt': DateTime.now().toIso8601String()},
      where: 'plantId = ? AND position = ?',
      whereArgs: [plantId, position],
    );
  }

  Future<void> swapPlantSlotStatuses(
    int plantId,
    int firstPosition,
    int secondPosition,
  ) async {
    if (firstPosition == secondPosition) return;

    final db = await _database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'plant_slots',
        where: 'plantId = ? AND position IN (?, ?)',
        whereArgs: [plantId, firstPosition, secondPosition],
      );
      if (rows.length != 2) {
        throw StateError('Plant positions are incomplete.');
      }

      String statusOf(int position) => rows
          .firstWhere((row) => row['position'] == position)['status']
          .toString();

      final firstStatus = statusOf(firstPosition);
      final secondStatus = statusOf(secondPosition);
      final now = DateTime.now().toIso8601String();

      await txn.update(
        'plant_slots',
        {'status': secondStatus, 'updatedAt': now},
        where: 'plantId = ? AND position = ?',
        whereArgs: [plantId, firstPosition],
      );
      await txn.update(
        'plant_slots',
        {'status': firstStatus, 'updatedAt': now},
        where: 'plantId = ? AND position = ?',
        whereArgs: [plantId, secondPosition],
      );
    });
  }

  Future<void> updatePlantQuantity(PlantModel plant, int quantity) async {
    await updatePlant(plant.copyWith(quantity: quantity.clamp(1, 6)));
  }

  Future<int> getAliveSlotCount(int plantId) async {
    final db = await _database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM plant_slots WHERE plantId = ? AND status = ?',
      [plantId, PlantSlotStatus.alive.name],
    );
    return (result.first['count'] as int?) ?? 0;
  }

  Future<List<HarvestEvent>> getHarvestEvents({int? plantId}) async {
    final db = await _database;
    final rows = await db.query(
      'harvest_events',
      where: plantId == null ? null : 'plantId = ?',
      whereArgs: plantId == null ? null : [plantId],
      orderBy: 'harvestedAt DESC',
    );
    return rows.map(HarvestEvent.fromMap).toList();
  }

  Future<HarvestEvent> recordHarvest({
    required PlantModel plant,
    required double weightKg,
    required bool markDone,
  }) async {
    final plantId = plant.id;
    if (plantId == null) {
      throw StateError('Cannot harvest a plant before it is saved.');
    }

    final db = await _database;
    final survivedCount = await getAliveSlotCount(plantId);
    final totalCount = plant.quantity.clamp(1, 6);
    final lifeRate = totalCount == 0 ? 0.0 : (survivedCount / totalCount) * 100;
    final now = DateTime.now();
    final event = HarvestEvent(
      plantId: plantId,
      plantName: plant.name,
      harvestedAt: now,
      weightKg: weightKg,
      survivedCount: survivedCount,
      totalCount: totalCount,
      lifeRate: lifeRate,
      markedDone: markDone,
    );

    await db.transaction((txn) async {
      await txn.insert('harvest_events', event.toMap());
      await txn.update(
        'plants',
        {
          'totalHarvestWeight': plant.totalHarvestWeight + weightKg,
          'harvestCount': plant.harvestCount + 1,
          if (markDone) 'isHarvested': 1,
          if (markDone) 'isActive': 0,
          if (markDone) 'actualHarvestDate': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [plantId],
      );
    });

    return event;
  }

  // ══════════════════════════════════════════
  //  SENSOR LOGS
  // ══════════════════════════════════════════

  Future<void> insertLog(
    SensorSnapshot snap, {
    int? plantId,
    String? plantName,
  }) async {
    final db = await _database;
    final timestamp = snap.timestamp.toIso8601String();
    final existing = await db.query(
      'sensor_logs',
      columns: ['id'],
      where: plantId == null
          ? 'timestamp = ? AND plantId IS NULL'
          : 'timestamp = ? AND plantId = ?',
      whereArgs: plantId == null ? [timestamp] : [timestamp, plantId],
      limit: 1,
    );
    if (existing.isNotEmpty) return;

    await db.insert(
      'sensor_logs',
      snap.toSqlMap(plantId: plantId, plantName: plantName),
    );
  }

  /// Fetch logs for a given calendar day.
  Future<List<Map<String, dynamic>>> getLogsForDay(
    int year,
    int month,
    int day, {
    int? plantId,
  }) async {
    final db = await _database;
    final date = '$year-${_p(month)}-${_p(day)}';
    final where = plantId == null
        ? 'timestamp LIKE ?'
        : 'timestamp LIKE ? AND plantId = ?';
    final whereArgs = plantId == null ? ['$date%'] : ['$date%', plantId];
    return db.query(
      'sensor_logs',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'timestamp ASC',
    );
  }

  Future<List<DateTime>> getLogDatesForPlant(int plantId) async {
    final db = await _database;
    final rows = await db.query(
      'sensor_logs',
      columns: ['timestamp'],
      where: 'plantId = ?',
      whereArgs: [plantId],
      orderBy: 'timestamp DESC',
    );

    final seen = <String>{};
    final dates = <DateTime>[];
    for (final row in rows) {
      final timestamp = DateTime.tryParse(row['timestamp']?.toString() ?? '');
      if (timestamp == null) continue;
      final key =
          '${timestamp.year}-${_p(timestamp.month)}-${_p(timestamp.day)}';
      if (seen.add(key)) {
        dates.add(DateTime(timestamp.year, timestamp.month, timestamp.day));
      }
    }
    return dates;
  }

  Future<List<Map<String, dynamic>>> getLogsForPlant(
    int plantId, {
    int limit = 500,
  }) async {
    final db = await _database;
    final rows = await db.query(
      'sensor_logs',
      where: 'plantId = ?',
      whereArgs: [plantId],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return rows.reversed.toList();
  }

  Future<int> seedSampleLogsForPlant(PlantModel plant, {int count = 72}) async {
    final plantId = plant.id;
    if (plantId == null) return 0;

    final db = await _database;
    final random = Random(plantId);
    final now = DateTime.now();
    var inserted = 0;

    await db.transaction((txn) async {
      for (var i = 0; i < count; i++) {
        final wave = sin(i / 5);
        final timestamp = now.subtract(Duration(minutes: (count - i) * 10));
        final snap = SensorSnapshot(
          temperature: 25.8 + wave * 1.4 + random.nextDouble() * 0.6,
          humidity: 68 + cos(i / 4) * 7 + random.nextDouble() * 2,
          ph: i % 19 == 0 ? 7.8 : 6.25 + wave * 0.28,
          tds: i % 23 == 0 ? 165 : 760 + sin(i / 3) * 95,
          waterLevel: i % 29 == 0 ? 22.5 : 9.5 + cos(i / 6) * 1.7,
          timestamp: timestamp,
        );
        final map = snap.toSqlMap(plantId: plantId, plantName: plant.name);
        final existing = await txn.query(
          'sensor_logs',
          columns: ['id'],
          where: 'timestamp = ? AND plantId = ?',
          whereArgs: [map['timestamp'], plantId],
          limit: 1,
        );
        if (existing.isNotEmpty) continue;
        await txn.insert('sensor_logs', map);
        inserted++;
      }
    });

    return inserted;
  }

  String _p(int n) => n.toString().padLeft(2, '0');
  // ══════════════════════════════════════════
  //  BATTERY STATE
  // ══════════════════════════════════════════

  /// Returns elapsed hours since last full charge. Max life = 3 hours.
  Future<double> getBatteryPercent() async {
    final db = await _database;
    await _ensureBatteryRow(db);
    final rows = await db.query('battery_state', where: 'id = 1', limit: 1);
    if (rows.isEmpty) return 100.0;
    final lastCharge = DateTime.parse(rows.first['lastFullCharge'] as String);
    final elapsed = DateTime.now().difference(lastCharge);
    const batteryLifeHours = 3.0;
    final percent = 1.0 - (elapsed.inSeconds / (batteryLifeHours * 3600));
    return (percent * 100).clamp(0.0, 100.0);
  }

  Future<DateTime> getLastFullCharge() async {
    final db = await _database;
    await _ensureBatteryRow(db);
    final rows = await db.query('battery_state', where: 'id = 1', limit: 1);
    if (rows.isEmpty) return DateTime.now();
    return DateTime.parse(rows.first['lastFullCharge'] as String);
  }

  /// Call this when the user marks the device as "fully charged".
  Future<void> resetBattery() async {
    final db = await _database;
    await db.insert('battery_state', {
      'id': 1,
      'lastFullCharge': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
