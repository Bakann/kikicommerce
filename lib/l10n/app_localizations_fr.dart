// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Kiki\'s Commerce';

  @override
  String get commonClose => 'Fermer';

  @override
  String get commonContact => 'Contact';

  @override
  String get commonRetry => 'Réessayer';

  @override
  String get commonRouteNotFound => 'Page introuvable.';

  @override
  String get errorNetwork => 'Problème de connexion. Vérifiez votre réseau.';

  @override
  String get errorServer => 'Erreur serveur. Réessayez plus tard.';

  @override
  String errorGeneric(String error) {
    return 'Erreur: $error';
  }

  @override
  String get languageLabel => 'Langue';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageEnglish => 'English';

  @override
  String get navSearchHint => 'Que recherchez-vous ?';

  @override
  String get navSearchAction => 'Recherche';

  @override
  String get navWishlist => 'Favoris';

  @override
  String get navAccount => 'Compte';

  @override
  String get navCart => 'Panier';

  @override
  String get navHome => 'Accueil';

  @override
  String get navSearch => 'Rechercher';

  @override
  String get navProfile => 'Profil';

  @override
  String navCartItemsCount(int count) {
    return 'Nombre d\'articles dans le panier $count';
  }

  @override
  String get navBackHome => 'Retour à l\'accueil';

  @override
  String get navOpenMenu => 'Ouvrir le menu';

  @override
  String get navCloseMenu => 'Fermer le menu';

  @override
  String get navCommercetoolsDemo => 'Démo commercetools';

  @override
  String get navHighlights => 'Highlights';

  @override
  String get navNoActiveCategories => 'Aucune catégorie active disponible.';

  @override
  String get navNoActiveNavigation => 'Aucune navigation active disponible.';

  @override
  String navCategoriesLoadError(String error) {
    return 'Impossible de charger les catégories.\n$error';
  }

  @override
  String get sportSegmentMen => 'Homme';

  @override
  String get sportSegmentWomen => 'Femme';

  @override
  String get sportSegmentKids => 'Enfant';

  @override
  String get cmsBrowse => 'Parcourir';

  @override
  String get cmsDiscover => 'Découvrir';

  @override
  String get cmsViewAll => 'Voir tout';

  @override
  String get cmsShoes => 'Chaussures';

  @override
  String get cmsClothing => 'Vêtements';

  @override
  String get cmsAccessories => 'Accessoires';

  @override
  String get cmsNikeTrendingNow => 'En ce moment';

  @override
  String get cmsNikeChooseYourAdventure => 'Choisis ton aventure';

  @override
  String get cmsNikeSummerEssentials => 'Articles d\'été';

  @override
  String get cmsNikeBallonDOrPack => 'Pack Ballon d\'Or';

  @override
  String get cmsNikeIconicStyles => 'Modèles iconiques';

  @override
  String get cmsNikeOurBrands => 'Nos marques';

  @override
  String get searchTitle => 'Recherche';

  @override
  String searchTitleWithQuery(String query) {
    return 'Résultats pour \"$query\"';
  }

  @override
  String get searchPrompt => 'Entrez un terme de recherche.';

  @override
  String get searchSuggestionsTitle => 'Meilleures suggestions';

  @override
  String searchEmptyResults(String query) {
    return 'Aucun résultat pour \"$query\".';
  }

  @override
  String searchResultCountSuffix(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: ' produits',
      one: ' produit',
    );
    return '$_temp0';
  }

  @override
  String get searchSortNewest => 'Nouveautés';

  @override
  String get searchSortNameAsc => 'Nom A-Z';

  @override
  String get searchSortNameDesc => 'Nom Z-A';

  @override
  String searchPagination(int current, int total) {
    return 'Page $current / $total';
  }

  @override
  String get homeCatalogLoadErrorTitle => 'Impossible de charger le catalogue';

  @override
  String get homeCatalogLoadErrorMessage =>
      'Le storefront attend une catégorie active dans PocketBase. Utilisez le backoffice admin pour importer un CSV de démo ou vérifier la connexion API.';

  @override
  String get homeOpenBackoffice => 'Ouvrir le backoffice';

  @override
  String get homeNoActiveCategoriesTitle => 'Aucune catégorie active';

  @override
  String get homeNoActiveCategoriesMessage =>
      'Importez un catalogue depuis la route admin pour alimenter les collections PocketBase avant d\'ouvrir le storefront.';

  @override
  String get homeImportData => 'Importer des données';

  @override
  String get homeCatalogUnavailableTitle =>
      'Catalogue momentanément indisponible';

  @override
  String get homeCatalogUnavailableMessage => 'Réessayez dans un instant.';

  @override
  String get homeEmptyPublicTitle => 'Bientôt disponible';

  @override
  String get homeEmptyPublicMessage =>
      'De nouveaux produits arrivent très bientôt.';

  @override
  String get homeCategoryUnavailableTitle => 'Page indisponible';

  @override
  String get homeCategoryUnavailableMessage =>
      'Cette sélection n\'est pas disponible pour le moment.';

  @override
  String get plpCatalogueFallbackTitle => 'Catalogue';

  @override
  String get plpFiltersComingSoon => 'Filtres et tri bientôt disponibles.';

  @override
  String get plpBackToPreviousLevel => 'Retour au niveau précédent';

  @override
  String plpProductsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count articles',
      one: '$count article',
    );
    return '$_temp0';
  }

  @override
  String get plpFilterAndSort => 'Filtrer et trier';

  @override
  String get productCardNewBadge => 'Nouveauté';

  @override
  String get productCardLatestReleases => 'Dernières sorties';

  @override
  String get productCardFavoritesUnavailable => 'Favoris bientôt disponibles.';

  @override
  String get pdpPriceUnavailable => 'Prix indisponible';

  @override
  String get pdpTabDescription => 'Description';

  @override
  String get pdpTabSizeAndFit => 'Taille & coupe';

  @override
  String get pdpTabSizeAndFitInfo => 'Information Taille & Coupe';

  @override
  String get pdpTabShippingAndReturns => 'Livraison & retours';

  @override
  String get pdpTabShippingAndReturnsLong => 'Livraison & Retours';

  @override
  String get pdpDescriptionEmpty =>
      'Aucune description détaillée n’est renseignée pour le moment.';

  @override
  String get pdpShowMore => 'Voir plus';

  @override
  String get pdpShowLess => 'Voir moins';

  @override
  String pdpSizingCategory(String type) {
    return 'Informations de taille et de coupe adaptées à la catégorie $type.';
  }

  @override
  String pdpSizingSilhouette(String type) {
    return 'Coupe pensée pour une silhouette $type.';
  }

  @override
  String pdpSizingBrandUniverse(String brand) {
    return 'Développé dans l’univers $brand avec une ligne volontairement épurée.';
  }

  @override
  String get pdpSizingDimensionsVary =>
      'Les dimensions et le poids peuvent varier selon la matière du produit.';

  @override
  String get pdpSizingSizeUpAdvice =>
      'Si vous hésitez entre deux tailles, choisissez la plus grande pour un porté plus souple.';

  @override
  String get pdpShippingReturnsTitle => 'Retours et échanges offerts';

  @override
  String get pdpShippingReturnsBody =>
      'Vous avez la possibilité de retourner ou d’échanger tout produit commandé dans un délai de 30 jours à compter de sa réception, à condition que le produit soit retourné dans son état d’origine.';

  @override
  String get pdpShippingFaqHint =>
      'Pour plus d’informations, consultez notre FAQ.';

  @override
  String get pdpShippingFreeTitle => 'Livraison offerte';

  @override
  String get pdpShippingFreeBody =>
      'Plusieurs modes de livraison rapides et sécurisés sont proposés selon votre adresse et les disponibilités du produit. Les délais sont estimés à partir de l’expédition de votre commande.';

  @override
  String get pdpShippingDispatchTitle => 'Expédition sous 24h';

  @override
  String get pdpShippingDispatchBody =>
      'Les commandes effectuées avant midi sont préparées et envoyées le même jour sous condition de disponibilité du stock.';

  @override
  String get pdpShippingSummary =>
      'Livraison à domicile sous 1 à 3 jours ouvrés. Retours et échanges gratuits en boutique. Click & Collect disponible selon le stock des points de vente.';

  @override
  String pdpChapterLabel(int position) {
    return 'Chapitre $position';
  }

  @override
  String pdpProgressCount(int current, int total) {
    return '$current / $total';
  }

  @override
  String get pdpSizeGuideTitle => 'Guide des tailles';

  @override
  String get pdpSizeGuideBody =>
      'Choisissez votre taille habituelle. Si vous hésitez entre deux tailles, privilégiez la plus grande pour un porté plus fluide.';

  @override
  String get pdpMaterialDetailsTitle => 'Détails matière';

  @override
  String get pdpMaterialDetailsEmpty =>
      'Aucun détail matière supplémentaire pour ce produit.';

  @override
  String pdpReference(String code) {
    return 'Référence : $code';
  }

  @override
  String get pdpSelectYourSize => 'Sélectionnez votre taille';

  @override
  String get pdpSizeGuideLink => 'Guide des tailles';

  @override
  String get pdpAddToCart => 'Ajouter au panier';

  @override
  String get pdpAddedToCart => 'Ajouté';

  @override
  String get pdpAddToCartRetry => 'Échec, réessayez';

  @override
  String get pdpReserveInStore => 'Réserver en boutique';

  @override
  String get pdpCrossSellsTitle => 'Vous aimerez aussi';

  @override
  String get pdpRecentlyViewed => 'Consulté récemment';

  @override
  String get pdpExpressCheckout => 'Paiement express';

  @override
  String get pdpCartMissingCurrency => 'Devise du produit manquante';

  @override
  String get pdpCartCurrencyMismatch =>
      'Devise différente, créez un autre panier';

  @override
  String get pdpCartAddFailed => 'Impossible d\'ajouter au panier';

  @override
  String get pdpCartAddedSyncFailed =>
      'Produit ajouté, impossible de synchroniser le panier';

  @override
  String get cartEditQuantityTitle => 'Modifier la quantité';

  @override
  String get cartQuantityTitle => 'Quantité';

  @override
  String cartQuantityLabelLong(int quantity) {
    return 'Qté : $quantity';
  }

  @override
  String cartQuantityLabelShort(int quantity) {
    return 'Qté $quantity';
  }

  @override
  String get cartRemoveItem => 'Retirer l\'article';

  @override
  String get cartUpdateQuantityError => 'Impossible de modifier la quantité.';

  @override
  String get cartRemoveItemError => 'Impossible de supprimer l\'article.';

  @override
  String get checkoutBack => 'Retour';

  @override
  String get checkoutSignInTitle => 'Se connecter';

  @override
  String get checkoutSignInSubtitle =>
      'Veuillez vous connecter ou continuer en tant qu’invité(e)';

  @override
  String get checkoutCartAlreadyLinked =>
      'Ce panier est déjà associé à un compte client.';

  @override
  String get checkoutSignInOptionSubtitle => 'Veuillez vous connecter';

  @override
  String get checkoutCreateAccountTitle => 'Créer un compte';

  @override
  String get checkoutCreateAccountSubtitle =>
      'Vous n’avez pas encore de compte ?';

  @override
  String get checkoutGuestTitle => 'Continuer sans créer de compte';

  @override
  String get checkoutGuestSubtitle =>
      'Veuillez saisir votre adresse e-mail pour passer votre commande';

  @override
  String get checkoutEmailLabel => '* E-mail';

  @override
  String get checkoutPasswordLabel => '* Mot de passe';

  @override
  String get checkoutForgotPassword => 'Mot de passe oublié ?';

  @override
  String get checkoutOrContinueWith => 'Ou continuer avec';

  @override
  String get checkoutPrivacyNotice => 'Avis de confidentialité';

  @override
  String get checkoutContinue => 'Continuer';

  @override
  String get checkoutEmailInvalid =>
      'Veuillez saisir une adresse e-mail valide.';

  @override
  String get checkoutEmptyCartTitle => 'Votre panier est vide.';

  @override
  String get checkoutEmptyCartSubtitle =>
      'Ajoutez un produit avant de finaliser votre commande.';

  @override
  String get checkoutContinueShopping => 'Continuer mes achats';

  @override
  String get checkoutStepShippingAddress => '1. Adresse de livraison';

  @override
  String get checkoutStepShippingMethod => '2. Mode de livraison';

  @override
  String get checkoutStepBillingPayment => '3. Facturation et paiement';

  @override
  String get checkoutEnterShippingAddress =>
      'Veuillez saisir votre adresse de livraison :';

  @override
  String get checkoutAddShippingAddress => 'Ajouter une adresse de livraison';

  @override
  String get checkoutEdit => 'Modifier';

  @override
  String get checkoutDeliveryIdentityNotice =>
      'La présence du client, sa signature et une pièce d’identité sont requises pour la livraison.';

  @override
  String get checkoutChooseShippingMethod => 'Choisir la méthode de livraison';

  @override
  String checkoutEmailAddressLabel(String email) {
    return 'Adresse e-mail : $email';
  }

  @override
  String get checkoutEditEmail => 'Modifier l’e-mail';

  @override
  String get checkoutOrderSummary => 'Récapitulatif de la commande';

  @override
  String checkoutItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count produits',
      one: '$count produit',
    );
    return '$_temp0';
  }

  @override
  String get checkoutPackagingTitle => 'Emballage et cadeaux';

  @override
  String get checkoutPackagingFreeOptions => 'Options offertes';

  @override
  String get checkoutPackagingNoPricesNote =>
      'Les prix et les factures ne sont pas envoyés avec les produits.';

  @override
  String checkoutPackagingSignatureTitle(String brand) {
    return 'Packaging signature $brand';
  }

  @override
  String checkoutPackagingSignatureSubtitle(String brand) {
    return 'L’emballage signature de $brand est produit de manière responsable et certifié à base de plus de 90% de matériaux recyclés.';
  }

  @override
  String get checkoutPackagingEcoTitle => 'Eco Packaging';

  @override
  String checkoutAddShoppingBag(String brand) {
    return 'Ajouter un sac shopping $brand';
  }

  @override
  String get checkoutGiftWrapTitle => 'Offrir en cadeau';

  @override
  String get checkoutGiftWrapSubtitle =>
      'Personnalisez gratuitement votre cadeau';

  @override
  String get checkoutTotal => 'Total';

  @override
  String get checkoutSubtotal => 'Sous-total';

  @override
  String get checkoutShipping => 'Livraison';

  @override
  String get checkoutShippingEstimate => 'Date de livraison et coûts estimés';

  @override
  String get checkoutTaxesIncluded => 'Taxes incluses';

  @override
  String get checkoutOrPayWith => 'ou payer avec';

  @override
  String get checkoutHelpServices => 'Aide & Services';

  @override
  String get checkoutServiceSecurePayment => 'Paiement 100% sécurisé';

  @override
  String get checkoutServiceSecurePaymentBody =>
      'Vos informations de carte de crédit sont en sécurité chez nous. Toutes les informations sont protégées par la technologie SSL (Secure Sockets Layer).';

  @override
  String get checkoutServiceHelp => 'Besoin d\'aide ?';

  @override
  String get checkoutServiceHelpBody =>
      'Nos conseillers accompagnent la commande, la personnalisation et le suivi de livraison.';

  @override
  String get checkoutServiceFreeShipping => 'Livraison standard offerte';

  @override
  String get checkoutServiceFreeShippingBody =>
      'La date de livraison et les coûts estimés sont confirmés à l\'étape suivante.';

  @override
  String get checkoutServiceReturns => 'Échange et remboursement';

  @override
  String get checkoutServiceReturnsBody =>
      'Les retours et remboursements sont traités selon les conditions de vente applicables à la commande.';

  @override
  String get checkoutFooterPersonalData => 'Données personnelles';

  @override
  String get checkoutFooterLegalNotice => 'Mentions légales';

  @override
  String get accountBarrierLabel => 'Fermer le compte';

  @override
  String get accountSignInTitle => 'Se connecter';

  @override
  String get accountSignInSubtitle => 'Pour accéder à votre compte';

  @override
  String get accountSignInPending =>
      'La connexion client sera branchée prochainement.';

  @override
  String get accountRegisterTitle => 'S\'inscrire';

  @override
  String get accountRegisterSubtitle => 'Vous n\'avez pas de compte ?';

  @override
  String get accountRegisterPending =>
      'La création de compte sera branchée prochainement.';

  @override
  String get accountOrderTrackingTitle => 'Suivre votre commande';

  @override
  String get accountOrderTrackingSubtitle =>
      'Soyez informé(e) des dernières mises à jour sur votre commande';

  @override
  String get accountOrderTrackingPending =>
      'Le suivi de commande sera branché prochainement.';

  @override
  String get accountToolbarSearch => 'Recherche';

  @override
  String get accountToolbarFavorites => 'Favoris';

  @override
  String get accountToolbarMyAccount => 'Mon compte';

  @override
  String get accountToolbarCart => 'Panier';

  @override
  String get accountPrivacyNotice => 'Avis de confidentialité';

  @override
  String get accountEmailLabel => '* E-mail';

  @override
  String get accountPasswordLabel => '* Mot de passe';

  @override
  String get accountForgotPassword => 'Mot de passe oublié ?';

  @override
  String get accountSignInButton => 'Me connecter';

  @override
  String get accountCreateAccountButton => 'Créer un compte';

  @override
  String get accountOrderNumberLabel => '* Numéro de commande';

  @override
  String get accountContinueButton => 'Continuer';

  @override
  String get accountOrDivider => 'Ou';

  @override
  String get accountLinkedCopyLead => 'Connectez-vous à votre compte ';

  @override
  String get accountBenefitOrderHistory =>
      'Suivre vos commandes\net l\'historique de vos\nachats';

  @override
  String get accountBenefitReturns => 'Demander un retour ou\nun échange';

  @override
  String get accountBenefitWishlist => 'Ajouter des articles à\nvotre wishlist';

  @override
  String get accountBenefitAdvisor => 'Contacter votre\nconseiller';

  @override
  String get accountBenefitManageAccount =>
      'Gérer les informations\nde votre compte et vos\nabonnements';

  @override
  String get pdpFoilTiltHint => 'Touchez l’image ou inclinez le téléphone';

  @override
  String get pdpFoilEnableMotionHint => 'Touchez pour activer le reflet';
}
