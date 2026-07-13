import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/client.dart';
import '../repositories/client_repository.dart';
import '../../settings/providers/settings_provider.dart';
import '../../../services/supabase_service.dart';
import '../../auth/providers/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ClientProvider extends AsyncNotifier<List<Client>> {
  StreamSubscription<List<Map<String, dynamic>>>? _subscription;
  List<Client> _lastValidData = [];
  bool _hasLoadedOnce = false;
  Timer? _periodicTimer;
  bool? _lastIsClient;



  String _getCacheKey() {
    final settings = ref.read(settingsProvider);
    final isClient = settings.isClientMode;
    final authState = ref.read(authProvider);
    final uid = authState.user?.id ?? SupabaseService.userId;
    return isClient ? 'cached_clients_client_$uid' : 'cached_clients_freelancer_$uid';
  }

  @override
  Future<List<Client>> build() async {
    final settings = ref.watch(settingsProvider);
    final isClient = settings.isClientMode;

    if (_lastIsClient != isClient) {
      debugPrint('[CLIENT BUILD] client mode changed from $_lastIsClient to $isClient - clearing cache');
      _lastIsClient = isClient;
      _hasLoadedOnce = false;
      _lastValidData = [];
    }

    final repo = ref.watch(clientRepositoryProvider);
    final authState = ref.watch(authProvider);

    if (authState.status != AuthStatus.authenticated) {
      debugPrint('[CLIENT BUILD] not authenticated - clearing cache');
      _lastValidData = [];
      _hasLoadedOnce = false;
      _periodicTimer?.cancel();
      return [];
    }

    final uid = authState.user?.id ?? SupabaseService.userId;
    debugPrint('[CLIENT BUILD] uid=$uid hasLoaded=$_hasLoadedOnce cacheLen=${_lastValidData.length}');

    final cacheKey = isClient ? 'cached_clients_client_$uid' : 'cached_clients_freelancer_$uid';

    // Set up a periodic timer to automatically refresh data every 30 seconds on Web
    _periodicTimer?.cancel();
    if (kIsWeb) {
      _periodicTimer = Timer.periodic(const Duration(seconds: 30), (t) {
        debugPrint('[CLIENT PROVIDER] Periodic 30s auto-refresh');
        _backgroundRefresh(cacheKey, repo);
      });
      ref.onDispose(() {
        _periodicTimer?.cancel();
      });
    }

    // Auto-link client record by email if authenticated
    final email = authState.user?.email;
    if (email != null && email.isNotEmpty) {
      unawaited(() async {
        try {
          final clientRows = await SupabaseService.instance
              .from('clients')
              .select('id, client_user_id')
              .eq('email', email);
          if (clientRows.isNotEmpty) {
            for (final row in clientRows) {
              if (row['client_user_id'] != uid) {
                await SupabaseService.instance
                    .from('clients')
                    .update({'client_user_id': uid})
                    .eq('id', row['id']);
                debugPrint('[CLIENT SYNC] Linked client ${row['id']} to user $uid');
              }
            }
          }
        } catch (e) {
          debugPrint('[CLIENT SYNC] Failed to sync client: $e');
        }
      }());
    }

    ref.onDispose(() {
      debugPrint('[CLIENT DISPOSED]');
      _subscription?.cancel();
      _periodicTimer?.cancel();
    });

    if (_hasLoadedOnce) {
      debugPrint('[CLIENT BUILD] returning CACHED ${_lastValidData.length} clients');
      return _lastValidData;
    }

    // 1. Try to load from SharedPreferences cache first
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(cacheKey);
      if (cachedJson != null) {
        final List<dynamic> decoded = jsonDecode(cachedJson);
        final list = decoded.map((e) => Client.fromJson(e)).toList();
        _lastValidData = list;
        _hasLoadedOnce = true;
        
        debugPrint('[CLIENT BUILD] Loaded ${list.length} clients from local storage cache. Starting delayed background refresh.');
        
        // Start background refresh. In tests, run immediately to avoid pumpAndSettle timeout.
        if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) {
          _backgroundRefresh(cacheKey, repo);
        } else {
          var disposed = false;
          ref.onDispose(() => disposed = true);
          Future.delayed(const Duration(milliseconds: 600), () {
            if (!disposed) {
              _backgroundRefresh(cacheKey, repo);
            }
          });
        }
        
        return list;
      }
    } catch (e) {
      debugPrint('[CLIENT BUILD] local cache load failed: $e');
    }

    // 2. If no cache, fetch from Supabase
    try {
      final fetched = await repo.getAll();
      debugPrint('[CLIENT BUILD] FETCH COUNT=${fetched.length}');
      _lastValidData = fetched;
      _hasLoadedOnce = true;
      _saveToCache(cacheKey, fetched);
      return fetched;
    } catch (e) {
      debugPrint('[CLIENT BUILD] FETCH FAILED: $e');
      if (_lastValidData.isNotEmpty) {
        return _lastValidData;
      }
      rethrow;
    }
  }

  Future<void> _backgroundRefresh(String cacheKey, ClientRepository repo) async {
    try {
      final fetched = await repo.getAll();
      _lastValidData = fetched;
      _hasLoadedOnce = true;
      _saveToCache(cacheKey, fetched);
      state = AsyncData(fetched);
      debugPrint('[CLIENT BG REFRESH] completed: fetched ${fetched.length} clients');
    } catch (e) {
      debugPrint('[CLIENT BG REFRESH] failed: $e');
    }
  }

  Future<void> _saveToCache(String cacheKey, List<Client> clients) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = jsonEncode(clients.map((c) => c.toJson()).toList());
      await prefs.setString(cacheKey, jsonStr);
    } catch (e) {
      debugPrint('[CLIENT CACHE] Save failed: $e');
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
      final updatedList = [
        newClient,
        ...current.where((c) => c.id != tempClient.id && c.id != newClient.id),
      ];
      state = AsyncData(updatedList);
      _saveToCache(_getCacheKey(), updatedList);
      debugPrint('[ClientProvider] addClient: created ${newClient.id}');
    } catch (e, st) {
      debugPrint('[ClientProvider] addClient failed: $e');
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
      final updatedList = current.map((c) => c.id == updated.id ? updated : c).toList();
      state = AsyncData(updatedList);
      _saveToCache(_getCacheKey(), updatedList);
      debugPrint('[ClientProvider] updateClient: updated ${updated.id}');
    } catch (e, st) {
      debugPrint('[ClientProvider] updateClient failed: $e');
      state = AsyncError<List<Client>>(e, st).copyWithPrevious(AsyncData(previousState));
    }
  }

  Future<void> deleteClient(String id) async {
    final repo = ref.read(clientRepositoryProvider);
    final previousState = state.valueOrNull ?? [];

    final updatedList = previousState.where((c) => c.id != id).toList();
    state = AsyncData(updatedList);
    _saveToCache(_getCacheKey(), updatedList);

    try {
      await repo.delete(id);
      debugPrint('[ClientProvider] deleteClient: deleted $id');
    } catch (e, st) {
      debugPrint('[ClientProvider] deleteClient failed: $e');
      state = AsyncError<List<Client>>(e, st).copyWithPrevious(AsyncData(previousState));
    }
  }

  Future<void> refresh() async {
    final repo = ref.read(clientRepositoryProvider);
    final previousState = state.valueOrNull ?? [];
    debugPrint('[ClientProvider] refresh() called');
    try {
      final clients = await repo.getAll();
      debugPrint('[ClientProvider] refresh: got ${clients.length} clients');
      _lastValidData = clients;
      _hasLoadedOnce = true;
      _saveToCache(_getCacheKey(), clients);
      state = AsyncData(clients);
    } catch (e, st) {
      debugPrint('[ClientProvider] refresh failed: $e');
      state = AsyncError<List<Client>>(e, st).copyWithPrevious(AsyncData(previousState));
    }
  }
}

