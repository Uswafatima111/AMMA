class AppointmentModel {
  final String id;
  final String motherId;
  final DateTime date;
  final String type;
  final String status;
  final bool reminderEnabled;

  const AppointmentModel({
    required this.id,
    required this.motherId,
    required this.date,
    required this.type,
    required this.status,
    required this.reminderEnabled,
  });
}