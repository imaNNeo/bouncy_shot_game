class BuildConstants {
  static const String commitHash = String.fromEnvironment(
    'COMMIT_HASH',
    defaultValue: '',
  );
}
