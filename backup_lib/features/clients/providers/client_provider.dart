import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/client.dart';
import '../repositories/client_repository.dart';
import '../../../services/supabase_service.dart';
import '../../auth/providers/auth_provider.dart';

class ClientProvider extends AsyncNotifier<List<Client>> {
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;
  List<Client> _lastValidData = [];
  bool _hasLoadedOnce = false;

  @override
  Future<List<Client>> build() async {
    final repo = ref.watch(clientRepositoryProvider);
    final authState = ref.watch(authProvider);

    if (authState.status != AuthStatus.authenticated) {
      print('[CLIENT BUILD] not authenticated - clearing cache');
      _lastValidData = [];
      _hasLoadedOnce = false;
      return [];
    }

    final uid = authState.user?.id ?? SupabaseService.userId;
    print('[CLIENT BUILD] uid=$uid hasLoaded=$_hasLoadedOnce cacheLen=${_lastValidData.length}');

    // REALTIME DISABLED for isolation test
    // _subscription?.cancel();
    // _subscription = SupabaseService.instance
    //     .from('clients')
    //     .stream(primaryKey: ['id'])
    //     .eq('user_id', uid)
    //     .listen(
    //   (rows) {
    //     print('[CLIENT STREAM] rows=${rows.length}');
    //     final clients = <Client>[];
    //     for (final e in rows) {
    //       final c = Client.tryFromJson(e);
    //       if (c != null) {
    //         clients.add(c);
    //       } else {
    //         print('[CLIENT STREAM] SKIPPED invalid row: $e');
    //       }
    //     }
    //     print('[CLIENT STREAM] parsed ${clients.length} valid, SETTING STATE');
    //     _lastValidData = clients;
    //     _hasLoadedOnce = true;
    //     state = AsyncData(clients);
    //   },
    //   onError: (e) {
    //     print('[CLIENT STREAM ERROR] $e');
    //     if (_hasLoadedOnce) {
    //       state = AsyncData(_lastValidData);
    //     } else {
    //       state = AsyncData([]);
    //     }
    //   },
    // );
    ref.onDispose(() {
      print('[CLIENT DISPOSED]');
      _subscription?.cancel();
    });

    if (_hasLoadedOnce) {
      print('[CLIENT BUILD] returning CACHED ${_lastValidData.length} clients');
      return _lastValidData;
    }

    try {
      final fetched = await repo.getAll();
      print('[CLIENT BUILD] FETCH COUNT=${fetched.length}');
      _lastValidData = fetched;
      _hasLoadedOnce = true;
      return fetched;
    } catch (e, st) {
      print('[CLIENT BUILD] FETCH FAILED: $e');
      if (_lastValidData.isNotEmpty) {
        return _lastValidData;
      }
      rethrow;
    }
  }

  Future<void> addClient(Client client) async {
    final repo = ref.read(clientRepositoryProvider);
    final previousState = state.valueOrNull ?? [];
    final tempClient = client.copyWith(id: '_temp_${DateTime.now().millisecondsSinceEpoch}');

    state = AsyncData([tempClient, ...previousState]);

    try {
      final newClient = await repo.create(client);
      final current = state.valueOrNull ?? [];
      state = AsyncData([
        newClient,
        ...current.where((c) => c.id != tempClient.id && c.id != newClient.id),
      ]);
      print('[ClientProvider] addClient: created ${newClient.id}');
    } catch (e, st) {
      print('[ClientProvider] addClient failed: $e');
      state = AsyncError<List<Client>>(e, st).copyWithPrevious(AsyncData(previousState));
    }
  }

  Future<void> updateClient(Client client) async {
    final repo = ref.read(clientRepositoryProvider);
    final previousState = state.valueOrNull ?? [];

    final optimistic = previousState.map((c) => c.id == client.id ? client : c).toList();
    state = AsyncData(optimistic);

    try {
      final updated = await repo.update(client);
      final current = state.valueOrNull ?? [];
      state = AsyncData(current.map((c) => c.id == updated.id ? updated : c).toList());
      print('[ClientProvider] updateClient: updated ${updated.id}');
    } catch (e, st) {
      print('[ClientProvider] updateClient failed: $e');
      state = AsyncError<List<Client>>(e, st).copyWithPrevious(AsyncData(previousState));
    }
  }

  Future<void> deleteClient(String id) async {
    final repo = ref.read(clientRepositoryProvider);
    final previousState = state.valueOrNull ?? [];

    state = AsyncData(previousState.where((c) => c.id != id).toList());

    try {
      await repo.delete(id);
      print('[ClientProvider] deleteClient: deleted $id');
    } catch (e, st) {
      print('[ClientProvider] deleteClient failed: $e');
      state = AsyncError<List<Client>>(e, st).copyWithPrevious(AsyncData(previousState));
    }
  }

  Future<void> refresh() async {
    final repo = ref.read(clientRepositoryProvider);
    final previousState = state.valueOrNull ?? [];
    print('[ClientProvider] refresh() called');
    try {
      final clients = await repo.getAll();
      print('[ClientProvider] refresh: got ${clients.length} clients');
      _lastValidData = clients;
      _hasLoadedOnce = true;
      if (clients.isNotEmpty || previousState.isEmpty) {
        state = AsyncData(clients);
      }
    } catch (e, st) {
      print('[ClientProvider] refresh failed: $e');
      state = AsyncError<List<Client>>(e, st).copyWithPrevious(AsyncData(previousState));
    }
  }
}

final clientRepositoryProvider = Provider<ClientRepository>((ref) => ClientRepository());

final clientProvider = AsyncNotifierProvider<ClientProvider, List<Client>>(
  () => ClientProvider(),
);
