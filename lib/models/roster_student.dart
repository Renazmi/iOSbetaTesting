class RosterStudent {
  const RosterStudent({
    required this.name,
    required this.studentId,
    required this.section,
  });

  final String name;
  final String studentId;
  final String section;

  factory RosterStudent.fromJson(Map<String, dynamic> json) {
    return RosterStudent(
      name: '${json['name'] ?? ''}'.trim(),
      studentId: '${json['studentId'] ?? ''}'.trim(),
      section: '${json['section'] ?? ''}'.trim(),
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'studentId': studentId,
        'section': section,
      };
}
