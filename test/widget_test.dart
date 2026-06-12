import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:editflow/app.dart';
import 'package:editflow/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:editflow/features/projects/repositories/project_repository.dart';
import 'package:editflow/features/clients/repositories/client_repository.dart';
import 'package:editflow/features/projects/repositories/comment_repository.dart';
import 'package:editflow/features/projects/models/project.dart';
import 'package:editflow/features/projects/models/comment.dart';
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

class FakeCommentRepository extends Fake implements CommentRepository {
  @override
  Stream<List<Comment>> subscribeComments(String projectId) {
    return Stream.value([]);
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
          commentRepositoryProvider.overrideWithValue(FakeCommentRepository()),
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

    // Navigate to Settings using the settings gear button
    print('--- Navigating to Settings ---');
    final settingsButton = find.byIcon(Icons.settings_outlined);
    expect(settingsButton, findsOneWidget);
    await tester.tap(settingsButton);
    await tester.pumpAndSettle();

    // Navigate back to Dashboard using the back button
    print('--- Navigating back to Dashboard ---');
    final backButton = find.byIcon(CupertinoIcons.back);
    expect(backButton, findsOneWidget);
    await tester.tap(backButton);
    await tester.pumpAndSettle();
    
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
          commentRepositoryProvider.overrideWithValue(FakeCommentRepository()),
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
          commentRepositoryProvider.overrideWithValue(FakeCommentRepository()),
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

  testWidgets('PaymentsScreen toggles selection mode and allows selecting projects', (WidgetTester tester) async {
    final fakeProjectRepo = FakeProjectRepository();
    final now = DateTime.now();
    fakeProjectRepo.projects = [
      Project(
        id: 'p1',
        userId: 'test-uid',
        clientId: 'c1',
        name: 'Project One',
        price: 2000,
        receivedAmount: 1000,
        status: ProjectStatus.inProgress,
        createdAt: now,
        updatedAt: now,
        clientName: 'Client One',
      ),
      Project(
        id: 'p2',
        userId: 'test-uid',
        clientId: 'c2',
        name: 'Project Two',
        price: 3000,
        receivedAmount: 1500,
        status: ProjectStatus.inProgress,
        createdAt: now,
        updatedAt: now,
        clientName: 'Client Two',
      ),
    ];

    final fakeClientRepo = FakeClientRepository();
    fakeClientRepo.clients = [];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectRepositoryProvider.overrideWithValue(fakeProjectRepo),
          clientRepositoryProvider.overrideWithValue(fakeClientRepo),
          commentRepositoryProvider.overrideWithValue(FakeCommentRepository()),
        ],
        child: const EditFlowApp(),
      ),
    );

    // Let splash screen settle and navigate to Dashboard
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // Navigate to payments screen
    final element = tester.element(find.byType(EditFlowApp));
    final container = ProviderScope.containerOf(element);
    container.read(routerProvider).go('/payments');
    await tester.pumpAndSettle();

    // Verify Payments page content is rendered
    expect(find.text('Payments'), findsNWidgets(2));
    expect(find.text('Project One'), findsOneWidget);
    expect(find.text('Project Two'), findsOneWidget);

    // Verify select mode toggles on when select icon is tapped
    final selectModeButton = find.byIcon(Icons.playlist_add_check_rounded);
    expect(selectModeButton, findsOneWidget);
    await tester.tap(selectModeButton);
    await tester.pumpAndSettle();

    // Should now show selection title
    expect(find.text('0 Selected'), findsOneWidget);

    // Verify Checkboxes are shown next to cards
    expect(find.byType(Checkbox), findsNWidgets(2));

    // Tap first card checkbox
    await tester.tap(find.byType(Checkbox).first);
    await tester.pumpAndSettle();
    expect(find.text('1 Selected'), findsOneWidget);

    // Tap Select All
    final selectAllButton = find.byIcon(Icons.select_all);
    await tester.tap(selectAllButton);
    await tester.pumpAndSettle();
    expect(find.text('2 Selected'), findsOneWidget);

    // Toggle select mode off via close button
    final closeButton = find.byIcon(Icons.close);
    await tester.tap(closeButton);
    await tester.pumpAndSettle();

