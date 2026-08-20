import '../config/storage_keys.dart';
import '../models/roster_student.dart';
import 'storage_service.dart';

/// Default roster entries — mirrors `DEFAULT_ROSTER_SEED` in sections.service.ts.
const defaultRosterSeed = [
  RosterStudent(studentId: '201172224', name: 'Renaz Mi', section: '3B'),
  RosterStudent(studentId: '202501002', name: 'Carlo Mendoza', section: '1A'),
  RosterStudent(studentId: '202501003', name: 'Patricia Santos', section: '1B'),
  RosterStudent(studentId: '202502002', name: 'Gabriel Torres', section: '2B'),
  RosterStudent(studentId: '202503001', name: 'Hannah Villanueva', section: '3C'),
  RosterStudent(studentId: '202504001', name: 'Miguel Dela Cruz', section: '4A'),
];

/// Section roster lookup — mirrors `SectionsService` enrollment checks for signup.
class SectionsService {
  SectionsService(this._storage);

  final StorageService _storage;
  Map<String, List<RosterStudent>> _roster = {};

  Future<void> initialize() async {
    _loadRoster();
    if (_roster.isEmpty) {
      _applySeed();
      await _persistRoster();
      return;
    }
    _ensureSeededStudents();
    await _persistRoster();
  }

  void _loadRoster() {
    final raw = _storage.readJsonObject(StorageKeys.sectionRoster);
    if (raw == null || raw.isEmpty) {
      _roster = {};
      return;
    }
    _roster = raw.map(
      (key, value) {
        if (value is! List) return MapEntry(key, <RosterStudent>[]);
        final students = value
            .whereType<Map>()
            .map((row) => RosterStudent.fromJson(Map<String, dynamic>.from(row)))
            .toList();
        return MapEntry(key, students);
      },
    );
  }

  Future<void> _persistRoster() async {
    final encoded = _roster.map(
      (key, value) => MapEntry(key, value.map((s) => s.toJson()).toList()),
    );
    await _storage.writeJsonObject(StorageKeys.sectionRoster, encoded);

    final totals = _roster.map((key, value) => MapEntry(key, value.length));
    await _storage.writeJsonObject(StorageKeys.sectionTotals, totals);
  }

  void _applySeed() {
    _roster = {};
    for (final seed in defaultRosterSeed) {
      final section = seed.section.trim().toUpperCase();
      _roster.putIfAbsent(section, () => []).add(
            RosterStudent(
              studentId: _normalizeId(seed.studentId),
              name: seed.name,
              section: section,
            ),
          );
    }
  }

  void _ensureSeededStudents() {
    for (final seed in defaultRosterSeed) {
      final id = _normalizeId(seed.studentId);
      if (findStudentById(id) != null) continue;
      final section = seed.section.trim().toUpperCase();
      _roster.putIfAbsent(section, () => []).add(
            RosterStudent(studentId: id, name: seed.name, section: section),
          );
    }
  }

  String _normalizeId(String studentId) => studentId.trim();

  RosterStudent? findStudentById(String studentId) {
    final id = _normalizeId(studentId);
    if (id.isEmpty) return null;
    for (final students in _roster.values) {
      for (final student in students) {
        if (_normalizeId(student.studentId) == id) return student;
      }
    }
    return null;
  }
}
