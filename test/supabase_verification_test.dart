import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EmptyLocalStorage extends LocalStorage {
  const EmptyLocalStorage();
  @override
  Future<void> initialize() async {}
  @override
  Future<String?> caught() async => null;
  @override
  Future<void> hasAccessToken() async {}
  @override
  Future<String?> accessToken() async => null;
  @override
  Future<void> removePersistedSession() async {}
  @override
  Future<void> persistSession(String persistSessionString) async {}
}

void main() {
  test('Supabase Sync Verification', () async {
    print('🚀 Starting Supabase Sync Verification...');
    
    const supabaseUrl = 'https://cnsvtkjfqlyhisviczop.supabase.co';
    const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNuc3Z0a2pmcWx5aGlzdmljem9wIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA2Njg2OTUsImV4cCI6MjA4NjI0NDY5NX0.AfrR8rUhG2R5ETrLqNs2_C0uvS9uZL4hVeaAMv3ReBk';
    
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseKey,
      authOptions: const FlutterAuthOptions(localStorage: EmptyLocalStorage()),
    );
    
    final client = Supabase.instance.client;
    
    try {
      print('🔑 Attempting login for school1@gmail.com...');
      final response = await client.auth.signInWithPassword(
        email: 'school1@gmail.com',
        password: 'Kadomazim@89',
      );
      
      expect(response.user, isNotNull, reason: 'Login failed');
      
      if (response.user != null) {
        print('✅ Auth successful!');
        final schoolId = response.user!.userMetadata?['school_id'];
        print('🏫 School ID: $schoolId');
        
        print('📊 Checking Students table...');
        final students = await client.from('students').select('*').limit(5);
        print('✅ Found ${students.length} students in the cloud.');

        print('\n🔔 Checking Notifications table...');
        final notifications = await client.from('notifications').select('*').limit(5);
        print('✅ Found ${notifications.length} notifications in the cloud.');

        print('\n💰 Checking Payments table...');
        final payments = await client.from('fee_payments').select('*').limit(5);
        print('✅ Found ${payments.length} payments in the cloud.');

        print('\n✨ [VERDICT]: Supabase integration is ACTIVE and verified.');
      }
    } catch (e) {
      fail('❌ Error during verification: $e');
    }
  });
}
