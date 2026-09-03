import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/app_providers.dart';
import '../../app/catalog_routes.dart';
import '../../application/cart/cart_read_models.dart';
import '../../application/storefront/storefront_brand_settings.dart';
import '../../domain/cart/cart_entities.dart';
import '../l10n/l10n_extension.dart';
import '../providers/cart_provider.dart';
import 'checkout/checkout_access_widgets.dart';
import 'checkout/checkout_layout.dart';
import 'checkout/checkout_tokens.dart';

enum _CheckoutAccessOption { signIn, createAccount, guest }

enum _GuestCheckoutAddressOption { addNew, saved }

bool _isGuestCart(Cart cart) {
  final userId = cart.userId?.trim();
  return userId == null || userId.isEmpty;
}

bool _looksLikeEmail(String value) {
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());
}

void _showCheckoutMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class MobileCheckoutAccessPage extends ConsumerStatefulWidget {
  final String? initialEmail;

  const MobileCheckoutAccessPage({super.key, this.initialEmail});

  @override
  ConsumerState<MobileCheckoutAccessPage> createState() =>
      _MobileCheckoutAccessPageState();
}

class _MobileCheckoutAccessPageState
    extends ConsumerState<MobileCheckoutAccessPage> {
  final _emailController = TextEditingController();
  final _signInEmailController = TextEditingController();
  final _passwordController = TextEditingController();
  _CheckoutAccessOption? _selectedOption;
  bool _passwordObscured = true;
  String? _emailErrorText;

  bool get _canSubmitSignIn {
    return _looksLikeEmail(_signInEmailController.text) &&
        _passwordController.text.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    final initialEmail = widget.initialEmail?.trim();
    if (initialEmail != null && initialEmail.isNotEmpty) {
      _emailController.text = initialEmail;
      _selectedOption = _CheckoutAccessOption.guest;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(cartControllerProvider);
      if (!state.hasValue || state.value == null) {
        ref.read(cartControllerProvider.notifier).refresh();
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _signInEmailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartControllerProvider);
    final cartView = cartState.value;
    final signedInCart = cartView != null && !_isGuestCart(cartView.cart);

    return Scaffold(
      backgroundColor: kCheckoutBackground,
      body: SafeArea(
        child: CheckoutTextScope(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  CheckoutHeader(
                    onBack: () {
                      if (context.canPop()) {
                        context.pop();
                        return;
                      }
                      // Fall back to the cart so we don't bounce through
                      // the `/checkout` → `/checkout/access` redirect.
                      context.go(CatalogRoutes.cart);
                    },
                  ),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: kCheckoutCardBorder,
                  ),
                  Expanded(
                    child: cartView == null
                        ? _buildEmptyOrLoading(context, cartState)
                        : Column(
                            children: [
                              Expanded(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.only(bottom: 28),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Container(
                                        color: Colors.white,
                                        padding: const EdgeInsets.fromLTRB(
                                          24,
                                          42,
                                          24,
                                          44,
                                        ),
                                        child: Column(
                                          children: [
                                            Text(
                                              context.l10n.checkoutSignInTitle,
                                              style: checkoutSerif(
                                                fontSize: 23,
                                                fontWeight: FontWeight.w500,
                                                color: kCheckoutHeading,
                                                height: 1,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            const SizedBox(height: 13),
                                            Text(
                                              context
                                                  .l10n
                                                  .checkoutSignInSubtitle,
                                              style: checkoutSans(
                                                fontSize: 13.5,
                                                color: kCheckoutMuted,
                                                height: 1.45,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                            if (signedInCart) ...[
                                              const SizedBox(height: 14),
                                              Text(
                                                context
                                                    .l10n
                                                    .checkoutCartAlreadyLinked,
                                                style: checkoutSans(
                                                  fontSize: 13.5,
                                                  color: kCheckoutMuted,
                                                  height: 1.45,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const Divider(
                                        height: 1,
                                        thickness: 1,
                                        color: kCheckoutCardBorder,
                                      ),
                                      CheckoutAccessOptionTile(
                                        selected:
                                            _selectedOption ==
                                            _CheckoutAccessOption.signIn,
                                        title: context.l10n.checkoutSignInTitle,
                                        subtitle: context
                                            .l10n
                                            .checkoutSignInOptionSubtitle,
                                        onTap: () => _selectOption(
                                          _CheckoutAccessOption.signIn,
                                        ),
                                        child:
                                            _selectedOption ==
                                                _CheckoutAccessOption.signIn
                                            ? CheckoutSignInForm(
                                                emailController:
                                                    _signInEmailController,
                                                passwordController:
                                                    _passwordController,
                                                passwordObscured:
                                                    _passwordObscured,
                                                canSubmit: _canSubmitSignIn,
                                                onChanged: () =>
                                                    setState(() {}),
                                                onPasswordVisibilityToggle: () {
                                                  setState(() {
                                                    _passwordObscured =
                                                        !_passwordObscured;
                                                  });
                                                },
                                                onSubmit: () =>
                                                    _handleContinue(context),
                                              )
                                            : null,
                                      ),
                                      const Divider(
                                        height: 1,
                                        thickness: 1,
                                        color: kCheckoutCardBorder,
                                      ),
                                      CheckoutAccessOptionTile(
                                        selected:
                                            _selectedOption ==
                                            _CheckoutAccessOption.createAccount,
                                        title: context
                                            .l10n
                                            .checkoutCreateAccountTitle,
                                        subtitle: context
                                            .l10n
                                            .checkoutCreateAccountSubtitle,
                                        onTap: () => _selectOption(
                                          _CheckoutAccessOption.createAccount,
                                        ),
                                        child:
                                            _selectedOption ==
                                                _CheckoutAccessOption
                                                    .createAccount
                                            ? CheckoutAccessContinueButton(
                                                onPressed: () =>
                                                    _handleContinue(context),
                                              )
                                            : null,
                                      ),
                                      const Divider(
                                        height: 1,
                                        thickness: 1,
                                        color: kCheckoutCardBorder,
                                      ),
                                      CheckoutAccessOptionTile(
                                        selected:
                                            _selectedOption ==
                                            _CheckoutAccessOption.guest,
                                        title: context.l10n.checkoutGuestTitle,
                                        subtitle:
                                            context.l10n.checkoutGuestSubtitle,
                                        onTap: () => _selectOption(
                                          _CheckoutAccessOption.guest,
                                        ),
                                        child:
                                            _selectedOption ==
                                                _CheckoutAccessOption.guest
                                            ? Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.stretch,
                                                children: [
                                                  TextField(
                                                    controller:
                                                        _emailController,
                                                    keyboardType: TextInputType
                                                        .emailAddress,
                                                    textInputAction:
                                                        TextInputAction.done,
                                                    autofillHints: const [
                                                      AutofillHints.email,
                                                    ],
                                                    onChanged: (_) {
                                                      if (_emailErrorText !=
                                                          null) {
                                                        setState(
                                                          () =>
                                                              _emailErrorText =
                                                                  null,
                                                        );
                                                      }
                                                    },
                                                    onSubmitted: (_) =>
                                                        _handleContinue(
                                                          context,
                                                        ),
                                                    style: checkoutSans(
                                                      fontSize: 15.5,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: kCheckoutHeading,
                                                    ),
                                                    decoration: InputDecoration(
                                                      labelText: context
                                                          .l10n
                                                          .checkoutEmailLabel,
                                                      labelStyle: checkoutSans(
                                                        fontSize: 14.5,
                                                        color: kCheckoutMuted,
                                                      ),
                                                      floatingLabelStyle:
                                                          checkoutSans(
                                                            fontSize: 14.5,
                                                            color:
                                                                kCheckoutMuted,
                                                          ),
                                                      errorText:
                                                          _emailErrorText,
                                                      contentPadding:
                                                          const EdgeInsets.only(
                                                            top: 16,
                                                            bottom: 8,
                                                          ),
                                                      enabledBorder:
                                                          const UnderlineInputBorder(
                                                            borderSide:
                                                                BorderSide(
                                                                  color: Color(
                                                                    0xFF98938A,
                                                                  ),
                                                                ),
                                                          ),
                                                      focusedBorder:
                                                          const UnderlineInputBorder(
                                                            borderSide: BorderSide(
                                                              color:
                                                                  kCheckoutPrimary,
                                                              width: 1.4,
                                                            ),
                                                          ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 24),
                                                  CheckoutAccessContinueButton(
                                                    onPressed: () =>
                                                        _handleContinue(
                                                          context,
                                                        ),
                                                    expanded: true,
                                                  ),
                                                ],
                                              )
                                            : null,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const Divider(
                                height: 1,
                                thickness: 1,
                                color: kCheckoutCardBorder,
                              ),
                              const Padding(
                                padding: EdgeInsets.fromLTRB(20, 24, 20, 28),
                                child: CheckoutFooter(),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyOrLoading(
    BuildContext context,
    AsyncValue<CartView?> state,
  ) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            context.l10n.checkoutEmptyCartTitle,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 36,
              fontWeight: FontWeight.w500,
              color: kCheckoutHeading,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.checkoutEmptyCartSubtitle,
            style: const TextStyle(
              fontSize: 16,
              color: kCheckoutMuted,
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => context.go(
                CatalogRoutes.localizedLocation(
                  CatalogRoutes.catalogBase,
                  locale: Localizations.localeOf(context).languageCode,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: kCheckoutPrimary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(context.l10n.checkoutContinueShopping),
            ),
          ),
        ],
      ),
    );
  }

  void _selectOption(_CheckoutAccessOption option) {
    setState(() {
      _selectedOption = option;
      _emailErrorText = null;
    });
  }

  void _handleContinue(BuildContext context) {
    final selectedOption = _selectedOption;
    if (selectedOption == null) {
      return;
    }

    switch (selectedOption) {
      case _CheckoutAccessOption.signIn:
        if (!_canSubmitSignIn) {
          return;
        }
        _showCheckoutMessage(
          context,
          'La connexion client sera branchée à la prochaine étape.',
        );
        return;
      case _CheckoutAccessOption.createAccount:
        _showCheckoutMessage(
          context,
          'La création de compte sera branchée à la prochaine étape.',
        );
        return;
      case _CheckoutAccessOption.guest:
        final email = _emailController.text.trim();
        if (!_looksLikeEmail(email)) {
          setState(() => _emailErrorText = context.l10n.checkoutEmailInvalid);
          return;
        }
        context.push(CatalogRoutes.checkoutGuestAddressLocation(email: email));
        return;
    }
  }
}

class MobileGuestCheckoutAddressPage extends ConsumerStatefulWidget {
  final String email;

  const MobileGuestCheckoutAddressPage({super.key, required this.email});

  @override
  ConsumerState<MobileGuestCheckoutAddressPage> createState() =>
      _MobileGuestCheckoutAddressPageState();
}

class _MobileGuestCheckoutAddressPageState
    extends ConsumerState<MobileGuestCheckoutAddressPage> {
  _GuestCheckoutAddressOption _selectedAddress =
      _GuestCheckoutAddressOption.saved;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(cartControllerProvider);
      if (!state.hasValue || state.value == null) {
        ref.read(cartControllerProvider.notifier).refresh();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cartState = ref.watch(cartControllerProvider);
    final cartView = cartState.value;
    final brandName = ref.watch(
      storefrontBrandSettingsProvider.select(
        (async) => async.value?.title ?? defaultStorefrontBrandTitle,
      ),
    );

    return Scaffold(
      backgroundColor: kCheckoutBackground,
      body: SafeArea(
        child: CheckoutTextScope(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                children: [
                  CheckoutHeader(
                    onBack: () {
                      if (context.canPop()) {
                        context.pop();
                        return;
                      }
                      context.go(
                        CatalogRoutes.checkoutAccessLocation(
                          email: widget.email,
                        ),
                      );
                    },
                  ),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: kCheckoutCardBorder,
                  ),
                  Expanded(
                    child: cartView == null
                        ? _buildEmptyOrLoading(context, cartState)
                        : SingleChildScrollView(
                            padding: const EdgeInsets.only(bottom: 32),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                CheckoutGuestEmailBanner(
                                  email: widget.email,
                                  onEditEmail: () => _handleEditEmail(context),
                                ),
                                const Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: kCheckoutCardBorder,
                                ),
                                Container(
                                  color: Colors.white,
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    58,
                                    20,
                                    64,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        context
                                            .l10n
                                            .checkoutStepShippingAddress,
                                        style: GoogleFonts.cormorantGaramond(
                                          fontSize: 34,
                                          fontWeight: FontWeight.w500,
                                          color: kCheckoutHeading,
                                          height: 1,
                                        ),
                                      ),
                                      const SizedBox(height: 26),
                                      Text(
                                        context
                                            .l10n
                                            .checkoutEnterShippingAddress,
                                        style: const TextStyle(
                                          fontSize: 17,
                                          color: kCheckoutHeading,
                                          height: 1.4,
                                        ),
                                      ),
                                      const SizedBox(height: 32),
                                      CheckoutAddressOptionCard(
                                        selected:
                                            _selectedAddress ==
                                            _GuestCheckoutAddressOption.addNew,
                                        title: context
                                            .l10n
                                            .checkoutAddShippingAddress,
                                        onTap: () {
                                          setState(() {
                                            _selectedAddress =
                                                _GuestCheckoutAddressOption
                                                    .addNew;
                                          });
                                        },
                                      ),
                                      const SizedBox(height: 34),
                                      CheckoutAddressOptionCard(
                                        selected:
                                            _selectedAddress ==
                                            _GuestCheckoutAddressOption.saved,
                                        title: '$brandName Cannes',
                                        detailLines: const [
                                          '7 Boulevard De La Croisette',
                                          '06400 Cannes',
                                        ],
                                        actionLabel: context.l10n.checkoutEdit,
                                        onTap: () {
                                          setState(() {
                                            _selectedAddress =
                                                _GuestCheckoutAddressOption
                                                    .saved;
                                          });
                                        },
                                        onActionTap: () => _showCheckoutMessage(
                                          context,
                                          'La modification de l’adresse sera branchée à la prochaine étape.',
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                      Text(
                                        context
                                            .l10n
                                            .checkoutDeliveryIdentityNotice,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          color: kCheckoutMuted,
                                          height: 1.5,
                                        ),
                                      ),
                                      const SizedBox(height: 46),
                                      SizedBox(
                                        width: double.infinity,
                                        height: 56,
                                        child: FilledButton(
                                          onPressed: () => _showCheckoutMessage(
                                            context,
                                            _selectedAddress ==
                                                    _GuestCheckoutAddressOption
                                                        .addNew
                                                ? 'Le formulaire d’adresse sera branché à la prochaine étape.'
                                                : 'Le choix du mode de livraison sera branché à la prochaine étape.',
                                          ),
                                          style: FilledButton.styleFrom(
                                            backgroundColor: kCheckoutPrimary,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          child: Text(
                                            context
                                                .l10n
                                                .checkoutChooseShippingMethod,
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: kCheckoutCardBorder,
                                ),
                                CheckoutStepPlaceholder(
                                  title:
                                      context.l10n.checkoutStepShippingMethod,
                                ),
                                const Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: kCheckoutCardBorder,
                                ),
                                CheckoutStepPlaceholder(
                                  title:
                                      context.l10n.checkoutStepBillingPayment,
                                ),
                              ],
                            ),
                          ),
                  ),
                  const Divider(
                    height: 1,
                    thickness: 1,
                    color: kCheckoutCardBorder,
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 24, 20, 28),
                    child: CheckoutFooter(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyOrLoading(
    BuildContext context,
    AsyncValue<CartView?> state,
  ) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            context.l10n.checkoutEmptyCartTitle,
            style: GoogleFonts.cormorantGaramond(
              fontSize: 36,
              fontWeight: FontWeight.w500,
              color: kCheckoutHeading,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.checkoutEmptyCartSubtitle,
            style: const TextStyle(
              fontSize: 16,
              color: kCheckoutMuted,
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => context.go(
                CatalogRoutes.localizedLocation(
                  CatalogRoutes.catalogBase,
                  locale: Localizations.localeOf(context).languageCode,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: kCheckoutPrimary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(context.l10n.checkoutContinueShopping),
            ),
          ),
        ],
      ),
    );
  }

  void _handleEditEmail(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(CatalogRoutes.checkoutAccessLocation(email: widget.email));
  }
}
