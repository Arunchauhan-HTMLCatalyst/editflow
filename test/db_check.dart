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
    print('Testing complete client project join query...');
    final response = await client
        .from('projects')
        .select('*, clients!inner(name, client_user_id), profiles:user_id(full_name)')
        .limit(1);
    
    print('Success! Query executed without schema errors.');
    print('Results returned: ${response.length}');
  } catch (e) {
    print('Query failed with database error:');
    print(e);
  }
}
