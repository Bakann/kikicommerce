import '../../config/api_config.dart';
import 'admin_backoffice_repository.dart';

class CategoryProductOrderItem {
  final String relationId;
  final int? position;

  const CategoryProductOrderItem({
    required this.relationId,
    required this.position,
  });
}

class ReorderCategoryProducts {
  static const positionStep = 10;

  final AdminBackofficeRepository repository;

  const ReorderCategoryProducts(this.repository);

  Future<void> call({
    required String authToken,
    required List<CategoryProductOrderItem> items,
    required String draggedRelationId,
    required String targetRelationId,
  }) async {
    final nextItems = reorderedItems(
      items: items,
      draggedRelationId: draggedRelationId,
      targetRelationId: targetRelationId,
    );
    if (identical(nextItems, items)) {
      return;
    }

    await Future.wait([
      for (var index = 0; index < nextItems.length; index++)
        if (nextItems[index].position != positionForIndex(index))
          repository.updateRecord(
            baseUrl: ApiConfig.apiBaseUrl,
            authToken: authToken,
            collection: 'categoryProducts',
            recordId: nextItems[index].relationId,
            data: {'position': positionForIndex(index)},
          ),
    ]);
  }

  static List<CategoryProductOrderItem> reorderedItems({
    required List<CategoryProductOrderItem> items,
    required String draggedRelationId,
    required String targetRelationId,
  }) {
    final oldIndex = items.indexWhere(
      (item) => item.relationId == draggedRelationId,
    );
    final targetIndex = items.indexWhere(
      (item) => item.relationId == targetRelationId,
    );
    if (oldIndex < 0 || targetIndex < 0 || oldIndex == targetIndex) {
      return items;
    }

    final nextItems = [...items];
    final moved = nextItems.removeAt(oldIndex);
    nextItems.insert(targetIndex, moved);
    return nextItems;
  }

  static int positionForIndex(int index) => (index + 1) * positionStep;
}
