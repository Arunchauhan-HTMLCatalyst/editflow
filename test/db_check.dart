import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  final client = SupabaseClient(
    'https://ednrbowbvkiubeqouhar.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVkbnJib3didmtpdWJlcW91aGFyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODExNjM1MzMsImV4cCI6MjA5NjczOTUzM30.Bf5-0Wt6cEnJENHi6ELBaUu-oUPLiGe0CD4JAmifuBI',
    authOptions: const AuthClientOptions(
      authFlowType: AuthFlowType.implicit,
    ),
  );

  try {
    print('Testing comments projects join select...');
    final response = await client
        .from('projects')
        .select('name, user_id, clients!client_id(client_user_id)')
        .limit(1);
    print('Query succeeded! Response: $response');
  } catch (e) {
    print('Query failed: $e');
  }
}
