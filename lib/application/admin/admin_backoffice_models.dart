typedef AdminRecord = Map<String, dynamic>;
typedef AdminCollectionRecords = Map<String, List<AdminRecord>>;

class AdminCollectionLoadRequest {
  final String name;
  final String sort;
  final int perPage;

  const AdminCollectionLoadRequest({
    required this.name,
    required this.sort,
    this.perPage = 500,
  });
}
