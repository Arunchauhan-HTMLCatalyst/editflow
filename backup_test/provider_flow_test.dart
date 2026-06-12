import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:editflow/services/supabase_service.dart';
import 'package:editflow/features/projects/providers/project_provider.dart';
import 'package:editflow/features/projects/models/project.dart';
import 'package:editflow/features/projects/models/project_status.dart';
import 'package:editflow/features/projects/repositories/project_repository.dart';

class FakeUser extends Fake implements User {
  @override
  String get id => 'test-uid';
}

class FakeSession extends Fake implements Session {
  @override
  User get user => FakeUser();
}

class FakeGoTrueClient extends Fake implements GoTrueClient {
  @override
  User? get currentUser => FakeUser();
  @override
  Session? get currentSession => FakeSession();
  @override
  Stream<AuthState> get onAuthStateChange => const Stream.empty();
}

class FakeSupabaseClient extends Fake implements SupabaseClient {
  final _auth = FakeGoTrueClient();

  @override
  GoTrueClient get auth => _auth;
}

class FakeProjectRepository extends Fake implements ProjectRepository {
  List<Project> projects = [];

  @override
  Future<List<Project>> getAll() async {
    print('FakeProjectRepository.getAll() called');
    return projects;
  }
}

void main() {
  setUp(() {
    SupabaseService.client = FakeSupabaseClient();
  });

  test('ProjectProvider dispose and caching lifecycle test', () async {
    final fakeRepo = FakeProjectRepository();
    fakeRepo.projects = [
      Project(
        id: '1',
        userId: 'test-uid',
        clientId: 'client-1',
        name: 'Test Project 1',
        price: 100,
        receivedAmount: 0,
        status: ProjectStatus.yetToStart,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      )
    ];

    final container = ProviderContainer(
      overrides: [
        projectRepositoryProvider.overrideWithValue(fakeRepo),
      ],
    );
    addTearDown(container.dispose);

    // 1. Listen to the provider (simulating Dashboard mounting)
    print('--- Step 1: Listening to projectProvider ---');
    final keepAlive = container.listen(projectProvider, (prev, next) {
      print('Listener state changed: hasValue=${next.hasValue} isLoading=${next.isLoading} value=${next.valueOrNull?.length}');
    });

    // Await build completion
    final initialProjects = await container.read(projectProvider.future);
    print('Initial projects count: ${initialProjects.length}');

    // 2. Stop listening (simulating navigate to Settings screen)
    print('--- Step 2: Stop listening (navigating to Settings) ---');
    keepAlive.close();

    // Flush microtasks
    await Future.delayed(Duration.zero);

    // 3. Listen again (simulating navigate back to Dashboard)
    print('--- Step 3: Listen again (navigating back to Dashboard) ---');
    final keepAlive2 = container.listen(projectProvider, (prev, next) {
      print('Listener2 state changed: hasValue=${next.hasValue} isLoading=${next.isLoading} value=${next.valueOrNull?.length}');
    });

    final currentProjects = await container.read(projectProvider.future);
    print('Current projects count: ${currentProjects.length}');

    keepAlive2.close();
  });
}
