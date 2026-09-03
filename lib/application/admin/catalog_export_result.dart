class CatalogExportResult {
  final String csvContent;
  final int exportedRows;
  final List<String> warnings;

  CatalogExportResult({
    required this.csvContent,
    required this.exportedRows,
    List<String> warnings = const [],
  }) : warnings = List<String>.unmodifiable(warnings);

  String toSummary() {
    final buffer = StringBuffer('CSV exporté: $exportedRows ligne(s).');

    if (warnings.isEmpty) {
      return buffer.toString();
    }

    buffer.write(' ${warnings.length} avertissement(s).');
    buffer.write('\n\nAvertissements:');
    for (final warning in warnings) {
      buffer.write('\n- $warning');
    }
    return buffer.toString();
  }
}
