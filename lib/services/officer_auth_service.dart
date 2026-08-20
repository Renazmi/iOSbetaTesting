import '../config/storage_keys.dart';
import '../data/class_roster_officers.dart';
import '../data/seed_data.dart';
import '../models/officer.dart';
import '../utils/settings_validation.dart';
import 'api_service.dart';
import 'storage_service.dart';

/// Mirrors `OfficersService` auth/password logic from the Ionic web app.
class OfficerAuthService {
  OfficerAuthService(this._storage, this._api);

  final StorageService _storage;
  final ApiService _api;

  List<Officer> _officers = [];
  Map<int, String> _passwords = {};

  List<Officer> get officers => List.unmodifiable(_officers);

  Future<void> initialize() async {
    await _loadOfficers();
    await _ensureSeededOfficers();
    await _loadPasswords();
    await _ensureSeededPasswords();
    await _ensurePrimaryLoginAccounts();
    await _ensureClassRosterOfficersUnassigned();
  }

  Future<void> _loadOfficers() async {
    final rows = _storage.readJsonList(StorageKeys.officers);
    if (rows.isEmpty) {
      _officers = buildDefaultOfficers();
      await _saveOfficers();
      return;
    }
    try {
      _officers = rows.map(Officer.fromJson).toList();
    } catch (_) {
      _officers = buildDefaultOfficers();
      await _saveOfficers();
    }
  }

  Future<void> _saveOfficers() async {
    await _api.saveCollection(
      StorageKeys.officers,
      _officers.map((o) => o.toJson()).toList(),
    );
  }

  Future<void> _loadPasswords() async {
    final raw = _storage.readJsonObject(StorageKeys.officerPasswords);
    if (raw == null) {
      _passwords = {};
      return;
    }
    _passwords = raw.map(
      (key, value) => MapEntry(int.parse(key), '$value'),
    );
  }

  Future<void> _savePasswords() async {
    await _storage.writeJsonObject(
      StorageKeys.officerPasswords,
      _passwords.map((key, value) => MapEntry('$key', value)),
    );
  }

  Future<void> _ensureSeededOfficers() async {
    var changed = false;
    final ids = _officers.map((o) => o.id).toSet();
    for (final seed in buildDefaultOfficers()) {
      if (!ids.contains(seed.id)) {
        _officers.add(seed);
        changed = true;
      }
    }
    if (changed) {
      await _saveOfficers();
    }
  }

  Future<void> _ensureSeededPasswords() async {
    var changed = false;
    for (final entry in defaultOfficerPasswords.entries) {
      if (!_passwords.containsKey(entry.key)) {
        _passwords[entry.key] = entry.value;
        changed = true;
      }
    }
    for (final entry in classRosterOfficerPasswords.entries) {
      if (!_passwords.containsKey(entry.key)) {
        _passwords[entry.key] = entry.value;
        changed = true;
      }
    }
    if (changed) {
      await _savePasswords();
    }
  }

  /// Keeps known login emails/passwords working even after older app data was saved.
  Future<void> _ensurePrimaryLoginAccounts() async {
    var officersChanged = false;
    var passwordsChanged = false;
    final seedById = {for (final officer in buildDefaultOfficers()) officer.id: officer};

    for (final login in primaryOfficerLogins) {
      final seed = seedById[login.officerId];
      final index = _officers.indexWhere((o) => o.id == login.officerId);

      if (seed != null) {
        if (index < 0) {
          _officers.add(seed.copyWith(email: login.email));
          officersChanged = true;
        } else {
          final current = _officers[index];
          final legacyRenazPhoto = current.profilePictureUrl?.trim();
          final needsRenazPhotoUpdate = login.officerId == 1 &&
              (legacyRenazPhoto == 'assets/images/lance1.jpg' ||
                  legacyRenazPhoto == 'assets/images/muichiro.jpg');
          if (current.email.trim().toLowerCase() != login.email.trim().toLowerCase() ||
              current.position.trim().toLowerCase() != seed.position.trim().toLowerCase() ||
              current.organizationId != seed.organizationId ||
              current.name.trim().isEmpty ||
              needsRenazPhotoUpdate) {
            _officers[index] = seed.copyWith(
              email: login.email,
              phone: current.phone ?? seed.phone,
              profilePictureUrl: needsRenazPhotoUpdate
                  ? 'assets/images/bangate.jpg'
                  : current.profilePictureUrl ?? seed.profilePictureUrl,
            );
            officersChanged = true;
          }
        }
      } else if (index >= 0) {
        final officer = _officers[index];
        if (officer.email.trim().toLowerCase() != login.email.trim().toLowerCase()) {
          _officers[index] = officer.copyWith(email: login.email);
          officersChanged = true;
        }
      }

      if (_passwords[login.officerId] != login.password) {
        _passwords[login.officerId] = login.password;
        passwordsChanged = true;
      }
    }

    if (officersChanged) await _saveOfficers();
    if (passwordsChanged) await _savePasswords();
  }

  Future<void> _ensureClassRosterOfficersUnassigned() async {
    var changed = false;
    for (var i = 0; i < _officers.length; i++) {
      final officer = _officers[i];
      if (!classRosterOfficerIds.contains(officer.id)) continue;
      if (officer.organizationId == classRosterOrganizationId) continue;
      _officers[i] = officer.copyWith(organizationId: classRosterOrganizationId);
      changed = true;
    }
    if (changed) await _saveOfficers();
  }

