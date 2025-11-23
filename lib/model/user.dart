class User {
  static String id = " "; // Firestore student document id (for attendance)
  static String studentId = " "; // Student ID value (human readable)
  static double lat = 0.0;
  static double long = 0.0;

  // New authentication fields
  static String uid = ""; // Firebase Auth UID
  static String role = ""; // 'student' | 'teacher' | 'admin'
  static String email = ""; // Auth email
  static String status = ""; // 'pending' | 'approved' | 'rejected'
  static String fcmToken = ""; // Device push token
  static List<String> providers = []; // e.g. ['password','google','facebook']
}
