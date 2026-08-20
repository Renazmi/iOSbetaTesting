import '../config/storage_keys.dart';
import '../data/seed_data.dart';
import '../models/organization.dart';
import 'api_service.dart';
import 'storage_service.dart';

/// Mirrors `OrganizationsService` from the Ionic web app.
class OrganizationsService {
  OrganizationsService(this._storage, this._api);

  final StorageService _storage;
  final ApiService _api;

  List<Organization> _organizations = [];

  List<Organization> get organizations => List.unmodifiable(_organizations);

  Future<void> initialize() async {
    final rows = _storage.readJsonList(StorageKeys.organizations);
    if (rows.isEmpty) {
      _organizations = List.from(defaultOrganizations);
      await _save();
      return;
    }
    _organizations = rows.map(Organization.fromJson).toList();
  }

  Future<void> _save() async {
    await _api.saveCollection(
      StorageKeys.organizations,
      _organizations.map((o) => o.toJson()).toList(),
    );
  }

  Organization? getById(int id) {
    try {
      return _organizations.firstWhere((o) => o.id == id);
    } catch (_) {
      return null;
    }
  }
}
