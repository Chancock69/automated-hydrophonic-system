class FirebaseConfig {
  static const databaseHost = String.fromEnvironment(
    'AHS_FIREBASE_HOST',
    defaultValue: 'https://ahsadmin-default-rtdb.firebaseio.com/',
  );

  static const authToken = String.fromEnvironment('AHS_FIREBASE_AUTH');

  static bool get hasAuthToken => authToken.trim().isNotEmpty;
}
