class FirebaseConfig {
  static const databaseHost = String.fromEnvironment(
    'AHS_FIREBASE_HOST',
    defaultValue: 'https://ahsadmin-default-rtdb.firebaseio.com/',
  );

  static const authToken = String.fromEnvironment(
    'AHS_FIREBASE_AUTH',
    defaultValue: 'rLn0WxyPf2Tda6gCja5E3ONvUq1x45By1NqZPHZe',
  );

  static bool get hasAuthToken => authToken.trim().isNotEmpty;
}
