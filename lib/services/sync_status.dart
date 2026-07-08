enum SyncStatus { pending, synced, error }

extension SyncStatusX on SyncStatus {
  String get storageValue {
    return switch (this) {
      SyncStatus.pending => 'pending',
      SyncStatus.synced => 'synced',
      SyncStatus.error => 'error',
    };
  }

  String get label {
    return switch (this) {
      SyncStatus.pending => 'Pendiente',
      SyncStatus.synced => 'Sincronizado',
      SyncStatus.error => 'Error',
    };
  }

  static SyncStatus fromStorage(String value) {
    final String normalized = value.trim().toLowerCase();

    for (final SyncStatus status in SyncStatus.values) {
      if (status.storageValue == normalized || status.name == normalized) {
        return status;
      }
    }

    return SyncStatus.pending;
  }
}
