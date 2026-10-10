import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:fleetopt_ai/models/models.dart';

class OfflineService {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'fleetopt_offline.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cached_duties (
            id TEXT PRIMARY KEY,
            duty_code TEXT,
            start_time TEXT,
            end_time TEXT,
            total_driving_minutes INTEGER,
            status TEXT,
            is_locked INTEGER,
            assigned_vehicle TEXT,
            json_payload TEXT,
            synced_at TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE offline_action_queue (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            action_type TEXT,
            payload TEXT,
            created_at TEXT
          )
        ''');
      },
    );
  }

  static Future<void> cacheDuties(List<DriverDutyModel> duties) async {
    try {
      final db = await database;
      await db.delete('cached_duties');
      final now = DateTime.now().toIso8601String();

      for (var d in duties) {
        await db.insert('cached_duties', {
          'id': d.id,
          'duty_code': d.dutyCode,
          'start_time': d.startTime,
          'end_time': d.endTime,
          'total_driving_minutes': d.totalDrivingMinutes,
          'status': d.status,
          'is_locked': d.isLocked ? 1 : 0,
          'assigned_vehicle': d.assignedVehicle,
          'json_payload': jsonEncode({
            'id': d.id,
            'duty_code': d.dutyCode,
            'start_time': d.startTime,
            'end_time': d.endTime,
            'total_driving_minutes': d.totalDrivingMinutes,
            'status': d.status,
            'is_locked': d.isLocked,
            'assigned_vehicle': d.assignedVehicle,
            'trips': d.trips,
            'breaks': d.breaks,
          }),
          'synced_at': now,
        });
      }
    } catch (e) {
      // Offline fallback handling
    }
  }

  static Future<List<DriverDutyModel>> getCachedDuties() async {
    try {
      final db = await database;
      final maps = await db.query('cached_duties');
      return maps.map((m) {
        final raw = jsonDecode(m['json_payload'] as String);
        return DriverDutyModel.fromJson(raw);
      }).toList();
    } catch (e) {
      return [];
    }
  }
}
