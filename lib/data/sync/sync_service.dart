import '../local/app_database.dart';
import '../remote/supabase_service.dart';
import 'package:drift/drift.dart' as drift;

class SyncService {
  final AppDatabase db;
  final SupabaseService supabase;

  SyncService({
    required this.db,
    required this.supabase,
  });

  // =========================================================
  // MAIN SYNC ENTRY POINT
  // =========================================================
  Future<void> syncAll() async {
    print('🔄 [SyncAll] Started. SchoolID: ${db.schoolId}, UserID: ${db.userId}');
    // FK-safe order
    try {
      await _syncTable('teachers', db.teachers);
      await _syncTable('classes', db.classes);
      await _syncTable('students', db.students);
      await _syncTable('subjects', db.subjects);
      await _syncTable('exam_marks', db.examMarks);
      await _syncTable('fee_payments', db.feePayments);
      await _syncTable('notifications', db.notifications);
      print('🏁 [SyncAll] Successfully completed all tables');
    } catch (e) {
      print('❌ [SyncAll] Global error: $e');
      rethrow;
    }
  }

  // =========================================================
  // GENERIC TABLE SYNC
  // =========================================================
  Future<void> _syncTable(String tableName, dynamic driftTable) async {
    // -------------------------------------------------------
    // STEP 1: FETCH PENDING LOCAL RECORDS
    // -------------------------------------------------------
    final pending = await (db.select(driftTable)
          ..where((t) => (t as dynamic).syncStatus.equals('PENDING')))
        .get();

    if (pending.isEmpty) {
      print('ℹ️ [$tableName] No pending records to sync.');
      return;
    }

    print('📦 [$tableName] Found ${pending.length} pending records.');
    final List<Map<String, dynamic>> payload = [];

    // -------------------------------------------------------
    // STEP 2: PREPARE & VALIDATE RECORDS
    // -------------------------------------------------------
    for (final record in pending) {
      final r = record as dynamic;
      
      // 🔒 HARD GUARANTEE: school_id MUST match RLS expected ID
      if (r.schoolId != db.schoolId) {
        print('🔧 [$tableName] Repairing Record ${r.id}: "${r.schoolId}" -> "${db.schoolId}"');
        await db.customUpdate(
          'UPDATE $tableName SET school_id = ? WHERE id = ?',
          variables: [
            drift.Variable(db.schoolId),
            drift.Variable(r.id),
          ],
          updates: {driftTable},
        );
      }

      final Map<String, dynamic> json =
          (r.toJson() as Map<String, dynamic>);
      
      // Update the JSON to use the current correct schoolId
      json['schoolId'] = db.schoolId;

      final Map<String, dynamic> finalized = {};

      // camelCase → snake_case + Date normalization
      json.forEach((key, value) {
        final snakeKey = key.replaceAllMapped(
          RegExp(r'([A-Z])'),
          (m) => '_${m.group(0)!.toLowerCase()}',
        );

        if (value is DateTime) {
          finalized[snakeKey] = value.toIso8601String();
        } else if (value is int &&
            (key.endsWith('At') ||
                key.endsWith('Date') ||
                key == 'dateOfBirth')) {
          finalized[snakeKey] =
              DateTime.fromMillisecondsSinceEpoch(value)
                  .toIso8601String();
        } else {
          finalized[snakeKey] = value;
        }
      });

      // ❌ Never send local-only fields
      finalized.remove('sync_status');

      payload.add(finalized);
    }

    // -------------------------------------------------------
    // STEP 3: UPLOAD TO SUPABASE (UPSERT)
    // -------------------------------------------------------
    try {
      print('⬆️ [$tableName] Uploading payload: $payload');
      await supabase.uploadRecords(tableName, payload);
      print('✅ [$tableName] Successfully uploaded ${payload.length} records.');
    } catch (e) {
      print('❌ [$tableName] Upload FAILED: $e');
      rethrow;
    }

    // -------------------------------------------------------
    // STEP 4: MARK LOCAL RECORDS AS SYNCED
    // -------------------------------------------------------
    for (final record in pending) {
      await db.customUpdate(
        'UPDATE $tableName SET sync_status = ? WHERE id = ?',
        variables: [
          drift.Variable('SYNCED'),
          drift.Variable((record as dynamic).id),
        ],
        updates: {driftTable},
      );
    }

    // -------------------------------------------------------
    // STEP 5: DOWNLOAD REMOTE UPDATES (OPTIONAL)
    // -------------------------------------------------------
    final lastSync = DateTime(2000); // replace with real metadata later
    final updates =
        await supabase.downloadUpdates(tableName, lastSync);

    // Example (optional):
    // for (final row in updates) {
    //   await db.into(driftTable).insertOnConflictUpdate(
    //     driftTable.fromJson(row),
    //   );
    // }
  }
}