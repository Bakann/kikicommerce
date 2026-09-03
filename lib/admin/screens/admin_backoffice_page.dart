import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../admin_collection_schema.dart';
import '../../config/api_config.dart';
import '../../core/utils/media_url_builder.dart';
import '../../presentation/providers/admin_backoffice_controller.dart';
import '../../presentation/widgets/browser_file_download.dart';
import '../../presentation/widgets/kiki_image.dart';
import 'admin_record_editor_dialog.dart';

class AdminBackofficePage extends ConsumerStatefulWidget {
  const AdminBackofficePage({super.key});

  @override
  ConsumerState<AdminBackofficePage> createState() =>
      _AdminBackofficePageState();
}

class _AdminBackofficePageState extends ConsumerState<AdminBackofficePage> {
  static const String importSection = '__import__';

  final TextEditingController _baseUrlController = TextEditingController(
    text: ApiConfig.apiBaseUrl,
  );
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _csvController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  String _selectedSection = importSection;

  @override
  void dispose() {
    _baseUrlController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _tokenController.dispose();
    _csvController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String? get _effectiveToken {
    final sessionToken = ref
        .read(adminBackofficeControllerProvider)
        .sessionToken
        ?.trim();
    if (sessionToken != null && sessionToken.isNotEmpty) {
      return sessionToken;
    }

    final pastedToken = _tokenController.text.trim();
    return pastedToken.isEmpty ? null : pastedToken;
  }

  bool get _hasSession => _effectiveToken != null;

  String get _normalizedBaseUrl {
    final value = _baseUrlController.text.trim();
    if (value.endsWith('/')) {
      return value.substring(0, value.length - 1);
    }
    return value;
  }

  Map<String, List<Map<String, dynamic>>> get _recordsByCollection =>
      ref.read(adminBackofficeControllerProvider).recordsByCollection;

  bool get _isAuthenticating =>
      ref.read(adminBackofficeControllerProvider).isAuthenticating;

  bool get _isLoadingData =>
      ref.read(adminBackofficeControllerProvider).isLoadingData;

  bool get _isImporting =>
      ref.read(adminBackofficeControllerProvider).isImporting;

  bool get _isExporting =>
      ref.read(adminBackofficeControllerProvider).isExporting;

  String? get _statusMessage =>
      ref.read(adminBackofficeControllerProvider).statusMessage;

  String? get _errorMessage =>
      ref.read(adminBackofficeControllerProvider).errorMessage;

  Future<void> _authenticate() async {
    final tokenInput = _tokenController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (tokenInput.isEmpty && (email.isEmpty || password.isEmpty)) {
      ref
          .read(adminBackofficeControllerProvider.notifier)
          .showError(
            'Renseignez un jeton admin ou un email + mot de passe superuser.',
          );
      return;
    }

    await ref
        .read(adminBackofficeControllerProvider.notifier)
        .authenticate(
          baseUrl: _normalizedBaseUrl,
          tokenInput: tokenInput,
          email: email,
          password: password,
        );
  }

  Future<void> _refreshAllCollections() async {
    if (!_hasSession) {
      ref
          .read(adminBackofficeControllerProvider.notifier)
          .showError('Connectez-vous avant de charger les collections.');
      return;
    }

    await ref
        .read(adminBackofficeControllerProvider.notifier)
        .refreshCollections(
          baseUrl: _normalizedBaseUrl,
          authToken: _effectiveToken!,
        );
  }

  Future<void> _loadSampleCsv() async {
    try {
      final csvContent = await rootBundle.loadString(
        'assets/admin/sample_catalog.csv',
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _csvController.text = csvContent;
        _selectedSection = importSection;
      });
      ref
          .read(adminBackofficeControllerProvider.notifier)
          .showStatus('CSV exemple chargé dans l’éditeur.');
    } catch (error) {
      ref
          .read(adminBackofficeControllerProvider.notifier)
          .showError('Impossible de charger le CSV exemple: $error');
    }
  }

