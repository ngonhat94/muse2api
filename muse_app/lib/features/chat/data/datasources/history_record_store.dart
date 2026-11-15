abstract interface class HistoryRecordStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}