  Officer? getOfficerById(int id) {
    try {
      return _officers.firstWhere((o) => o.id == id);
    } catch (_) {
      return null;
    }
  }

  Officer? verifyOfficerLogin(String email, String password) {
    final officer = findOfficerByEmail(email);
    if (officer == null) return null;
    final stored = _passwords[officer.id];
    if (stored == null || stored != password) return null;
    return officer;
  }

  Officer? findOfficerByEmail(String email) {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    for (final item in _officers) {
      if (item.email.toLowerCase() == normalized) {
        return item;
      }
    }

    final aliasId = defaultOfficerEmailAliases[normalized];
    if (aliasId != null) {
      return getOfficerById(aliasId);
    }

    return null;
  }

  Future<void> resetOfficerPasswordFromRecovery(int officerId, String newPassword) async {
    _passwords[officerId] = newPassword;
    await _savePasswords();
  }

  Officer? getCurrentOfficer() {
    final raw = _storage.readString(StorageKeys.currentOfficer);
    if (raw == null || raw.isEmpty) return null;
    final id = int.tryParse(raw);
    if (id == null) return null;
    return getOfficerById(id);
  }

  Future<void> setCurrentOfficer(int officerId) async {
    await _storage.writeString(StorageKeys.currentOfficer, '$officerId');
  }

  Future<void> clearCurrentOfficer() async {
    await _storage.remove(StorageKeys.currentOfficer);
  }

  Future<OfficerUpdateResult> updateOfficerAccount(
    int id, {
    String? name,
    String? email,
    String? phone,
  }) async {
    final index = _officers.indexWhere((o) => o.id == id);
    if (index < 0) {
      return const OfficerUpdateResult.fail('Officer not found.');
    }

    final trimmedName = name?.trim();
    final trimmedEmail = email?.trim().toLowerCase();
    final trimmedPhone = phone?.trim();

    if (trimmedName != null ||
        trimmedEmail != null ||
        trimmedPhone != null) {
      final validationError = SettingsValidation.validateOfficerProfile(
        fullName: trimmedName ?? _officers[index].name,
        email: trimmedEmail ?? _officers[index].email,
        phone: trimmedPhone ?? _officers[index].phone ?? '',
      );
      if (validationError != null) {
        return OfficerUpdateResult.fail(validationError);
      }
    }

    if (trimmedEmail != null) {
      final duplicate = _officers.any(
        (o) => o.id != id && o.email.toLowerCase() == trimmedEmail,
      );
      if (duplicate) {
        return const OfficerUpdateResult.fail('That username is already in use.');
      }
    }

    var updated = _officers[index];
    if (trimmedName != null) updated = updated.copyWith(name: trimmedName);
    if (trimmedEmail != null) updated = updated.copyWith(email: trimmedEmail);
    if (trimmedPhone != null) {
      updated = updated.copyWith(phone: trimmedPhone.isEmpty ? '' : trimmedPhone);
    }

    _officers[index] = updated;
    await _saveOfficers();
    return const OfficerUpdateResult.ok();
  }

  Future<OfficerUpdateResult> changeOfficerPassword(
    int id,
    String currentPassword,
    String newPassword,
    String confirmPassword,
  ) async {
    final officer = getOfficerById(id);
    if (officer == null) {
      return const OfficerUpdateResult.fail('Officer not found.');
    }

    final validationError = SettingsValidation.validateOfficerPasswordChange(
      currentPassword: currentPassword,
      newPassword: newPassword,
      confirmPassword: confirmPassword,
    );
    if (validationError != null) {
      return OfficerUpdateResult.fail(validationError);
    }

    final stored = _passwords[id];
    if (stored == null || stored != currentPassword) {
      return const OfficerUpdateResult.fail('Current password is incorrect.');
    }

    _passwords[id] = newPassword;
    await _savePasswords();
    return const OfficerUpdateResult.ok();
  }

  Future<OfficerUpdateResult> setOfficerProfilePicture(int id, String dataUrl) async {
    final index = _officers.indexWhere((o) => o.id == id);
    if (index < 0) {
      return const OfficerUpdateResult.fail('Officer not found.');
    }
    final url = dataUrl.trim();
    if (!url.startsWith('data:image/')) {
      return const OfficerUpdateResult.fail('Choose a valid image file.');
    }
    _officers[index] = _officers[index].copyWith(profilePictureUrl: url);
    await _saveOfficers();
    return const OfficerUpdateResult.ok();
  }

  Future<OfficerUpdateResult> clearOfficerProfilePicture(int id) async {
    final index = _officers.indexWhere((o) => o.id == id);
    if (index < 0) {
      return const OfficerUpdateResult.fail('Officer not found.');
    }
    _officers[index] = _officers[index].copyWith(clearProfilePicture: true);
    await _saveOfficers();
    return const OfficerUpdateResult.ok();
  }
}

class OfficerUpdateResult {
  const OfficerUpdateResult._({required this.success, this.error});

  const OfficerUpdateResult.ok() : this._(success: true);
  const OfficerUpdateResult.fail(String message) : this._(success: false, error: message);

  final bool success;
  final String? error;
}
