import 'dart:async';
import '../../../services/supabase_service.dart';
import '../../../features/clients/models/client.dart';
import '../../../shared/services/activity_service.dart';

class ClientRepository {
  final ActivityService _activity = ActivityService();

  Future<List<Client>> getAll() async {
    final userId = SupabaseService.userId;
    final response = await SupabaseService.instance
        .from('clients')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .timeout(const Duration(seconds: 15));
    return (response as List).map((e) => Client.fromJson(e)).toList();
  }

  Future<Client> getById(String id) async {
    final response = await SupabaseService.instance
        .from('clients')
        .select()
        .eq('id', id)
        .single()
        .timeout(const Duration(seconds: 15));
    return Client.fromJson(response);
  }

  Future<Client> create(Client client) async {
    final response = await SupabaseService.instance
        .from('clients')
        .insert(client.toJson()..remove('id'))
        .select()
        .single()
        .timeout(const Duration(seconds: 15));
    final created = Client.fromJson(response);
    unawaited(_activity.log(
      type: 'client_created',
      description: 'Created client "${created.name}"',
      referenceId: created.id,
      referenceType: 'client',
    ));
    return created;
  }

  Future<Client> update(Client client) async {
    final old = await getById(client.id);
    final response = await SupabaseService.instance
        .from('clients')
        .update(client.toJson())
        .eq('id', client.id)
        .select()
        .single()
        .timeout(const Duration(seconds: 15));
    final updated = Client.fromJson(response);
    if (old.name != updated.name) {
      unawaited(_activity.log(
        type: 'client_updated',
        description: 'Renamed client "${old.name}" → "${updated.name}"',
        referenceId: updated.id,
        referenceType: 'client',
      ));
    }
    return updated;
  }

  Future<void> delete(String id) async {
    final client = await getById(id);
    await SupabaseService.instance
        .from('clients')
        .delete()
        .eq('id', id)
        .timeout(const Duration(seconds: 15));
    unawaited(_activity.log(
      type: 'client_deleted',
      description: 'Deleted client "${client.name}"',
      referenceId: id,
      referenceType: 'client',
    ));
  }
}
