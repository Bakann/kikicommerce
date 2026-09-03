import 'package:flutter_test/flutter_test.dart';
import 'package:kiki_commerce/application/admin/catalog_import_report.dart';
import 'package:kiki_commerce/application/catalog/catalog_invalidations.dart';

void main() {
  group('catalog invalidation contracts', () {
    test(
      'saved product text invalidates PDP, listings, search, and routes',
      () {
        expect(invalidationsForSavedProductText('prod-1'), [
          const ProductDetailInvalidation('prod-1'),
          const AllProductListsInvalidation(),
          const AllSearchResultsInvalidation(),
          const AllProductRoutesInvalidation(),
        ]);
      },
    );

    test('created product in category keeps invalidations targeted', () {
      expect(
        invalidationsForCreatedProductInCategory(
          categoryId: 'cat-1',
          productId: 'prod-1',
        ),
        [
          const CategoryPlpInvalidation('cat-1'),
          const ProductDetailInvalidation('prod-1'),
          const AllSearchResultsInvalidation(),
          const AllProductRoutesInvalidation(),
        ],
      );
    });

    test(
      'category admin save invalidates category tree and related catalog',
      () {
        expect(
          invalidationsForAdminSave(
            collection: 'categories',
            recordId: 'cat-1',
            data: {'slug': 'robes'},
          ),
          [
            const CategoryTreeInvalidation(),
            const CategoryPlpInvalidation('cat-1'),
            const CategoryBySlugInvalidation('robes'),
            const AllProductListsInvalidation(),
            const AllProductRoutesInvalidation(),
            const DrawerNavigationInvalidation(),
          ],
        );
      },
    );

    test('category product admin save targets known category and product', () {
      expect(
        invalidationsForAdminSave(
          collection: 'categoryProducts',
          data: {'category': 'cat-1', 'product': 'prod-1'},
        ),
        [
          const CategoryPlpInvalidation('cat-1'),
          const ProductDetailInvalidation('prod-1'),
          const AllProductRoutesInvalidation(),
        ],
      );
    });

    test(
      'media replacement invalidates product surfaces and media library',
      () {
        expect(invalidationsForReplacedProductMedia(productId: 'prod-1'), [
          const ProductDetailInvalidation('prod-1'),
          const AllProductListsInvalidation(),
          const AllSearchResultsInvalidation(),
          const DrawerNavigationInvalidation(),
          const MediaLibraryInvalidation(),
        ]);
      },
    );

    test('import report broadens only touched collection domains', () {
      final report = CatalogImportReport(totalRows: 2)
        ..markCreated('products')
        ..markUpdated('medias');

      expect(invalidationsForCatalogImportReport(report), [
        const AllProductDetailsInvalidation(),
        const AllProductListsInvalidation(),
        const AllSearchResultsInvalidation(),
        const AllProductRoutesInvalidation(),
        const DrawerNavigationInvalidation(),
        const MediaLibraryInvalidation(),
      ]);
    });

    test('navigation item delete invalidates only drawer navigation', () {
      expect(
        invalidationsForAdminDelete(
          collection: 'navigation_items',
          recordId: 'nav-1',
        ),
        [const DrawerNavigationInvalidation()],
      );
    });

    test('cms page save invalidates CMS page reads', () {
      expect(
        invalidationsForAdminSave(
          collection: 'cms_pages',
          recordId: 'page-1',
          data: {'code': 'homepage_nike'},
        ),
        [const CmsPagesInvalidation()],
      );
    });

    test('page section save invalidates CMS page reads', () {
      expect(
        invalidationsForAdminSave(
          collection: 'page_sections',
          recordId: 'sec-1',
          data: const {},
        ),
        [const CmsPagesInvalidation()],
      );
    });

    test('cms page import broadens to CMS page reads', () {
      final report = CatalogImportReport(totalRows: 1)
        ..markUpdated('cms_pages');

      expect(invalidationsForCatalogImportReport(report), [
        const CmsPagesInvalidation(),
      ]);
    });
  });
}