    // Should return to normal Payments view
    expect(find.text('Payments'), findsNWidgets(2));
    expect(find.byType(Checkbox), findsNothing);
  });

  testWidgets('ClientDetailScreen renders details without layout crashes', (WidgetTester tester) async {
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
        company: 'Acme Corp',
        email: 'client@example.com',
        phone: '123456789',
        notes: 'Some notes',
        createdAt: now,
        updatedAt: now,
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          projectRepositoryProvider.overrideWithValue(fakeProjectRepo),
          clientRepositoryProvider.overrideWithValue(fakeClientRepo),
          commentRepositoryProvider.overrideWithValue(FakeCommentRepository()),
        ],
        child: const EditFlowApp(),
      ),
    );

    // Let splash screen settle
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // Navigate to the client details page
    final element = tester.element(find.byType(EditFlowApp));
    final container = ProviderScope.containerOf(element);
    container.read(routerProvider).go('/clients/c1');

    await tester.pump();
    await tester.pumpAndSettle();

    // Verify detail screen content is displayed
    expect(find.text('Client One'), findsNWidgets(3));
    expect(find.text('Acme Corp'), findsOneWidget);
  });

  testWidgets('FreelancerDetailScreen renders details and navigates successfully', (WidgetTester tester) async {
    final fakeProjectRepo = FakeProjectRepository();
    final now = DateTime.now();
    fakeProjectRepo.projects = [
      Project(
        id: 'p1',
        userId: 'f1',
        clientId: 'c1',
        name: 'Bob Video Editing',
        price: 1500,
        receivedAmount: 500,
        status: ProjectStatus.inProgress,
        createdAt: now,
        updatedAt: now,
        clientName: 'Client One',
        freelancerName: 'Freelancer Bob',
      ),
    ];

    final fakeClientRepo = FakeClientRepository();
    fakeClientRepo.clients = [
      Client(
        id: 'c1',
        userId: 'f1',
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
          commentRepositoryProvider.overrideWithValue(FakeCommentRepository()),
        ],
        child: const EditFlowApp(),
      ),
    );

    // Let splash screen settle
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // Navigate to the freelancer details page
    final element = tester.element(find.byType(EditFlowApp));
    final container = ProviderScope.containerOf(element);
    container.read(routerProvider).go('/freelancers/f1');

    await tester.pump();
    await tester.pumpAndSettle();

    // Verify detail screen content is displayed
    expect(find.text('Freelancer Profile'), findsOneWidget);
    expect(find.text('Freelancer Bob'), findsOneWidget);
    expect(find.text('Bob Video Editing'), findsOneWidget);
  });

  testWidgets('ProjectDetailScreen back button in Client Mode pops back correctly', (WidgetTester tester) async {
    final fakeProjectRepo = FakeProjectRepository();
    final now = DateTime.now();
    fakeProjectRepo.projects = [
      Project(
        id: 'p1',
        userId: 'f1',
        clientId: 'c1',
        name: 'Bob Video Editing',
        price: 1500,
        receivedAmount: 500,
        status: ProjectStatus.inProgress,
        createdAt: now,
        updatedAt: now,
        clientName: 'Client One',
        freelancerName: 'Freelancer Bob',
      ),
    ];

    final fakeClientRepo = FakeClientRepository();
    fakeClientRepo.clients = [
      Client(
        id: 'c1',
        userId: 'f1',
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
          commentRepositoryProvider.overrideWithValue(FakeCommentRepository()),
        ],
        child: const EditFlowApp(),
      ),
    );

    // Let splash screen settle
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // Push the project detail screen so that context.canPop() is true
    final element = tester.element(find.byType(EditFlowApp));
    final container = ProviderScope.containerOf(element);
    container.read(routerProvider).push('/projects/p1');
    await tester.pumpAndSettle();

    // Verify we are on project details screen
    expect(find.text('Bob Video Editing'), findsNWidgets(2));

    // Tap back button
    final backButton = find.byIcon(CupertinoIcons.back);
    expect(backButton, findsOneWidget);
    await tester.tap(backButton);
    await tester.pumpAndSettle();

    // Verify we popped back to Dashboard (the screen we pushed from)
    expect(find.text('Bob Video Editing'), findsNothing);
    expect(find.text('Earning'), findsOneWidget);
  });
}
