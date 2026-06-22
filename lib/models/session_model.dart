class SessionModel {
  final String sessionId;
  final String conductorId;
  final String routeId;
  final int totalCollected; // Stored in cents
  final String status; // "active" or "ended"

  SessionModel({
    required this.sessionId,
    required this.conductorId,
    required this.routeId,
    required this.totalCollected,
    required this.status,
  });

  factory SessionModel.fromMap(Map<String, dynamic> data, String documentId) {
    return SessionModel(
      sessionId: documentId,
      conductorId: data['conductorId'] ?? '',
      routeId: data['routeId'] ?? '',
      totalCollected: data['totalCollected'] ?? 0,
      status: data['status'] ?? 'ended',
    );
  }
}