  Future<void> _pickCsvFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        return;
      }

      final bytes = result.files.single.bytes;
      if (bytes == null) {
        throw Exception(
          'Le fichier sélectionné ne contient pas de données lisibles.',
        );
      }

      setState(() {
        _csvController.text = utf8.decode(bytes, allowMalformed: true);
      });
      ref
          .read(adminBackofficeControllerProvider.notifier)
          .showStatus('CSV chargé: ${result.files.single.name}');
    } catch (error) {
      ref
          .read(adminBackofficeControllerProvider.notifier)
          .showError('Import du fichier CSV impossible: $error');
    }
  }

  Future<void> _runCsvImport() async {
    if (!_hasSession) {
      ref
          .read(adminBackofficeControllerProvider.notifier)
          .showError('Connectez-vous avant de lancer un import.');
      return;
    }

    final csvContent = _csvController.text.trim();
    if (csvContent.isEmpty) {
      ref
          .read(adminBackofficeControllerProvider.notifier)
          .showError('Chargez ou collez un CSV avant de lancer l’import.');
      return;
    }

    await ref
        .read(adminBackofficeControllerProvider.notifier)
        .importCatalog(
          baseUrl: _normalizedBaseUrl,
          authToken: _effectiveToken!,
          csvContent: csvContent,
        );
  }

  Future<void> _exportCatalogCsv() async {
    if (!_hasSession) {
      ref
          .read(adminBackofficeControllerProvider.notifier)
          .showError('Connectez-vous avant de lancer un export.');
      return;
    }

    final result = await ref
        .read(adminBackofficeControllerProvider.notifier)
        .exportCatalog(
          baseUrl: _normalizedBaseUrl,
          authToken: _effectiveToken!,
        );

    if (result == null) {
      return;
    }

    try {
      await downloadTextFile(
        filename: _exportFilename(),
        content: result.csvContent,
        mimeType: 'text/csv;charset=utf-8',
        includeBom: true,
      );
    } catch (error) {
      ref
          .read(adminBackofficeControllerProvider.notifier)
          .showError('Export généré mais téléchargement impossible: $error');
    }
  }

  Future<void> _rebuildSearchIndexes() async {
    if (!_hasSession) {
      ref
          .read(adminBackofficeControllerProvider.notifier)
          .showError('Connectez-vous avant de recalculer les index.');
      return;
    }

    await ref
        .read(adminBackofficeControllerProvider.notifier)
        .rebuildSearchIndexes(
          baseUrl: _normalizedBaseUrl,
          authToken: _effectiveToken!,
        );
  }

  Future<void> _openEditor(
    AdminCollectionDefinition definition, {
    Map<String, dynamic>? existingRecord,
  }) async {
    if (!_hasSession) {
      ref
          .read(adminBackofficeControllerProvider.notifier)
          .showError('Connectez-vous avant de modifier les collections.');
      return;
    }

    final draft = await showDialog<AdminRecordDraft>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AdminRecordEditorDialog(
          definition: definition,
          record: existingRecord,
          relationData: _recordsByCollection,
        );
      },
    );

    if (draft == null) {
      return;
    }

    final fallbackFilename =
        ((draft.data['code'] as String?)?.trim().isNotEmpty ?? false)
        ? (draft.data['code'] as String).trim()
        : 'media';

    await ref
        .read(adminBackofficeControllerProvider.notifier)
        .saveRecord(
          baseUrl: _normalizedBaseUrl,
          authToken: _effectiveToken!,
          collection: definition.name,
          label: definition.label,
          data: draft.data,
          recordId: existingRecord?['id'] as String?,
          mediaSource: draft.mediaSource,
          mimeType: draft.data['mimeType'] as String?,
          fallbackFilename: fallbackFilename,
        );
  }

  Future<void> _deleteRecord(
    AdminCollectionDefinition definition,
    Map<String, dynamic> record,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Supprimer ce record ?'),
          content: Text(
            'Cette action supprimera ${adminRecordLabel(definition, record)}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await ref
        .read(adminBackofficeControllerProvider.notifier)
        .deleteRecord(
          baseUrl: _normalizedBaseUrl,
          authToken: _effectiveToken!,
          collection: definition.name,
          recordId: record['id'] as String,
          label: definition.label,
        );
  }

  String _fileUrl({
    required String collection,
    required String recordId,
    required String filename,
  }) {
    return MediaUrlBuilder.fileUrl(
      collectionId: collection,
      recordId: recordId,
      filename: filename,
      baseUrl: _normalizedBaseUrl,
    );
  }

  void _navigateToCollection(String collectionName, {String? initialSearch}) {
    setState(() {
      _selectedSection = collectionName;
      _searchController.text = initialSearch ?? '';
    });
  }

  String _exportFilename() {
    final now = DateTime.now();
    String twoDigits(int value) => value.toString().padLeft(2, '0');

    return 'catalog-export-${now.year}'
        '${twoDigits(now.month)}'
        '${twoDigits(now.day)}-'
        '${twoDigits(now.hour)}'
        '${twoDigits(now.minute)}'
        '${twoDigits(now.second)}.csv';
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(adminBackofficeControllerProvider);
    final isCompact = MediaQuery.of(context).size.width < 1100;
    final selectedIndex = _destinationKeys.indexOf(_selectedSection);
    final currentDefinition = _selectedSection == importSection
        ? null
        : adminCollectionDefinitionsByName[_selectedSection];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Backoffice admin'),
        actions: [
          IconButton(
            tooltip: 'Charger le CSV exemple',
            onPressed: _loadSampleCsv,
            icon: const Icon(Icons.description_outlined),
          ),
          IconButton(
            tooltip: 'Recharger les collections',
            onPressed: _hasSession && !_isLoadingData
                ? _refreshAllCollections
                : null,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      drawer: isCompact ? Drawer(child: _buildDrawerContent()) : null,
      body: Row(
        children: [
          if (!isCompact)
            NavigationRail(
              labelType: NavigationRailLabelType.all,
              selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
              onDestinationSelected: (index) {
                setState(() {
                  _selectedSection = _destinationKeys[index];
                  if (_selectedSection == importSection) {
                    _searchController.clear();
                  }
                });
              },
              destinations: [
                const NavigationRailDestination(
                  icon: Icon(Icons.upload_file_outlined),
                  label: Text('Import'),
                ),
                for (final definition in adminCollectionDefinitions)
                  NavigationRailDestination(
                    icon: const Icon(Icons.table_rows_outlined),
                    label: Text(definition.label),
                  ),
              ],
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildConnectionPanel(),
                  if (_errorMessage != null || _statusMessage != null) ...[
                    const SizedBox(height: 12),
                    _buildFeedbackBanner(),
                  ],
                  const SizedBox(height: 16),
                  Expanded(
                    child: currentDefinition == null
                        ? _buildImportPanel()
                        : _buildCollectionPanel(currentDefinition),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerContent() {
    return SafeArea(
      child: ListView(
        children: [
          const DrawerHeader(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                'Backoffice admin',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.upload_file_outlined),
            title: const Text('Import'),
            selected: _selectedSection == importSection,
            onTap: () {
              Navigator.of(context).pop();
              setState(() {
                _selectedSection = importSection;
              });
            },
          ),
          for (final definition in adminCollectionDefinitions)
            ListTile(
              leading: const Icon(Icons.table_rows_outlined),
              title: Text(definition.label),
              selected: _selectedSection == definition.name,
              onTap: () {
                Navigator.of(context).pop();
                setState(() {
                  _selectedSection = definition.name;
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _buildConnectionPanel() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connexion PocketBase',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 320,
                  child: TextField(
                    controller: _baseUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Base URL',
                      hintText: 'https://xxx.pockethost.io',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email superuser',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Mot de passe',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 320,
                  child: TextField(
                    controller: _tokenController,
                    decoration: const InputDecoration(
                      labelText: 'Jeton admin (optionnel)',
                      helperText: 'Prioritaire si renseigné',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: _isAuthenticating ? null : _authenticate,
                  icon: _isAuthenticating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.lock_open_outlined),
                  label: Text(
                    _effectiveToken == null
                        ? 'Se connecter'
                        : 'Rafraîchir la session',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _hasSession && !_isLoadingData
                      ? _refreshAllCollections
                      : null,
                  icon: _isLoadingData
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                  label: const Text('Charger les collections'),
                ),
                TextButton.icon(
                  onPressed: () {
                    _tokenController.clear();
                    ref
                        .read(adminBackofficeControllerProvider.notifier)
                        .clearSession();
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Déconnecter'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackBanner() {
    final isError = _errorMessage != null;
    final message = _errorMessage ?? _statusMessage ?? '';
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: isError
          ? colorScheme.errorContainer
          : colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.info_outline,
              color: isError
                  ? colorScheme.onErrorContainer
                  : colorScheme.onSecondaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SelectableText(
                message,
                style: TextStyle(
                  color: isError
                      ? colorScheme.onErrorContainer
                      : colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImportPanel() {
    return Card(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compactHeight = constraints.maxHeight < 420;
          final csvEditor = TextField(
            controller: _csvController,
            expands: !compactHeight,
            maxLines: compactHeight ? 12 : null,
            minLines: compactHeight ? 12 : null,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
              labelText: 'Contenu CSV',
              hintText: 'Chargez un fichier ou collez le CSV ici.',
            ),
          );

          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Import CSV catalogue',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              const Text(
                'Le backoffice attend un CSV dénormalisé qui hydrate automatiquement '
                'les 8 collections PocketBase. Le fichier exemple crée 3 catégories '
                'avec 2 produits chacune, leurs médias, mediaContainers, prix, devise '
                'et unité.',
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.icon(
                    onPressed: _loadSampleCsv,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Charger le CSV exemple'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _pickCsvFile,
                    icon: const Icon(Icons.folder_open_outlined),
                    label: const Text('Choisir un CSV'),
                  ),
                  OutlinedButton.icon(
                    onPressed: !_hasSession || _isExporting
                        ? null
                        : _exportCatalogCsv,
                    icon: _isExporting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_outlined),
                    label: const Text('Exporter le CSV'),
                  ),
                  OutlinedButton.icon(
                    onPressed: !_hasSession || _isLoadingData
                        ? null
                        : _rebuildSearchIndexes,
                    icon: const Icon(Icons.manage_search_outlined),
                    label: const Text('Recalculer index recherche'),
                  ),
                  FilledButton.icon(
                    onPressed: _isImporting ? null : _runCsvImport,
                    icon: _isImporting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.file_upload_outlined),
                    label: const Text('Importer dans PocketBase'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (compactHeight) csvEditor else Expanded(child: csvEditor),
            ],
          );

          return Padding(
            padding: const EdgeInsets.all(16),
            child: compactHeight
                ? SingleChildScrollView(child: content)
                : content,
          );
        },
      ),
    );
  }

  Widget _buildCollectionPanel(AdminCollectionDefinition definition) {
    if (!_hasSession) {
      return const Center(
        child: Text(
          'Connectez-vous avec un superuser PocketBase ou un jeton admin pour éditer les collections.',
          textAlign: TextAlign.center,
        ),
      );
    }

    final query = _searchController.text.trim().toLowerCase();
    final allRecords = _recordsByCollection[definition.name] ?? const [];
    final filteredRecords = query.isEmpty
        ? allRecords
        : allRecords
              .where(
                (record) => jsonEncode(record).toLowerCase().contains(query),
              )
              .toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 320,
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: 'Rechercher dans ${definition.label}',
                      prefixIcon: const Icon(Icons.search),
                      border: const OutlineInputBorder(),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                              icon: const Icon(Icons.clear),
                            ),
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _isLoadingData
                      ? null
                      : () => _openEditor(definition),
                  icon: const Icon(Icons.add),
                  label: Text('Créer ${definition.label}'),
                ),
                OutlinedButton.icon(
                  onPressed: _isLoadingData ? null : _refreshAllCollections,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Recharger'),
                ),
                Text(
                  '${filteredRecords.length} / ${allRecords.length} record(s)',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: filteredRecords.isEmpty
                  ? const Center(child: Text('Aucun record à afficher.'))
                  : ListView.separated(
                      itemCount: filteredRecords.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final record = filteredRecords[index];
                        // Records always carry an id in prod; the index fallback
                        // keeps keys distinct for broken/mocked data so a null
                        // id can't collapse every row onto ValueKey(null).
                        final recordId = record['id'] as String?;
                        return KeyedSubtree(
                          key: ValueKey(
                            '${definition.name}:${recordId ?? index}',
                          ),
                          child: _buildRecordCard(definition, record),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecordCard(
    AdminCollectionDefinition definition,
    Map<String, dynamic> record,
  ) {
    final mediaFile = record['file'] as String?;
    final mediaPreviewUrl =
        definition.name == 'medias' && mediaFile != null && mediaFile.isNotEmpty
        ? _fileUrl(
            collection: definition.name,
            recordId: record['id'] as String,
            filename: mediaFile,
          )
        : null;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (mediaPreviewUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: KikiImage(
                      imageUrl: mediaPreviewUrl,
                      width: 84,
                      height: 84,
                      fit: BoxFit.cover,
                    ),
                  ),
                if (mediaPreviewUrl != null) const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        adminRecordLabel(definition, record),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        'id: ${record['id']}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _isLoadingData
                          ? null
                          : () =>
                                _openEditor(definition, existingRecord: record),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Éditer'),
                    ),
                    IconButton(
                      tooltip: 'Supprimer',
                      onPressed: _isLoadingData
                          ? null
                          : () => _deleteRecord(definition, record),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final field in definition.listFields)
                  ..._buildFieldWidgets(definition, field, record),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildFieldWidgets(
    AdminCollectionDefinition definition,
    AdminFieldDefinition field,
    Map<String, dynamic> record,
  ) {
    if (field.type == AdminFieldType.relationSingle) {
      final relatedId = record[field.name] as String?;
      if (relatedId == null || relatedId.isEmpty) {
        return const [];
      }
      return [
        ActionChip(
          label: Text(
            '${field.label}: ${_relationLabel(field.relationCollection!, relatedId)}',
          ),
          onPressed: () => _navigateToCollection(
            field.relationCollection!,
            initialSearch: relatedId,
          ),
        ),
      ];
    }

    if (field.type == AdminFieldType.relationMultiple) {
      final relatedIds = ((record[field.name] as List<dynamic>?) ?? const [])
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList();
      return [
        for (final relatedId in relatedIds)
          ActionChip(
            label: Text(
              '${field.label}: ${_relationLabel(field.relationCollection!, relatedId)}',
            ),
            onPressed: () => _navigateToCollection(
              field.relationCollection!,
              initialSearch: relatedId,
            ),
          ),
      ];
    }

    final value = record[field.name];
    if (value == null) {
      return const [];
    }

    final formatted = switch (field.type) {
      AdminFieldType.boolean => (value as bool?) == true ? 'true' : 'false',
      AdminFieldType.file => value.toString(),
      _ => value.toString(),
    };

    if (formatted.isEmpty || formatted == 'null') {
      return const [];
    }

    return [Chip(label: Text('${field.label}: $formatted'))];
  }

  String _relationLabel(String collectionName, String recordId) {
    final definition = adminCollectionDefinitionsByName[collectionName];
    final records = _recordsByCollection[collectionName] ?? const [];
    for (final record in records) {
      if (record['id'] == recordId) {
        return definition == null
            ? (record['id'] as String? ?? recordId)
            : adminRecordLabel(definition, record);
      }
    }
    return recordId;
  }

  List<String> get _destinationKeys => <String>[
    importSection,
    ...adminCollectionDefinitions.map((definition) => definition.name),
  ];
}
