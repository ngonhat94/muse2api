abstract interface class CredentialStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}
