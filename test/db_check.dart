import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  final client = SupabaseClient(
    'https://ednrbowbvkiubeqouhar.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVkbnJib3didmtpdWJlcW91aGFyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODExNjM1MzMsImV4cCI6MjA5NjczOTUzM30.Bf5-0Wt6cEnJENHi6ELBaUu-oUPLiGe0CD4JAmifuBI',
  );

  try {
    print('Testing query for is_approved column on review_videos...');
    final response = await client
        .from('review_videos')
        .select('is_approved')
        .limit(1);
    print('Response: $response');
  } catch (e) {
    print('Error: $e');
  }
}
