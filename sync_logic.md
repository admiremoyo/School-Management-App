# Sync Logic Pseudocode & Rules

## 1. Local Persistence (Offline-First)
- Every write operation (Create/Update) is performed on the local SQLite database first.
- The `sync_status` column is set to `PENDING`.
- `updated_at` is set to the current local timestamp.

## 2. Sync Trigger (Manual or Background)
When the user clicks "Sync Now":

### Phase A: Upload (Outbound)
1. Query all tables for records where `sync_status == 'PENDING'`.
2. Push these records to Supabase using a bulk `UPSERT` operation.
   - *Conflict Resolution (Cloud Side):* Supabase UPSERT ensures that if a record exists, it's updated.
3. Upon success, update the local `sync_status` to `SYNCED`.

### Phase B: Download (Inbound)
1. Retrieve the `last_sync_timestamp` (stored locally).
2. Fetch records from Supabase tables where `updated_at > last_sync_timestamp`.
3. For each fetched record:
   - Check if the local record exists.
   - **Rule: Last Updated Wins.**
   - If `remote.updated_at > local.updated_at`, overwrite the local record.
   - Otherwise, keep the local version (it will be pushed in the next Phase A if it was modified locally).

## 3. Handling Conflicts
- **Strict Rule:** Last writer wins based on the `updated_at` timestamp.
- This approach is simple and effective for school environments where a single teacher/admin usually manages specific sets of data.

## 4. Auth Continuity
- Use `supabase_flutter`'s persistent session management.
- On app launch, check if a valid session exists.
- If offline, allow access to local data if a session was previously active.
