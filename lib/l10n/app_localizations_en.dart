// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Kiki\'s Commerce';

  @override
  String get commonClose => 'Close';

  @override
  String get commonContact => 'Contact';

  @override
  String get commonRetry => 'Try again';

  @override
  String get commonRouteNotFound => 'Page not found.';

  @override
  String get errorNetwork => 'Connection problem. Check your network.';

  @override
  String get errorServer => 'Server error. Please try again later.';

  @override
  String errorGeneric(String error) {
    return 'Error: $error';
  }

  @override
  String get languageLabel => 'Language';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageEnglish => 'English';

  @override
  String get navSearchHint => 'What are you looking for?';

  @override
  String get navSearchAction => 'Search';

  @override
  String get navWishlist => 'Favorites';

  @override
  String get navAccount => 'Account';

  @override
  String get navCart => 'Cart';

  @override
  String get navHome => 'Home';

  @override
  String get navSearch => 'Search';

  @override
  String get navProfile => 'Profile';

  @override
  String navCartItemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items in cart',
      one: '1 item in cart',
    );
    return '$_temp0';
  }

  @override
  String get navBackHome => 'Back to home';

  @override
  String get navOpenMenu => 'Open menu';

  @override
  String get navCloseMenu => 'Close menu';

  @override
  String get navCommercetoolsDemo => 'commercetools demo';

  @override
  String get navHighlights => 'Highlights';

  @override
  String get navNoActiveCategories => 'No active categories available.';

  @override
  String get navNoActiveNavigation => 'No active navigation available.';

  @override
  String navCategoriesLoadError(String error) {
    return 'Unable to load categories.\n$error';
  }

  @override
  String get sportSegmentMen => 'Men';

  @override
  String get sportSegmentWomen => 'Women';

  @override
  String get sportSegmentKids => 'Kids';

  @override
  String get cmsBrowse => 'Browse';

  @override
  String get cmsDiscover => 'Discover';

  @override
  String get cmsViewAll => 'View all';

  @override
  String get cmsShoes => 'Shoes';

  @override
  String get cmsClothing => 'Clothing';

  @override
  String get cmsAccessories => 'Accessories';

  @override
  String get cmsNikeTrendingNow => 'Trending now';

  @override
  String get cmsNikeChooseYourAdventure => 'Choose your adventure';

  @override
  String get cmsNikeSummerEssentials => 'Summer essentials';

  @override
  String get cmsNikeBallonDOrPack => 'Ballon d\'Or pack';

  @override
  String get cmsNikeIconicStyles => 'Iconic styles';

  @override
  String get cmsNikeOurBrands => 'Our brands';

  @override
  String get searchTitle => 'Search';

  @override
  String searchTitleWithQuery(String query) {
    return 'Results for \"$query\"';
  }

  @override
  String get searchPrompt => 'Enter a search term.';

  @override
  String get searchSuggestionsTitle => 'Top suggestions';

  @override
  String searchEmptyResults(String query) {
    return 'No results for \"$query\".';
  }

  @override
  String searchResultCountSuffix(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: ' products',
      one: ' product',
    );
    return '$_temp0';
  }

  @override
  String get searchSortNewest => 'Newest';

  @override
  String get searchSortNameAsc => 'Name A-Z';

  @override
  String get searchSortNameDesc => 'Name Z-A';

  @override
  String searchPagination(int current, int total) {
    return 'Page $current / $total';
  }

  @override
  String get homeCatalogLoadErrorTitle => 'We couldn\'t load the catalogue';

  @override
  String get homeCatalogLoadErrorMessage =>
      'The storefront needs an active category in PocketBase. Use the admin backoffice to import a demo CSV or check the API connection.';

  @override
  String get homeOpenBackoffice => 'Open backoffice';

  @override
  String get homeNoActiveCategoriesTitle => 'No active categories';

  @override
  String get homeNoActiveCategoriesMessage =>
      'Import a catalogue from the admin route to populate your PocketBase collections before opening the storefront.';

  @override
  String get homeImportData => 'Import data';

  @override
  String get homeCatalogUnavailableTitle => 'Catalogue temporarily unavailable';

  @override
  String get homeCatalogUnavailableMessage => 'Please try again in a moment.';

  @override
  String get homeEmptyPublicTitle => 'Coming soon';

  @override
  String get homeEmptyPublicMessage => 'New products are arriving very soon.';

  @override
  String get homeCategoryUnavailableTitle => 'Page unavailable';

  @override
  String get homeCategoryUnavailableMessage =>
      'This selection isn\'t available right now.';

  @override
  String get plpCatalogueFallbackTitle => 'Catalogue';

  @override
  String get plpFiltersComingSoon => 'Filters and sorting coming soon.';

  @override
  String get plpBackToPreviousLevel => 'Back to previous level';

  @override
  String plpProductsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '$count item',
    );
    return '$_temp0';
  }

  @override
  String get plpFilterAndSort => 'Filter and sort';

  @override
  String get productCardNewBadge => 'New';

  @override
  String get productCardLatestReleases => 'Latest releases';

  @override
  String get productCardFavoritesUnavailable => 'Favorites coming soon.';

  @override
  String get pdpPriceUnavailable => 'Price unavailable';

  @override
  String get pdpTabDescription => 'Description';

  @override
  String get pdpTabSizeAndFit => 'Size & fit';

  @override
  String get pdpTabSizeAndFitInfo => 'Size & Fit Information';

  @override
  String get pdpTabShippingAndReturns => 'Shipping & returns';

  @override
  String get pdpTabShippingAndReturnsLong => 'Shipping & Returns';

  @override
  String get pdpDescriptionEmpty => 'No detailed description is available yet.';

  @override
  String get pdpShowMore => 'Show more';

  @override
  String get pdpShowLess => 'Show less';

  @override
  String pdpSizingCategory(String type) {
    return 'Size and fit information tailored to the $type category.';
  }

  @override
  String pdpSizingSilhouette(String type) {
    return 'A cut designed for a $type silhouette.';
  }

  @override
  String pdpSizingBrandUniverse(String brand) {
    return 'Created within the $brand world with a deliberately clean line.';
  }

  @override
  String get pdpSizingDimensionsVary =>
      'Dimensions and weight may vary depending on the product\'s material.';

  @override
  String get pdpSizingSizeUpAdvice =>
      'If you\'re between two sizes, choose the larger one for a more relaxed fit.';

  @override
  String get pdpShippingReturnsTitle => 'Free returns and exchanges';

  @override
  String get pdpShippingReturnsBody =>
      'You may return or exchange any item ordered within 30 days of receipt, provided the product is returned in its original condition.';

  @override
  String get pdpShippingFaqHint => 'For more information, see our FAQ.';

  @override
  String get pdpShippingFreeTitle => 'Free shipping';

  @override
  String get pdpShippingFreeBody =>
      'Several fast, secure delivery options are offered based on your address and product availability. Delivery times are estimated from the moment your order ships.';

  @override
  String get pdpShippingDispatchTitle => 'Dispatched within 24h';

  @override
  String get pdpShippingDispatchBody =>
      'Orders placed before noon are prepared and shipped the same day, subject to stock availability.';

  @override
  String get pdpShippingSummary =>
      'Home delivery within 1 to 3 business days. Free in-store returns and exchanges. Click & Collect available depending on store stock.';

  @override
  String pdpChapterLabel(int position) {
    return 'Chapter $position';
  }

  @override
  String pdpProgressCount(int current, int total) {
    return '$current / $total';
  }

  @override
  String get pdpSizeGuideTitle => 'Size guide';

  @override
  String get pdpSizeGuideBody =>
      'Choose your usual size. If you\'re between two sizes, go for the larger one for a more fluid fit.';

  @override
  String get pdpMaterialDetailsTitle => 'Material details';

  @override
  String get pdpMaterialDetailsEmpty =>
      'No additional material details for this product.';

  @override
  String pdpReference(String code) {
    return 'Reference: $code';
  }

  @override
  String get pdpSelectYourSize => 'Select your size';

  @override
  String get pdpSizeGuideLink => 'Size guide';

  @override
  String get pdpAddToCart => 'Add to cart';

  @override
  String get pdpAddedToCart => 'Added';

  @override
  String get pdpAddToCartRetry => 'Failed, try again';

  @override
  String get pdpReserveInStore => 'Reserve in store';

  @override
  String get pdpCrossSellsTitle => 'You may also like';

  @override
  String get pdpRecentlyViewed => 'Recently viewed';

  @override
  String get pdpExpressCheckout => 'Express checkout';

  @override
  String get pdpCartMissingCurrency => 'Product currency is missing';

  @override
  String get pdpCartCurrencyMismatch =>
      'Different currency — create a separate cart';

  @override
  String get pdpCartAddFailed => 'Couldn\'t add to cart';

  @override
  String get pdpCartAddedSyncFailed =>
      'Product added, but the cart couldn\'t be synced';

  @override
  String get cartEditQuantityTitle => 'Edit quantity';

  @override
  String get cartQuantityTitle => 'Quantity';

  @override
  String cartQuantityLabelLong(int quantity) {
    return 'Qty: $quantity';
  }

  @override
  String cartQuantityLabelShort(int quantity) {
    return 'Qty $quantity';
  }

  @override
  String get cartRemoveItem => 'Remove item';

  @override
  String get cartUpdateQuantityError => 'Couldn\'t update the quantity.';

  @override
  String get cartRemoveItemError => 'Couldn\'t remove the item.';

  @override
  String get checkoutBack => 'Back';

  @override
  String get checkoutSignInTitle => 'Sign in';

  @override
  String get checkoutSignInSubtitle => 'Please sign in or continue as a guest';

  @override
  String get checkoutCartAlreadyLinked =>
      'This cart is already linked to a customer account.';

  @override
  String get checkoutSignInOptionSubtitle => 'Please sign in';

  @override
  String get checkoutCreateAccountTitle => 'Create an account';

  @override
  String get checkoutCreateAccountSubtitle => 'Don\'t have an account yet?';

  @override
  String get checkoutGuestTitle => 'Continue without creating an account';

  @override
  String get checkoutGuestSubtitle =>
      'Please enter your email address to place your order';

  @override
  String get checkoutEmailLabel => '* Email';

  @override
  String get checkoutPasswordLabel => '* Password';

  @override
  String get checkoutForgotPassword => 'Forgot your password?';

  @override
  String get checkoutOrContinueWith => 'Or continue with';

  @override
  String get checkoutPrivacyNotice => 'Privacy notice';

  @override
  String get checkoutContinue => 'Continue';

  @override
  String get checkoutEmailInvalid => 'Please enter a valid email address.';

  @override
  String get checkoutEmptyCartTitle => 'Your cart is empty.';

  @override
  String get checkoutEmptyCartSubtitle =>
      'Add a product before completing your order.';

  @override
  String get checkoutContinueShopping => 'Continue shopping';

  @override
  String get checkoutStepShippingAddress => '1. Shipping address';

  @override
  String get checkoutStepShippingMethod => '2. Shipping method';

  @override
  String get checkoutStepBillingPayment => '3. Billing and payment';

  @override
  String get checkoutEnterShippingAddress =>
      'Please enter your shipping address:';

  @override
  String get checkoutAddShippingAddress => 'Add a shipping address';

  @override
  String get checkoutEdit => 'Edit';

  @override
  String get checkoutDeliveryIdentityNotice =>
      'The customer\'s presence, signature, and a photo ID are required for delivery.';

  @override
  String get checkoutChooseShippingMethod => 'Choose shipping method';

  @override
  String checkoutEmailAddressLabel(String email) {
    return 'Email address: $email';
  }

  @override
  String get checkoutEditEmail => 'Edit email';

  @override
  String get checkoutOrderSummary => 'Order summary';

  @override
  String checkoutItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '$count item',
    );
    return '$_temp0';
  }

  @override
  String get checkoutPackagingTitle => 'Packaging and gifts';

  @override
  String get checkoutPackagingFreeOptions => 'Free options';

  @override
  String get checkoutPackagingNoPricesNote =>
      'Prices and invoices are not shipped with the products.';

  @override
  String checkoutPackagingSignatureTitle(String brand) {
    return '$brand signature packaging';
  }

  @override
  String checkoutPackagingSignatureSubtitle(String brand) {
    return '$brand\'s signature packaging is responsibly produced and certified to contain more than 90% recycled materials.';
  }

  @override
  String get checkoutPackagingEcoTitle => 'Eco Packaging';

  @override
  String checkoutAddShoppingBag(String brand) {
    return 'Add a $brand shopping bag';
  }

  @override
  String get checkoutGiftWrapTitle => 'Send as a gift';

  @override
  String get checkoutGiftWrapSubtitle => 'Personalize your gift for free';

  @override
  String get checkoutTotal => 'Total';

  @override
  String get checkoutSubtotal => 'Subtotal';

  @override
  String get checkoutShipping => 'Shipping';

  @override
  String get checkoutShippingEstimate => 'Estimated delivery date and costs';

  @override
  String get checkoutTaxesIncluded => 'Taxes included';

  @override
  String get checkoutOrPayWith => 'or pay with';

  @override
  String get checkoutHelpServices => 'Help & Services';

  @override
  String get checkoutServiceSecurePayment => '100% secure payment';

  @override
  String get checkoutServiceSecurePaymentBody =>
      'Your credit card details are safe with us. All information is protected by SSL (Secure Sockets Layer) technology.';

  @override
  String get checkoutServiceHelp => 'Need help?';

  @override
  String get checkoutServiceHelpBody =>
      'Our advisors assist with your order, personalization, and delivery tracking.';

  @override
  String get checkoutServiceFreeShipping => 'Free standard shipping';

  @override
  String get checkoutServiceFreeShippingBody =>
      'The delivery date and estimated costs are confirmed at the next step.';

  @override
  String get checkoutServiceReturns => 'Exchange and refund';

  @override
  String get checkoutServiceReturnsBody =>
      'Returns and refunds are handled according to the terms of sale applicable to the order.';

  @override
  String get checkoutFooterPersonalData => 'Personal data';

  @override
  String get checkoutFooterLegalNotice => 'Legal notice';

  @override
  String get accountBarrierLabel => 'Close account';

  @override
  String get accountSignInTitle => 'Sign in';

  @override
  String get accountSignInSubtitle => 'To access your account';

  @override
  String get accountSignInPending => 'Customer sign-in will be available soon.';

  @override
  String get accountRegisterTitle => 'Register';

  @override
  String get accountRegisterSubtitle => 'Don\'t have an account?';

  @override
  String get accountRegisterPending =>
      'Account creation will be available soon.';

  @override
  String get accountOrderTrackingTitle => 'Track your order';

  @override
  String get accountOrderTrackingSubtitle =>
      'Stay up to date with the latest updates on your order';

  @override
  String get accountOrderTrackingPending =>
      'Order tracking will be available soon.';

  @override
  String get accountToolbarSearch => 'Search';

  @override
  String get accountToolbarFavorites => 'Favorites';

  @override
  String get accountToolbarMyAccount => 'My account';

  @override
  String get accountToolbarCart => 'Cart';

  @override
  String get accountPrivacyNotice => 'Privacy notice';

  @override
  String get accountEmailLabel => '* Email';

  @override
  String get accountPasswordLabel => '* Password';

  @override
  String get accountForgotPassword => 'Forgot password?';

  @override
  String get accountSignInButton => 'Sign me in';

  @override
  String get accountCreateAccountButton => 'Create an account';

  @override
  String get accountOrderNumberLabel => '* Order number';

  @override
  String get accountContinueButton => 'Continue';

  @override
  String get accountOrDivider => 'Or';

  @override
  String get accountLinkedCopyLead => 'Sign in to your ';

  @override
  String get accountBenefitOrderHistory =>
      'Track your orders\nand your purchase\nhistory';

  @override
  String get accountBenefitReturns => 'Request a return or\nexchange';

  @override
  String get accountBenefitWishlist => 'Add items to\nyour wishlist';

  @override
  String get accountBenefitAdvisor => 'Contact your\nadvisor';

  @override
  String get accountBenefitManageAccount =>
      'Manage your account\ninformation and\nsubscriptions';

  @override
  String get pdpFoilTiltHint => 'Touch the image or tilt your phone';

  @override
  String get pdpFoilEnableMotionHint => 'Tap to activate the shine';
}
