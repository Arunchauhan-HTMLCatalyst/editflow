import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:editflow/services/supabase_service.dart';
import 'package:editflow/features/projects/providers/project_provider.dart';
import 'package:editflow/features/projects/models/project.dart';
import 'package:editflow/features/projects/models/project_status.dart';
import 'package:editflow/features/projects/repositories/project_repository.dart';
import 'package:editflow/features/settings/providers/settings_provider.dart';

import 'package:editflow/features/clients/models/client.dart';

class FakeUser extends Fake implements User {
  @override
  String get id => 'test-uid';
  @override
  Map<String, dynamic>? get userMetadata => null;
  @override
  String get createdAt => DateTime.now().toIso8601String();
  @override
  String? get lastSignInAt => DateTime.now().toIso8601String();
  @override
  Map<String, dynamic> get appMetadata => const {'provider': 'email'};
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
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
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

  test('Client and Project parsing validation', () {
    final clientJson = {
      'id': 'client-uuid-1',
      'user_id': 'test-uid',
      'name': 'Client 1',
      'phone': null,
      'email': 'client@test.com',
      'company': null,
      'notes': null,
      'created_at': '2026-06-11T20:30:00Z',
      'updated_at': '2026-06-11T20:30:00Z',
    };

    final client = Client.fromJson(clientJson);
    expect(client.id, 'client-uuid-1');
    expect(client.name, 'Client 1');

    final projectJson = {
      'id': 'project-uuid-1',
      'user_id': 'test-uid',
      'client_id': 'client-uuid-1',
      'name': 'Project 1',
      'description': 'A description',
      'price': 1500.0,
      'received_amount': 250.0,
      'deadline': null,
      'status': 'ongoing',
      'created_at': '2026-06-11T20:30:00Z',
      'updated_at': '2026-06-11T20:30:00Z',
    };

    final project = Project.fromJson(projectJson);
    expect(project.id, 'project-uuid-1');
    expect(project.name, 'Project 1');
    expect(project.price, 1500.0);
    expect(project.receivedAmount, 250.0);
  });

  test('ProjectProvider clears cache on client mode switch', () async {
    final fakeRepo = FakeProjectRepository();
    fakeRepo.projects = [
      Project(
        id: '1',
        userId: 'test-uid',
        clientId: 'client-1',
        name: 'Freelancer Project',
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

    // Initial read (Freelancer Mode)
    final initialList = await container.read(projectProvider.future);
    expect(initialList.length, 1);
    expect(initialList.first.name, 'Freelancer Project');

    // Change projects in repository
    fakeRepo.projects = [
      Project(
        id: '2',
        userId: 'test-uid',
        clientId: 'client-1',
        name: 'Client Project',
        price: 200,
        receivedAmount: 0,
        status: ProjectStatus.yetToStart,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      )
    ];

    // Read again - should return cached Freelancer Project because isClientMode has not changed
    final cachedList = await container.read(projectProvider.future);
    expect(cachedList.length, 1);
    expect(cachedList.first.name, 'Freelancer Project');

    // Toggle client mode to true (simulate settings toggle)
    container.read(settingsProvider.notifier).state = const SettingsState(isClientMode: true);
    
    // Read again - should clear cache and fetch Client Project
    final updatedList = await container.read(projectProvider.future);
    expect(updatedList.length, 1);
    expect(updatedList.first.name, 'Client Project');
  });
}
