class UserModel {
  final String uid;
  final String role; // "passenger" or "conductor"
  final String phoneNumber;
  final int walletBalance; // Stored in cents ($1.00 = 100)

  UserModel({
    required this.uid,
    required this.role,
    required this.phoneNumber,
    required this.walletBalance,
  });

  // Factory method to convert Firebase Document into a Dart Object
  factory UserModel.fromMap(Map<String, dynamic> data, String documentId) {
    return UserModel(
      uid: documentId,
      role: data['role'] ?? 'passenger', // Default to passenger if missing
      phoneNumber: data['phoneNumber'] ?? '',
      walletBalance: data['walletBalance'] ?? 0,
    );
  }

  // Method to convert Dart Object back into Firebase Map
  Map<String, dynamic> toMap() {
    return {
      'role': role,
      'phoneNumber': phoneNumber,
      'walletBalance': walletBalance,
    };
  }
}