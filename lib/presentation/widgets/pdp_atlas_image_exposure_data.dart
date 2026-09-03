class PdpAtlasImageExposureData {
  final String pageType;
  final String productId;
  final String productCode;
  final String productName;
  final String? categoryName;
  final String imageUrl;
  final String imageAlt;
  final String? mediaTitle;
  final String? summary;

  const PdpAtlasImageExposureData({
    this.pageType = 'pdp',
    required this.productId,
    required this.productCode,
    required this.productName,
    required this.categoryName,
    required this.imageUrl,
    required this.imageAlt,
    required this.mediaTitle,
    required this.summary,
  });

  Map<String, Object?> toJson() {
    return {
      'pageType': pageType,
      'productId': productId,
      'productCode': productCode,
      'productName': productName,
      'categoryName': categoryName,
      'imageUrl': imageUrl,
      'imageAlt': imageAlt,
      'mediaTitle': mediaTitle,
      'summary': summary,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is PdpAtlasImageExposureData &&
        other.pageType == pageType &&
        other.productId == productId &&
        other.productCode == productCode &&
        other.productName == productName &&
        other.categoryName == categoryName &&
        other.imageUrl == imageUrl &&
        other.imageAlt == imageAlt &&
        other.mediaTitle == mediaTitle &&
        other.summary == summary;
  }

  @override
  int get hashCode => Object.hash(
    pageType,
    productId,
    productCode,
    productName,
    categoryName,
    imageUrl,
    imageAlt,
    mediaTitle,
    summary,
  );
}
