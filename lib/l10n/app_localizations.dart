import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('fr'),
  ];

  /// Application title shown in the browser tab / app switcher.
  ///
  /// In fr, this message translates to:
  /// **'Kiki\'s Commerce'**
  String get appTitle;

  /// Generic close action (drawer close header).
  ///
  /// In fr, this message translates to:
  /// **'Fermer'**
  String get commonClose;

  /// Contact link in the navigation drawer footer.
  ///
  /// In fr, this message translates to:
  /// **'Contact'**
  String get commonContact;

  /// Retry button shown on error states.
  ///
  /// In fr, this message translates to:
  /// **'Réessayer'**
  String get commonRetry;

  /// Shown when a route/URL does not resolve to a page.
  ///
  /// In fr, this message translates to:
  /// **'Page introuvable.'**
  String get commonRouteNotFound;

  /// Customer-facing message for a network/connectivity failure.
  ///
  /// In fr, this message translates to:
  /// **'Problème de connexion. Vérifiez votre réseau.'**
  String get errorNetwork;

  /// Customer-facing message for a server-side API error.
  ///
  /// In fr, this message translates to:
  /// **'Erreur serveur. Réessayez plus tard.'**
  String get errorServer;

  /// Fallback customer-facing error message with the raw error detail.
  ///
  /// In fr, this message translates to:
  /// **'Erreur: {error}'**
  String errorGeneric(String error);

  /// Label above the FR/EN language switcher in the drawer footer.
  ///
  /// In fr, this message translates to:
  /// **'Langue'**
  String get languageLabel;

  /// French option in the language switcher.
  ///
  /// In fr, this message translates to:
  /// **'Français'**
  String get languageFrench;

  /// English option in the language switcher.
  ///
  /// In fr, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// Placeholder text in the storefront search field.
  ///
  /// In fr, this message translates to:
  /// **'Que recherchez-vous ?'**
  String get navSearchHint;

  /// Tooltip and semantic label for the storefront search action.
  ///
  /// In fr, this message translates to:
  /// **'Recherche'**
  String get navSearchAction;

  /// Tooltip and semantic label for the wishlist navigation action.
  ///
  /// In fr, this message translates to:
  /// **'Favoris'**
  String get navWishlist;

  /// Tooltip and semantic label for the account navigation action.
  ///
  /// In fr, this message translates to:
  /// **'Compte'**
  String get navAccount;

  /// Tooltip and semantic label for the cart navigation action.
  ///
  /// In fr, this message translates to:
  /// **'Panier'**
  String get navCart;

  /// Bottom navigation label for the home tab.
  ///
  /// In fr, this message translates to:
  /// **'Accueil'**
  String get navHome;

  /// Bottom navigation label for the search tab.
  ///
  /// In fr, this message translates to:
  /// **'Rechercher'**
  String get navSearch;

  /// Bottom navigation label for the profile/account tab.
  ///
  /// In fr, this message translates to:
  /// **'Profil'**
  String get navProfile;

  /// Tooltip and semantic label for the cart navigation action when a count badge is visible.
  ///
  /// In fr, this message translates to:
  /// **'Nombre d\'articles dans le panier {count}'**
  String navCartItemsCount(int count);

  /// Semantic label for the storefront brand logo link back to home.
  ///
  /// In fr, this message translates to:
  /// **'Retour à l\'accueil'**
  String get navBackHome;

  /// Tooltip for the navigation drawer menu button when closed.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir le menu'**
  String get navOpenMenu;

  /// Tooltip for the navigation drawer menu button when open.
  ///
  /// In fr, this message translates to:
  /// **'Fermer le menu'**
  String get navCloseMenu;

  /// Drawer link to the commercetools demo lab.
  ///
  /// In fr, this message translates to:
  /// **'Démo commercetools'**
  String get navCommercetoolsDemo;

  /// Section header for promotional highlight links in the drawer.
  ///
  /// In fr, this message translates to:
  /// **'Highlights'**
  String get navHighlights;

  /// Empty state when the category drawer has no active categories.
  ///
  /// In fr, this message translates to:
  /// **'Aucune catégorie active disponible.'**
  String get navNoActiveCategories;

  /// Empty state when the managed navigation drawer has no entries.
  ///
  /// In fr, this message translates to:
  /// **'Aucune navigation active disponible.'**
  String get navNoActiveNavigation;

  /// Error shown when the category list fails to load in the drawer.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger les catégories.\n{error}'**
  String navCategoriesLoadError(String error);

  /// Sport storefront segment label for men.
  ///
  /// In fr, this message translates to:
  /// **'Homme'**
  String get sportSegmentMen;

  /// Sport storefront segment label for women.
  ///
  /// In fr, this message translates to:
  /// **'Femme'**
  String get sportSegmentWomen;

  /// Sport storefront segment label for kids.
  ///
  /// In fr, this message translates to:
  /// **'Enfant'**
  String get sportSegmentKids;

  /// Generic label for browsing a CMS category/segment menu.
  ///
  /// In fr, this message translates to:
  /// **'Parcourir'**
  String get cmsBrowse;

  /// Generic CMS call-to-action label.
  ///
  /// In fr, this message translates to:
  /// **'Découvrir'**
  String get cmsDiscover;

  /// Generic CMS call-to-action to view all items.
  ///
  /// In fr, this message translates to:
  /// **'Voir tout'**
  String get cmsViewAll;

  /// CMS sport category label for shoes.
  ///
  /// In fr, this message translates to:
  /// **'Chaussures'**
  String get cmsShoes;

  /// CMS sport category label for clothing.
  ///
  /// In fr, this message translates to:
  /// **'Vêtements'**
  String get cmsClothing;

  /// CMS sport category label for accessories.
  ///
  /// In fr, this message translates to:
  /// **'Accessoires'**
  String get cmsAccessories;

  /// Nike/Sport CMS carousel heading for currently featured items.
  ///
  /// In fr, this message translates to:
  /// **'En ce moment'**
  String get cmsNikeTrendingNow;

  /// Nike/Sport CMS carousel heading for adventure activity links.
  ///
  /// In fr, this message translates to:
  /// **'Choisis ton aventure'**
  String get cmsNikeChooseYourAdventure;

  /// Nike/Sport CMS tile label for summer essentials.
  ///
  /// In fr, this message translates to:
  /// **'Articles d\'été'**
  String get cmsNikeSummerEssentials;

  /// Nike/Sport CMS tile label for the Ballon d'Or pack.
  ///
  /// In fr, this message translates to:
  /// **'Pack Ballon d\'Or'**
  String get cmsNikeBallonDOrPack;

  /// Nike/Sport CMS carousel heading for iconic product styles.
  ///
  /// In fr, this message translates to:
  /// **'Modèles iconiques'**
  String get cmsNikeIconicStyles;

  /// Nike/Sport CMS carousel heading for brand links.
  ///
  /// In fr, this message translates to:
  /// **'Nos marques'**
  String get cmsNikeOurBrands;

  /// Search results page heading when there is no query yet.
  ///
  /// In fr, this message translates to:
  /// **'Recherche'**
  String get searchTitle;

  /// Search results page heading for a given query.
  ///
  /// In fr, this message translates to:
  /// **'Résultats pour \"{query}\"'**
  String searchTitleWithQuery(String query);

  /// Prompt shown before the visitor has entered a search term.
  ///
  /// In fr, this message translates to:
  /// **'Entrez un terme de recherche.'**
  String get searchPrompt;

  /// Section title above live product-name suggestions on the search entry screen.
  ///
  /// In fr, this message translates to:
  /// **'Meilleures suggestions'**
  String get searchSuggestionsTitle;

  /// Shown when a search returns no products.
  ///
  /// In fr, this message translates to:
  /// **'Aucun résultat pour \"{query}\".'**
  String searchEmptyResults(String query);

  /// Pluralized noun suffix (with leading space) after the bold result count, e.g. ' produits'.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{ produit} other{ produits}}'**
  String searchResultCountSuffix(int count);

  /// Search sort option: newest first.
  ///
  /// In fr, this message translates to:
  /// **'Nouveautés'**
  String get searchSortNewest;

  /// Search sort option: name ascending.
  ///
  /// In fr, this message translates to:
  /// **'Nom A-Z'**
  String get searchSortNameAsc;

  /// Search sort option: name descending.
  ///
  /// In fr, this message translates to:
  /// **'Nom Z-A'**
  String get searchSortNameDesc;

  /// Pagination indicator on the search results page.
  ///
  /// In fr, this message translates to:
  /// **'Page {current} / {total}'**
  String searchPagination(int current, int total);

  /// No description provided for @homeCatalogLoadErrorTitle.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de charger le catalogue'**
  String get homeCatalogLoadErrorTitle;

  /// No description provided for @homeCatalogLoadErrorMessage.
  ///
  /// In fr, this message translates to:
  /// **'Le storefront attend une catégorie active dans PocketBase. Utilisez le backoffice admin pour importer un CSV de démo ou vérifier la connexion API.'**
  String get homeCatalogLoadErrorMessage;

  /// No description provided for @homeOpenBackoffice.
  ///
  /// In fr, this message translates to:
  /// **'Ouvrir le backoffice'**
  String get homeOpenBackoffice;

  /// No description provided for @homeNoActiveCategoriesTitle.
  ///
  /// In fr, this message translates to:
  /// **'Aucune catégorie active'**
  String get homeNoActiveCategoriesTitle;

  /// No description provided for @homeNoActiveCategoriesMessage.
  ///
  /// In fr, this message translates to:
  /// **'Importez un catalogue depuis la route admin pour alimenter les collections PocketBase avant d\'ouvrir le storefront.'**
  String get homeNoActiveCategoriesMessage;

  /// No description provided for @homeImportData.
  ///
  /// In fr, this message translates to:
  /// **'Importer des données'**
  String get homeImportData;

  /// Sober public-facing title when the catalogue fails to load (non edit-mode).
  ///
  /// In fr, this message translates to:
  /// **'Catalogue momentanément indisponible'**
  String get homeCatalogUnavailableTitle;

  /// Sober public-facing body when the catalogue fails to load (non edit-mode).
  ///
  /// In fr, this message translates to:
  /// **'Réessayez dans un instant.'**
  String get homeCatalogUnavailableMessage;

  /// Sober public-facing title when no product/category is available yet (non edit-mode).
  ///
  /// In fr, this message translates to:
  /// **'Bientôt disponible'**
  String get homeEmptyPublicTitle;

  /// Sober public-facing body when the catalogue is genuinely empty (no requested category, non edit-mode).
  ///
  /// In fr, this message translates to:
  /// **'De nouveaux produits arrivent très bientôt.'**
  String get homeEmptyPublicMessage;

  /// Sober public-facing title when a requested category/URL is unknown or inactive (non edit-mode).
  ///
  /// In fr, this message translates to:
  /// **'Page indisponible'**
  String get homeCategoryUnavailableTitle;

  /// Sober public-facing body when a requested category/URL is unknown or inactive (non edit-mode).
  ///
  /// In fr, this message translates to:
  /// **'Cette sélection n\'est pas disponible pour le moment.'**
  String get homeCategoryUnavailableMessage;

  /// No description provided for @plpCatalogueFallbackTitle.
  ///
  /// In fr, this message translates to:
  /// **'Catalogue'**
  String get plpCatalogueFallbackTitle;

  /// No description provided for @plpFiltersComingSoon.
  ///
  /// In fr, this message translates to:
  /// **'Filtres et tri bientôt disponibles.'**
  String get plpFiltersComingSoon;

  /// No description provided for @plpBackToPreviousLevel.
  ///
  /// In fr, this message translates to:
  /// **'Retour au niveau précédent'**
  String get plpBackToPreviousLevel;

  /// Count of products shown under the editorial PLP header.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{{count} article} other{{count} articles}}'**
  String plpProductsCount(int count);

  /// No description provided for @plpFilterAndSort.
  ///
  /// In fr, this message translates to:
  /// **'Filtrer et trier'**
  String get plpFilterAndSort;

  /// Badge shown on a product card when the product is recent.
  ///
  /// In fr, this message translates to:
  /// **'Nouveauté'**
  String get productCardNewBadge;

  /// Sport product card label shown for recently released products.
  ///
  /// In fr, this message translates to:
  /// **'Dernières sorties'**
  String get productCardLatestReleases;

  /// Snackbar shown when the not-yet-wired product-card favorite action is tapped.
  ///
  /// In fr, this message translates to:
  /// **'Favoris bientôt disponibles.'**
  String get productCardFavoritesUnavailable;

  /// No description provided for @pdpPriceUnavailable.
  ///
  /// In fr, this message translates to:
  /// **'Prix indisponible'**
  String get pdpPriceUnavailable;

  /// No description provided for @pdpTabDescription.
  ///
  /// In fr, this message translates to:
  /// **'Description'**
  String get pdpTabDescription;

  /// No description provided for @pdpTabSizeAndFit.
  ///
  /// In fr, this message translates to:
  /// **'Taille & coupe'**
  String get pdpTabSizeAndFit;

  /// No description provided for @pdpTabSizeAndFitInfo.
  ///
  /// In fr, this message translates to:
  /// **'Information Taille & Coupe'**
  String get pdpTabSizeAndFitInfo;

  /// No description provided for @pdpTabShippingAndReturns.
  ///
  /// In fr, this message translates to:
  /// **'Livraison & retours'**
  String get pdpTabShippingAndReturns;

  /// No description provided for @pdpTabShippingAndReturnsLong.
  ///
  /// In fr, this message translates to:
  /// **'Livraison & Retours'**
  String get pdpTabShippingAndReturnsLong;

  /// No description provided for @pdpDescriptionEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucune description détaillée n’est renseignée pour le moment.'**
  String get pdpDescriptionEmpty;

  /// No description provided for @pdpShowMore.
  ///
  /// In fr, this message translates to:
  /// **'Voir plus'**
  String get pdpShowMore;

  /// No description provided for @pdpShowLess.
  ///
  /// In fr, this message translates to:
  /// **'Voir moins'**
  String get pdpShowLess;

  /// Sizing bullet referencing the product type/category.
  ///
  /// In fr, this message translates to:
  /// **'Informations de taille et de coupe adaptées à la catégorie {type}.'**
  String pdpSizingCategory(String type);

  /// Sizing sentence describing the cut for a given silhouette/type (lowercased).
  ///
  /// In fr, this message translates to:
  /// **'Coupe pensée pour une silhouette {type}.'**
  String pdpSizingSilhouette(String type);

  /// Sizing sentence referencing the brand universe.
  ///
  /// In fr, this message translates to:
  /// **'Développé dans l’univers {brand} avec une ligne volontairement épurée.'**
  String pdpSizingBrandUniverse(String brand);

  /// No description provided for @pdpSizingDimensionsVary.
  ///
  /// In fr, this message translates to:
  /// **'Les dimensions et le poids peuvent varier selon la matière du produit.'**
  String get pdpSizingDimensionsVary;

  /// No description provided for @pdpSizingSizeUpAdvice.
  ///
  /// In fr, this message translates to:
  /// **'Si vous hésitez entre deux tailles, choisissez la plus grande pour un porté plus souple.'**
  String get pdpSizingSizeUpAdvice;

  /// No description provided for @pdpShippingReturnsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Retours et échanges offerts'**
  String get pdpShippingReturnsTitle;

  /// No description provided for @pdpShippingReturnsBody.
  ///
  /// In fr, this message translates to:
  /// **'Vous avez la possibilité de retourner ou d’échanger tout produit commandé dans un délai de 30 jours à compter de sa réception, à condition que le produit soit retourné dans son état d’origine.'**
  String get pdpShippingReturnsBody;

  /// No description provided for @pdpShippingFaqHint.
  ///
  /// In fr, this message translates to:
  /// **'Pour plus d’informations, consultez notre FAQ.'**
  String get pdpShippingFaqHint;

  /// No description provided for @pdpShippingFreeTitle.
  ///
  /// In fr, this message translates to:
  /// **'Livraison offerte'**
  String get pdpShippingFreeTitle;

  /// No description provided for @pdpShippingFreeBody.
  ///
  /// In fr, this message translates to:
  /// **'Plusieurs modes de livraison rapides et sécurisés sont proposés selon votre adresse et les disponibilités du produit. Les délais sont estimés à partir de l’expédition de votre commande.'**
  String get pdpShippingFreeBody;

  /// No description provided for @pdpShippingDispatchTitle.
  ///
  /// In fr, this message translates to:
  /// **'Expédition sous 24h'**
  String get pdpShippingDispatchTitle;

  /// No description provided for @pdpShippingDispatchBody.
  ///
  /// In fr, this message translates to:
  /// **'Les commandes effectuées avant midi sont préparées et envoyées le même jour sous condition de disponibilité du stock.'**
  String get pdpShippingDispatchBody;

  /// No description provided for @pdpShippingSummary.
  ///
  /// In fr, this message translates to:
  /// **'Livraison à domicile sous 1 à 3 jours ouvrés. Retours et échanges gratuits en boutique. Click & Collect disponible selon le stock des points de vente.'**
  String get pdpShippingSummary;

  /// Narrative PDP chapter label, e.g. 'Chapitre 2'.
  ///
  /// In fr, this message translates to:
  /// **'Chapitre {position}'**
  String pdpChapterLabel(int position);

  /// Narrative progress indicator, e.g. '2 / 5'.
  ///
  /// In fr, this message translates to:
  /// **'{current} / {total}'**
  String pdpProgressCount(int current, int total);

  /// No description provided for @pdpSizeGuideTitle.
  ///
  /// In fr, this message translates to:
  /// **'Guide des tailles'**
  String get pdpSizeGuideTitle;

  /// No description provided for @pdpSizeGuideBody.
  ///
  /// In fr, this message translates to:
  /// **'Choisissez votre taille habituelle. Si vous hésitez entre deux tailles, privilégiez la plus grande pour un porté plus fluide.'**
  String get pdpSizeGuideBody;

  /// No description provided for @pdpMaterialDetailsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Détails matière'**
  String get pdpMaterialDetailsTitle;

  /// No description provided for @pdpMaterialDetailsEmpty.
  ///
  /// In fr, this message translates to:
  /// **'Aucun détail matière supplémentaire pour ce produit.'**
  String get pdpMaterialDetailsEmpty;

  /// Product reference/SKU label on the narrative PDP.
  ///
  /// In fr, this message translates to:
  /// **'Référence : {code}'**
  String pdpReference(String code);

  /// No description provided for @pdpSelectYourSize.
  ///
  /// In fr, this message translates to:
  /// **'Sélectionnez votre taille'**
  String get pdpSelectYourSize;

  /// No description provided for @pdpSizeGuideLink.
  ///
  /// In fr, this message translates to:
  /// **'Guide des tailles'**
  String get pdpSizeGuideLink;

  /// No description provided for @pdpAddToCart.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter au panier'**
  String get pdpAddToCart;

  /// No description provided for @pdpAddedToCart.
  ///
  /// In fr, this message translates to:
  /// **'Ajouté'**
  String get pdpAddedToCart;

  /// No description provided for @pdpAddToCartRetry.
  ///
  /// In fr, this message translates to:
  /// **'Échec, réessayez'**
  String get pdpAddToCartRetry;

  /// No description provided for @pdpReserveInStore.
  ///
  /// In fr, this message translates to:
  /// **'Réserver en boutique'**
  String get pdpReserveInStore;

  /// No description provided for @pdpCrossSellsTitle.
  ///
  /// In fr, this message translates to:
  /// **'Vous aimerez aussi'**
  String get pdpCrossSellsTitle;

  /// No description provided for @pdpRecentlyViewed.
  ///
  /// In fr, this message translates to:
  /// **'Consulté récemment'**
  String get pdpRecentlyViewed;

  /// No description provided for @pdpExpressCheckout.
  ///
  /// In fr, this message translates to:
  /// **'Paiement express'**
  String get pdpExpressCheckout;

  /// No description provided for @pdpCartMissingCurrency.
  ///
  /// In fr, this message translates to:
  /// **'Devise du produit manquante'**
  String get pdpCartMissingCurrency;

  /// No description provided for @pdpCartCurrencyMismatch.
  ///
  /// In fr, this message translates to:
  /// **'Devise différente, créez un autre panier'**
  String get pdpCartCurrencyMismatch;

  /// No description provided for @pdpCartAddFailed.
  ///
  /// In fr, this message translates to:
  /// **'Impossible d\'ajouter au panier'**
  String get pdpCartAddFailed;

  /// No description provided for @pdpCartAddedSyncFailed.
  ///
  /// In fr, this message translates to:
  /// **'Produit ajouté, impossible de synchroniser le panier'**
  String get pdpCartAddedSyncFailed;

  /// No description provided for @cartEditQuantityTitle.
  ///
  /// In fr, this message translates to:
  /// **'Modifier la quantité'**
  String get cartEditQuantityTitle;

  /// No description provided for @cartQuantityTitle.
  ///
  /// In fr, this message translates to:
  /// **'Quantité'**
  String get cartQuantityTitle;

  /// Quantity row label in the luxe cart quantity sheet (with colon separator).
  ///
  /// In fr, this message translates to:
  /// **'Qté : {quantity}'**
  String cartQuantityLabelLong(int quantity);

  /// Compact quantity label for the sport quantity sheet rows and the line-item selector.
  ///
  /// In fr, this message translates to:
  /// **'Qté {quantity}'**
  String cartQuantityLabelShort(int quantity);

  /// No description provided for @cartRemoveItem.
  ///
  /// In fr, this message translates to:
  /// **'Retirer l\'article'**
  String get cartRemoveItem;

  /// No description provided for @cartUpdateQuantityError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de modifier la quantité.'**
  String get cartUpdateQuantityError;

  /// No description provided for @cartRemoveItemError.
  ///
  /// In fr, this message translates to:
  /// **'Impossible de supprimer l\'article.'**
  String get cartRemoveItemError;

  /// No description provided for @checkoutBack.
  ///
  /// In fr, this message translates to:
  /// **'Retour'**
  String get checkoutBack;

  /// No description provided for @checkoutSignInTitle.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter'**
  String get checkoutSignInTitle;

  /// No description provided for @checkoutSignInSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez vous connecter ou continuer en tant qu’invité(e)'**
  String get checkoutSignInSubtitle;

  /// No description provided for @checkoutCartAlreadyLinked.
  ///
  /// In fr, this message translates to:
  /// **'Ce panier est déjà associé à un compte client.'**
  String get checkoutCartAlreadyLinked;

  /// No description provided for @checkoutSignInOptionSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez vous connecter'**
  String get checkoutSignInOptionSubtitle;

  /// No description provided for @checkoutCreateAccountTitle.
  ///
  /// In fr, this message translates to:
  /// **'Créer un compte'**
  String get checkoutCreateAccountTitle;

  /// No description provided for @checkoutCreateAccountSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Vous n’avez pas encore de compte ?'**
  String get checkoutCreateAccountSubtitle;

  /// No description provided for @checkoutGuestTitle.
  ///
  /// In fr, this message translates to:
  /// **'Continuer sans créer de compte'**
  String get checkoutGuestTitle;

  /// No description provided for @checkoutGuestSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez saisir votre adresse e-mail pour passer votre commande'**
  String get checkoutGuestSubtitle;

  /// No description provided for @checkoutEmailLabel.
  ///
  /// In fr, this message translates to:
  /// **'* E-mail'**
  String get checkoutEmailLabel;

  /// No description provided for @checkoutPasswordLabel.
  ///
  /// In fr, this message translates to:
  /// **'* Mot de passe'**
  String get checkoutPasswordLabel;

  /// No description provided for @checkoutForgotPassword.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe oublié ?'**
  String get checkoutForgotPassword;

  /// No description provided for @checkoutOrContinueWith.
  ///
  /// In fr, this message translates to:
  /// **'Ou continuer avec'**
  String get checkoutOrContinueWith;

  /// No description provided for @checkoutPrivacyNotice.
  ///
  /// In fr, this message translates to:
  /// **'Avis de confidentialité'**
  String get checkoutPrivacyNotice;

  /// No description provided for @checkoutContinue.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get checkoutContinue;

  /// No description provided for @checkoutEmailInvalid.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez saisir une adresse e-mail valide.'**
  String get checkoutEmailInvalid;

  /// No description provided for @checkoutEmptyCartTitle.
  ///
  /// In fr, this message translates to:
  /// **'Votre panier est vide.'**
  String get checkoutEmptyCartTitle;

  /// No description provided for @checkoutEmptyCartSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Ajoutez un produit avant de finaliser votre commande.'**
  String get checkoutEmptyCartSubtitle;

  /// No description provided for @checkoutContinueShopping.
  ///
  /// In fr, this message translates to:
  /// **'Continuer mes achats'**
  String get checkoutContinueShopping;

  /// No description provided for @checkoutStepShippingAddress.
  ///
  /// In fr, this message translates to:
  /// **'1. Adresse de livraison'**
  String get checkoutStepShippingAddress;

  /// No description provided for @checkoutStepShippingMethod.
  ///
  /// In fr, this message translates to:
  /// **'2. Mode de livraison'**
  String get checkoutStepShippingMethod;

  /// No description provided for @checkoutStepBillingPayment.
  ///
  /// In fr, this message translates to:
  /// **'3. Facturation et paiement'**
  String get checkoutStepBillingPayment;

  /// No description provided for @checkoutEnterShippingAddress.
  ///
  /// In fr, this message translates to:
  /// **'Veuillez saisir votre adresse de livraison :'**
  String get checkoutEnterShippingAddress;

  /// No description provided for @checkoutAddShippingAddress.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter une adresse de livraison'**
  String get checkoutAddShippingAddress;

  /// No description provided for @checkoutEdit.
  ///
  /// In fr, this message translates to:
  /// **'Modifier'**
  String get checkoutEdit;

  /// No description provided for @checkoutDeliveryIdentityNotice.
  ///
  /// In fr, this message translates to:
  /// **'La présence du client, sa signature et une pièce d’identité sont requises pour la livraison.'**
  String get checkoutDeliveryIdentityNotice;

  /// No description provided for @checkoutChooseShippingMethod.
  ///
  /// In fr, this message translates to:
  /// **'Choisir la méthode de livraison'**
  String get checkoutChooseShippingMethod;

  /// Guest checkout banner showing the email address used for the order.
  ///
  /// In fr, this message translates to:
  /// **'Adresse e-mail : {email}'**
  String checkoutEmailAddressLabel(String email);

  /// No description provided for @checkoutEditEmail.
  ///
  /// In fr, this message translates to:
  /// **'Modifier l’e-mail'**
  String get checkoutEditEmail;

  /// No description provided for @checkoutOrderSummary.
  ///
  /// In fr, this message translates to:
  /// **'Récapitulatif de la commande'**
  String get checkoutOrderSummary;

  /// Number of items in the order summary header.
  ///
  /// In fr, this message translates to:
  /// **'{count, plural, =1{{count} produit} other{{count} produits}}'**
  String checkoutItemCount(int count);

  /// No description provided for @checkoutPackagingTitle.
  ///
  /// In fr, this message translates to:
  /// **'Emballage et cadeaux'**
  String get checkoutPackagingTitle;

  /// No description provided for @checkoutPackagingFreeOptions.
  ///
  /// In fr, this message translates to:
  /// **'Options offertes'**
  String get checkoutPackagingFreeOptions;

  /// No description provided for @checkoutPackagingNoPricesNote.
  ///
  /// In fr, this message translates to:
  /// **'Les prix et les factures ne sont pas envoyés avec les produits.'**
  String get checkoutPackagingNoPricesNote;

  /// Title of the signature packaging option; brand is the storefront brand name.
  ///
  /// In fr, this message translates to:
  /// **'Packaging signature {brand}'**
  String checkoutPackagingSignatureTitle(String brand);

  /// Descriptive blurb for the signature packaging option; brand is the storefront brand name.
  ///
  /// In fr, this message translates to:
  /// **'L’emballage signature de {brand} est produit de manière responsable et certifié à base de plus de 90% de matériaux recyclés.'**
  String checkoutPackagingSignatureSubtitle(String brand);

  /// No description provided for @checkoutPackagingEcoTitle.
  ///
  /// In fr, this message translates to:
  /// **'Eco Packaging'**
  String get checkoutPackagingEcoTitle;

  /// Toggle to add a branded shopping bag; brand is the storefront brand name.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter un sac shopping {brand}'**
  String checkoutAddShoppingBag(String brand);

  /// No description provided for @checkoutGiftWrapTitle.
  ///
  /// In fr, this message translates to:
  /// **'Offrir en cadeau'**
  String get checkoutGiftWrapTitle;

  /// No description provided for @checkoutGiftWrapSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Personnalisez gratuitement votre cadeau'**
  String get checkoutGiftWrapSubtitle;

  /// No description provided for @checkoutTotal.
  ///
  /// In fr, this message translates to:
  /// **'Total'**
  String get checkoutTotal;

  /// No description provided for @checkoutSubtotal.
  ///
  /// In fr, this message translates to:
  /// **'Sous-total'**
  String get checkoutSubtotal;

  /// No description provided for @checkoutShipping.
  ///
  /// In fr, this message translates to:
  /// **'Livraison'**
  String get checkoutShipping;

  /// No description provided for @checkoutShippingEstimate.
  ///
  /// In fr, this message translates to:
  /// **'Date de livraison et coûts estimés'**
  String get checkoutShippingEstimate;

  /// No description provided for @checkoutTaxesIncluded.
  ///
  /// In fr, this message translates to:
  /// **'Taxes incluses'**
  String get checkoutTaxesIncluded;

  /// No description provided for @checkoutOrPayWith.
  ///
  /// In fr, this message translates to:
  /// **'ou payer avec'**
  String get checkoutOrPayWith;

  /// No description provided for @checkoutHelpServices.
  ///
  /// In fr, this message translates to:
  /// **'Aide & Services'**
  String get checkoutHelpServices;

  /// No description provided for @checkoutServiceSecurePayment.
  ///
  /// In fr, this message translates to:
  /// **'Paiement 100% sécurisé'**
  String get checkoutServiceSecurePayment;

  /// No description provided for @checkoutServiceSecurePaymentBody.
  ///
  /// In fr, this message translates to:
  /// **'Vos informations de carte de crédit sont en sécurité chez nous. Toutes les informations sont protégées par la technologie SSL (Secure Sockets Layer).'**
  String get checkoutServiceSecurePaymentBody;

  /// No description provided for @checkoutServiceHelp.
  ///
  /// In fr, this message translates to:
  /// **'Besoin d\'aide ?'**
  String get checkoutServiceHelp;

  /// No description provided for @checkoutServiceHelpBody.
  ///
  /// In fr, this message translates to:
  /// **'Nos conseillers accompagnent la commande, la personnalisation et le suivi de livraison.'**
  String get checkoutServiceHelpBody;

  /// No description provided for @checkoutServiceFreeShipping.
  ///
  /// In fr, this message translates to:
  /// **'Livraison standard offerte'**
  String get checkoutServiceFreeShipping;

  /// No description provided for @checkoutServiceFreeShippingBody.
  ///
  /// In fr, this message translates to:
  /// **'La date de livraison et les coûts estimés sont confirmés à l\'étape suivante.'**
  String get checkoutServiceFreeShippingBody;

  /// No description provided for @checkoutServiceReturns.
  ///
  /// In fr, this message translates to:
  /// **'Échange et remboursement'**
  String get checkoutServiceReturns;

  /// No description provided for @checkoutServiceReturnsBody.
  ///
  /// In fr, this message translates to:
  /// **'Les retours et remboursements sont traités selon les conditions de vente applicables à la commande.'**
  String get checkoutServiceReturnsBody;

  /// No description provided for @checkoutFooterPersonalData.
  ///
  /// In fr, this message translates to:
  /// **'Données personnelles'**
  String get checkoutFooterPersonalData;

  /// No description provided for @checkoutFooterLegalNotice.
  ///
  /// In fr, this message translates to:
  /// **'Mentions légales'**
  String get checkoutFooterLegalNotice;

  /// No description provided for @accountBarrierLabel.
  ///
  /// In fr, this message translates to:
  /// **'Fermer le compte'**
  String get accountBarrierLabel;

  /// No description provided for @accountSignInTitle.
  ///
  /// In fr, this message translates to:
  /// **'Se connecter'**
  String get accountSignInTitle;

  /// No description provided for @accountSignInSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Pour accéder à votre compte'**
  String get accountSignInSubtitle;

  /// No description provided for @accountSignInPending.
  ///
  /// In fr, this message translates to:
  /// **'La connexion client sera branchée prochainement.'**
  String get accountSignInPending;

  /// No description provided for @accountRegisterTitle.
  ///
  /// In fr, this message translates to:
  /// **'S\'inscrire'**
  String get accountRegisterTitle;

  /// No description provided for @accountRegisterSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Vous n\'avez pas de compte ?'**
  String get accountRegisterSubtitle;

  /// No description provided for @accountRegisterPending.
  ///
  /// In fr, this message translates to:
  /// **'La création de compte sera branchée prochainement.'**
  String get accountRegisterPending;

  /// No description provided for @accountOrderTrackingTitle.
  ///
  /// In fr, this message translates to:
  /// **'Suivre votre commande'**
  String get accountOrderTrackingTitle;

  /// No description provided for @accountOrderTrackingSubtitle.
  ///
  /// In fr, this message translates to:
  /// **'Soyez informé(e) des dernières mises à jour sur votre commande'**
  String get accountOrderTrackingSubtitle;

  /// No description provided for @accountOrderTrackingPending.
  ///
  /// In fr, this message translates to:
  /// **'Le suivi de commande sera branché prochainement.'**
  String get accountOrderTrackingPending;

  /// No description provided for @accountToolbarSearch.
  ///
  /// In fr, this message translates to:
  /// **'Recherche'**
  String get accountToolbarSearch;

  /// No description provided for @accountToolbarFavorites.
  ///
  /// In fr, this message translates to:
  /// **'Favoris'**
  String get accountToolbarFavorites;

  /// No description provided for @accountToolbarMyAccount.
  ///
  /// In fr, this message translates to:
  /// **'Mon compte'**
  String get accountToolbarMyAccount;

  /// No description provided for @accountToolbarCart.
  ///
  /// In fr, this message translates to:
  /// **'Panier'**
  String get accountToolbarCart;

  /// No description provided for @accountPrivacyNotice.
  ///
  /// In fr, this message translates to:
  /// **'Avis de confidentialité'**
  String get accountPrivacyNotice;

  /// No description provided for @accountEmailLabel.
  ///
  /// In fr, this message translates to:
  /// **'* E-mail'**
  String get accountEmailLabel;

  /// No description provided for @accountPasswordLabel.
  ///
  /// In fr, this message translates to:
  /// **'* Mot de passe'**
  String get accountPasswordLabel;

  /// No description provided for @accountForgotPassword.
  ///
  /// In fr, this message translates to:
  /// **'Mot de passe oublié ?'**
  String get accountForgotPassword;

  /// No description provided for @accountSignInButton.
  ///
  /// In fr, this message translates to:
  /// **'Me connecter'**
  String get accountSignInButton;

  /// No description provided for @accountCreateAccountButton.
  ///
  /// In fr, this message translates to:
  /// **'Créer un compte'**
  String get accountCreateAccountButton;

  /// No description provided for @accountOrderNumberLabel.
  ///
  /// In fr, this message translates to:
  /// **'* Numéro de commande'**
  String get accountOrderNumberLabel;

  /// No description provided for @accountContinueButton.
  ///
  /// In fr, this message translates to:
  /// **'Continuer'**
  String get accountContinueButton;

  /// No description provided for @accountOrDivider.
  ///
  /// In fr, this message translates to:
  /// **'Ou'**
  String get accountOrDivider;

  /// Lead-in sentence before the underlined brand name; keep the trailing space.
  ///
  /// In fr, this message translates to:
  /// **'Connectez-vous à votre compte '**
  String get accountLinkedCopyLead;

  /// No description provided for @accountBenefitOrderHistory.
  ///
  /// In fr, this message translates to:
  /// **'Suivre vos commandes\net l\'historique de vos\nachats'**
  String get accountBenefitOrderHistory;

  /// No description provided for @accountBenefitReturns.
  ///
  /// In fr, this message translates to:
  /// **'Demander un retour ou\nun échange'**
  String get accountBenefitReturns;

  /// No description provided for @accountBenefitWishlist.
  ///
  /// In fr, this message translates to:
  /// **'Ajouter des articles à\nvotre wishlist'**
  String get accountBenefitWishlist;

  /// No description provided for @accountBenefitAdvisor.
  ///
  /// In fr, this message translates to:
  /// **'Contacter votre\nconseiller'**
  String get accountBenefitAdvisor;

  /// No description provided for @accountBenefitManageAccount.
  ///
  /// In fr, this message translates to:
  /// **'Gérer les informations\nde votre compte et vos\nabonnements'**
  String get accountBenefitManageAccount;

  /// No description provided for @pdpFoilTiltHint.
  ///
  /// In fr, this message translates to:
  /// **'Touchez l’image ou inclinez le téléphone'**
  String get pdpFoilTiltHint;

  /// No description provided for @pdpFoilEnableMotionHint.
  ///
  /// In fr, this message translates to:
  /// **'Touchez pour activer le reflet'**
  String get pdpFoilEnableMotionHint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
