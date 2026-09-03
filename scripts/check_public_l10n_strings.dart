import 'dart:io';

const _forbiddenPublicLiterals = <String, List<String>>{
  'lib/presentation/widgets/navigation/top_navigation_bar.dart': [
    'Recherche',
    'Favoris',
    'Compte',
    'Panier',
    "Nombre d'articles dans le panier",
    "Retour à l'accueil",
    'Ouvrir le menu',
    'Fermer le menu',
  ],
  'lib/presentation/widgets/product_card.dart': [
    'Nouveauté',
    'Dernières sorties',
    'Favoris bientôt disponibles.',
  ],
};

void main() {
  final failures = <String>[];

  for (final entry in _forbiddenPublicLiterals.entries) {
    final file = File(entry.key);
    if (!file.existsSync()) {
      failures.add('${entry.key}: file is missing');
      continue;
    }

    final source = file.readAsStringSync();
    for (final literal in entry.value) {
      if (source.contains(literal)) {
        failures.add(
          '${entry.key}: "$literal" must come from AppLocalizations',
        );
      }
    }
  }

  if (failures.isEmpty) {
    stdout.writeln('Public localization string guard passed.');
    return;
  }

  stderr.writeln('Customer-facing strings must use AppLocalizations.');
  stderr.writeln(
    'Admin/edit-mode copy is intentionally outside this narrow guard.',
  );
  for (final failure in failures) {
    stderr.writeln('- $failure');
  }
  exitCode = 1;
}