class ClientClientRepository extends ClientRepository {
  @override
  Future<List<Client>> getAll() async {
    final clientUserId = SupabaseService.userId;
    try {
      final response = await SupabaseService.instance
          .from('clients')
          .select('*')
          .eq('client_user_id', clientUserId)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 15));
      final list = <Client>[];
      for (final e in (response as List)) {
        if (e['profiles'] != null && e['profiles'] is Map) {
          e['notes'] = e['profiles']['full_name'];
        } else {
          bool resolved = false;
          try {
            final profileRes = await SupabaseService.instance
                .from('profiles')
                .select('full_name')
                .eq('id', e['user_id'] as String)
                .maybeSingle()
                .timeout(const Duration(seconds: 5));
            if (profileRes != null && profileRes['full_name'] != null) {
              e['notes'] = profileRes['full_name'] as String;
              resolved = true;
            }
          } catch (err) {
            debugPrint('[ClientClientRepository] Direct profile fallback query failed: $err');
          }
          if (!resolved) {
            e['notes'] = 'Freelancer';
          }
        }
        final client = Client.tryFromJson(e);
        if (client != null) {
          list.add(client);
        }
      }
      return list;
    } catch (e) {
      debugPrint('[ClientClientRepository] getAll failed: $e');
      rethrow;
    }
  }

  @override
  Future<Client> create(Client client) => throw UnsupportedError("Write operations are disabled in client mode");

  @override
  Future<Client> update(Client client) => throw UnsupportedError("Write operations are disabled in client mode");

  @override
  Future<void> delete(String id) => throw UnsupportedError("Write operations are disabled in client mode");
}

final clientRepositoryProvider = Provider<ClientRepository>((ref) {
  final settings = ref.watch(settingsProvider);
  if (settings.isClientMode) {
    return ClientClientRepository();
  }
  return ClientRepository();
});

final clientProvider = AsyncNotifierProvider<ClientProvider, List<Client>>(
  () => ClientProvider(),
);
