import 'category.dart';
import 'product.dart';

class CategoryProduct {
  final String id;
  final String categoryId;
  final String productId;
  final int? position;
  final bool isPrimary;
  final bool isActive;

  // Expanded
  final Category? category;
  final Product? product;

  CategoryProduct({
    required this.id,
    required this.categoryId,
    required this.productId,
    this.position,
    this.isPrimary = false,
    this.isActive = true,
    this.category,
    this.product,
  });

  CategoryProduct copyWith({Product? product}) {
    return CategoryProduct(
      id: id,
      categoryId: categoryId,
      productId: productId,
      position: position,
      isPrimary: isPrimary,
      isActive: isActive,
      category: category,
      product: product ?? this.product,
    );
  }

  factory CategoryProduct.fromJson(Map<String, dynamic> json) {
    final expand = json['expand'] as Map<String, dynamic>? ?? {};

    return CategoryProduct(
      id: json['id'] as String,
      categoryId: json['category'] as String,
      productId: json['product'] as String,
      position: (json['position'] as num?)?.toInt(),
      isPrimary: json['isPrimary'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? true,
      category: expand['category'] != null
          ? Category.fromJson(expand['category'] as Map<String, dynamic>)
          : null,
      product: expand['product'] != null
          ? Product.fromJson(expand['product'] as Map<String, dynamic>)
          : null,
    );
  }
}
