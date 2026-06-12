import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:editflow/app.dart';
import 'package:editflow/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:editflow/features/projects/repositories/project_repository.dart';
import 'package:editflow/features/clients/repositories/client_repository.dart';
import 'package:editflow/features/projects/models/project.dart';
import 'package:editflow/features/projects/models/project_status.dart';
import 'package:editflow/features/clients/models/client.dart';
import 'package:editflow/features/projects/providers/project_provider.dart';
import 'package:editflow/features/clients/providers/client_provider.dart';
import 'package:editflow/router.dart';
import 'package:editflow/shared/models/activity.dart';
import 'package:editflow/shared/providers/computed_providers.dart';

class FakeRecentActivityNotifier extends RecentActivityNotifier {
  final List<Activity> _activities;
  FakeRecentActivityNotifier(this._activities);

  @override
  Future<List<Activity>> build() async {
    print('[FAKE ACTIVITY BUILD] returning ${_activities.length} activities');
    return _activities;
  }
}

class FakeUser extends Fake implements User {
  @override
  String get id => 'test-uid';
  @override
  String? get email => 'test@example.com';
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
    print('[FAKE REPO] getAll projects starting');
    await Future.delayed(const Duration(milliseconds: 200));
    print('[FAKE REPO] getAll projects returning: ${projects.length}');
    return projects;
  }
}

class FakeClientRepository extends Fake implements ClientRepository {
  List<Client> clients = [];
  @override
  Future<List<Client>> getAll() async {
    print('[FAKE REPO] getAll clients starting');
    await Future.delayed(const Duration(milliseconds: 200));
    print('[FAKE REPO] getAll clients returning: ${clients.length}');
    return clients;
  }
}

void main() {
  setUp(() {
    SupabaseService.client = FakeSupabaseClient();
  });

  testWidgets('Dashboard navigation to Settings and back data vanish bug reproduction', (WidgetTester tester) async {
    final fakeProjectRepo = FakeProjectRepository();
    fakeProjectRepo.projects = [
      Project(
        id: 'p1',
        userId: 'test-uid',
        clientId: 'c1',
        name: 'Test Video Project',
        price: 1500,
        receivedAmount: 500,
        status: ProjectStatus.inProgress,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        clientName: 'Client One',
      ),
    ];

    final fakeClientRepo = FakeClientRepository();
    fakeClientRepo.clients = [
      Client(
        id: 'c1',
        userId: 'test-uid',
        name: 'Client One',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectRepositoryProvider.overrideWithValue(fakeProjectRepo),
          clientRepositoryProvider.overrideWithValue(fakeClientRepo),
        ],
        child: const EditFlowApp(),
      ),
    );

    // Let the splash screen finish and transition to dashboard
    print('--- Pump 1: Splash screen ---');
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // Verify dashboard is shown and not empty
    print('--- Verify Dashboard content ---');
    expect(find.text('Earning'), findsOneWidget);

    // Switch to Settings tab (tab index 3)
    print('--- Navigating to Settings tab ---');
    final settingsTab = find.text('Settings');
    expect(settingsTab, findsWidgets);
    await tester.tap(settingsTab.first);
    await tester.pumpAndSettle();

    // Switch back to Dashboard tab (tab index 0)
    print('--- Navigating back to Dashboard tab ---');
    final dashboardTab = find.text('Dashboard');
    expect(dashboardTab, findsWidgets);
    await tester.tap(dashboardTab.first);
    
    // Pump once to trigger build
    await tester.pump();
    
    // Pump and settle to let everything load
    await tester.pumpAndSettle();

    // Verify if dashboard content is still there or vanished
    print('--- Verify Dashboard content after navigation ---');
    expect(find.text('Earning'), findsOneWidget);
  });

  testWidgets('ProjectDetailScreen renders details and status pipeline without layout crashes', (WidgetTester tester) async {
    final fakeProjectRepo = FakeProjectRepository();
    final now = DateTime.now();
    fakeProjectRepo.projects = [
      Project(
        id: 'p1',
        userId: 'test-uid',
        clientId: 'c1',
        name: 'Test Video Project',
        price: 1500,
        receivedAmount: 500,
        status: ProjectStatus.inProgress,
        createdAt: now,
        updatedAt: now,
        clientName: 'Client One',
      ),
    ];

    final fakeClientRepo = FakeClientRepository();
    fakeClientRepo.clients = [
      Client(
        id: 'c1',
        userId: 'test-uid',
        name: 'Client One',
        createdAt: now,
        updatedAt: now,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectRepositoryProvider.overrideWithValue(fakeProjectRepo),
          clientRepositoryProvider.overrideWithValue(fakeClientRepo),
        ],
        child: const EditFlowApp(),
      ),
    );

    // Let splash screen settle
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // Navigate to the project details page
    final element = tester.element(find.byType(EditFlowApp));
    final container = ProviderScope.containerOf(element);
    container.read(routerProvider).go('/projects/p1');

    await tester.pump();
    await tester.pumpAndSettle();

    // Verify detail screen content is displayed
    expect(find.text('Test Video Project'), findsNWidgets(2));
    expect(find.text('Payment'), findsOneWidget);
  });

  testWidgets('Dashboard renders recent activities without layout crashes', (WidgetTester tester) async {
    final fakeProjectRepo = FakeProjectRepository();
    final now = DateTime.now();
    fakeProjectRepo.projects = [
      Project(
        id: 'p1',
        userId: 'test-uid',
        clientId: 'c1',
        name: 'Test Video Project',
        price: 1500,
        receivedAmount: 500,
        status: ProjectStatus.inProgress,
        createdAt: now,
        updatedAt: now,
        clientName: 'Client One',
      ),
    ];

    final fakeClientRepo = FakeClientRepository();
    fakeClientRepo.clients = [
      Client(
        id: 'c1',
        userId: 'test-uid',
        name: 'Client One',
        createdAt: now,
        updatedAt: now,
      ),
    ];

    final fakeActivities = [
      Activity(
        id: 'a1',
        userId: 'test-uid',
        type: 'project_created',
        description: 'Created project "Test Video Project"',
        createdAt: now,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectRepositoryProvider.overrideWithValue(fakeProjectRepo),
          clientRepositoryProvider.overrideWithValue(fakeClientRepo),
          recentActivityProvider.overrideWith(() => FakeRecentActivityNotifier(fakeActivities)),
        ],
        child: const EditFlowApp(),
      ),
    );

    // Let splash screen settle
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    final element = tester.element(find.byType(EditFlowApp));
    final container = ProviderScope.containerOf(element);
    final activitiesState = container.read(recentActivityProvider);
    print('--- recentActivityProvider state in test: $activitiesState');

    // Scroll ListView to bring RecentActivityWidget into view
    final listFinder = find.byType(ListView);
    await tester.drag(listFinder, const Offset(0, -600));
    await tester.pumpAndSettle();

    // Verify recent activity text is displayed
    expect(find.text('Recent Activity'), findsOneWidget);
    expect(find.text('Created project "Test Video Project"'), findsOneWidget);
  });
}
