class CatalogImportReport {
  final int totalRows;
  final Map<String, int> createdByCollection = {};
  final Map<String, int> updatedByCollection = {};
  final List<String> errors = [];

  CatalogImportReport({required this.totalRows});

  void markCreated(String collection) {
    createdByCollection[collection] =
        (createdByCollection[collection] ?? 0) + 1;
  }

  void markUpdated(String collection) {
    updatedByCollection[collection] =
        (updatedByCollection[collection] ?? 0) + 1;
  }

  String toSummary({String Function(String collection)? labelForCollection}) {
    final buffer = StringBuffer()..writeln('Lignes traitées: $totalRows');
    final collections = {
      ...createdByCollection.keys,
      ...updatedByCollection.keys,
    }.toList()..sort();

    for (final collection in collections) {
      final created = createdByCollection[collection] ?? 0;
      final updated = updatedByCollection[collection] ?? 0;
      if (created == 0 && updated == 0) {
        continue;
      }

      final label = labelForCollection?.call(collection) ?? collection;
      buffer.writeln('$label: $created créé(s), $updated mis à jour');
    }

    if (errors.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('Erreurs:');
      for (final error in errors) {
        buffer.writeln('- $error');
      }
    }

    return buffer.toString().trimRight();
  }
}
