import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n_extension.dart';
import '../providers/cart_provider.dart';

const _kAccountInk = Color(0xFF2F2F2C);
const _kAccountMuted = Color(0xFF7B7F82);
const _kAccountLine = Color(0xFFE6E3DD);
const _kAccountFieldLine = Color(0xFF98938A);
const _kAccountDisabled = Color(0xFFE4E4E2);
const _kAccountDisabledText = Color(0xFFB3B9BC);

class _AccountType {
  static double sectionTitle(bool compact) => compact ? 15 : 16;
  static double supporting(bool compact) => compact ? 13.5 : 14.5;
  static double field(bool compact) => compact ? 15 : 15.5;
  static double button(bool compact) => compact ? 15 : 15.5;
}

Future<void> showCustomerAccountModal(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: context.l10n.accountBarrierLabel,
    barrierColor: Colors.black.withValues(alpha: 0.56),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (context, _, _) => const _CustomerAccountModal(),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.985, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

enum _AccountPanel { signIn, register, orderTracking }

class _CustomerAccountModal extends ConsumerStatefulWidget {
  const _CustomerAccountModal();

  @override
  ConsumerState<_CustomerAccountModal> createState() =>
      _CustomerAccountModalState();
}

class _CustomerAccountModalState extends ConsumerState<_CustomerAccountModal> {
  final _scrollController = ScrollController();
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _orderEmailController = TextEditingController();
  final _orderNumberController = TextEditingController();

  _AccountPanel? _openPanel;
  bool _passwordVisible = false;

  @override
  void initState() {
    super.initState();
    _loginEmailController.addListener(_handleFormChange);
    _loginPasswordController.addListener(_handleFormChange);
    _orderEmailController.addListener(_handleFormChange);
    _orderNumberController.addListener(_handleFormChange);
  }

  @override
  void dispose() {
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _orderEmailController.dispose();
    _orderNumberController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleFormChange() {
    if (mounted) {
      setState(() {});
    }
  }

  bool get _canSignIn {
    return _looksLikeEmail(_loginEmailController.text) &&
        _loginPasswordController.text.trim().isNotEmpty;
  }

  bool get _canTrackOrder {
    return _looksLikeEmail(_orderEmailController.text) &&
        _orderNumberController.text.trim().isNotEmpty;
  }

  void _togglePanel(_AccountPanel panel) {
    setState(() {
      _openPanel = _openPanel == panel ? null : panel;
    });
  }

  void _showPendingMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final safePadding = MediaQuery.paddingOf(context);
    final isCompact = size.width < 700;
    final horizontalMargin = isCompact ? 16.0 : 32.0;
    final topMargin = isCompact ? 39.0 : 44.0;
    final bottomMargin = isCompact ? 16.0 : 32.0;
    final panelWidth = isCompact ? size.width - (horizontalMargin * 2) : 560.0;
    final panelHeight =
        size.height -
        safePadding.top -
        safePadding.bottom -
        topMargin -
        bottomMargin;
    final contentPadding = isCompact ? 24.0 : 34.0;
    final cartCount = ref.watch(cartItemCountProvider);
    final typeScale = _AccountTypeScale(isCompact);

    return SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalMargin,
            topMargin,
            horizontalMargin,
            bottomMargin,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: panelWidth,
              maxHeight: panelHeight.clamp(360.0, size.height),
            ),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(6),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _AccountModalToolbar(cartCount: cartCount),
                  Expanded(
                    child: Scrollbar(
                      controller: _scrollController,
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        padding: EdgeInsets.symmetric(
                          horizontal: contentPadding,
                        ),
                        child: Column(
                          children: [
                            _AccountAccordionSection(
                              title: context.l10n.accountSignInTitle,
                              subtitle: context.l10n.accountSignInSubtitle,
                              typeScale: typeScale,
                              expanded: _openPanel == _AccountPanel.signIn,
                              onTap: () => _togglePanel(_AccountPanel.signIn),
                              child: _SignInPanel(
                                typeScale: typeScale,
                                emailController: _loginEmailController,
                                passwordController: _loginPasswordController,
                                passwordVisible: _passwordVisible,
                                canSubmit: _canSignIn,
                                onPasswordVisibilityToggle: () {
                                  setState(() {
                                    _passwordVisible = !_passwordVisible;
                                  });
                                },
                                onSubmit: () => _showPendingMessage(
                                  context.l10n.accountSignInPending,
                                ),
                              ),
                            ),
                            _AccountAccordionSection(
                              title: context.l10n.accountRegisterTitle,
                              subtitle: context.l10n.accountRegisterSubtitle,
                              typeScale: typeScale,
                              expanded: _openPanel == _AccountPanel.register,
                              onTap: () => _togglePanel(_AccountPanel.register),
                              child: _RegisterPanel(
                                typeScale: typeScale,
                                onCreateAccount: () => _showPendingMessage(
                                  context.l10n.accountRegisterPending,
                                ),
                              ),
                            ),
                            _AccountAccordionSection(
                              title: context.l10n.accountOrderTrackingTitle,
                              subtitle:
                                  context.l10n.accountOrderTrackingSubtitle,
                              typeScale: typeScale,
                              expanded:
                                  _openPanel == _AccountPanel.orderTracking,
                              onTap: () =>
                                  _togglePanel(_AccountPanel.orderTracking),
                              child: _OrderTrackingPanel(
                                typeScale: typeScale,
                                emailController: _orderEmailController,
                                orderNumberController: _orderNumberController,
                                canSubmit: _canTrackOrder,
                                onSubmit: () => _showPendingMessage(
                                  context.l10n.accountOrderTrackingPending,
                                ),
                              ),
                            ),
                            SizedBox(height: isCompact ? 180 : 96),
                          ],
                        ),
                      ),
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
}

class _AccountTypeScale {
  final bool compact;

  const _AccountTypeScale(this.compact);

  double get sectionTitle => _AccountType.sectionTitle(compact);
  double get supporting => _AccountType.supporting(compact);
  double get field => _AccountType.field(compact);
  double get button => _AccountType.button(compact);
}

class _AccountModalToolbar extends StatelessWidget {
  final int cartCount;

  const _AccountModalToolbar({required this.cartCount});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 18, 28, 0),
      child: Column(
        children: [
          Row(
            children: [
              _ToolbarIconButton(
                icon: Icons.close,
                semanticLabel: context.l10n.commonClose,
                iconColor: const Color(0xFF686866),
                onPressed: () =>
                    Navigator.of(context, rootNavigator: true).pop(),
              ),
              const Spacer(),
              _ToolbarIconButton(
                icon: Icons.search,
                semanticLabel: context.l10n.accountToolbarSearch,
              ),
              const SizedBox(width: 4),
              _ToolbarIconButton(
                icon: Icons.favorite_border,
                semanticLabel: context.l10n.accountToolbarFavorites,
              ),
              const SizedBox(width: 4),
              _ToolbarIconButton(
                icon: Icons.person_outline,
                semanticLabel: context.l10n.accountToolbarMyAccount,
              ),
              const SizedBox(width: 4),
              _ToolbarIconButton(
                icon: Icons.shopping_bag_outlined,
                semanticLabel: context.l10n.accountToolbarCart,
                badgeLabel: cartCount > 0 ? cartCount.toString() : null,
              ),
            ],
          ),
          const SizedBox(height: 17),
          Stack(
            clipBehavior: Clip.none,
            children: [
              const Divider(height: 1, thickness: 1, color: _kAccountLine),
              Align(
                alignment: const Alignment(0.68, 0),
                child: Container(width: 46, height: 2, color: _kAccountInk),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  final IconData icon;
  final String semanticLabel;
  final String? badgeLabel;
  final Color iconColor;
  final VoidCallback? onPressed;

  const _ToolbarIconButton({
    required this.icon,
    required this.semanticLabel,
    this.badgeLabel,
    this.iconColor = _kAccountInk,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 40,
      child: IconButton(
        onPressed: onPressed ?? () {},
        tooltip: semanticLabel,
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        icon: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Icon(icon, size: 26, color: iconColor),
            if (badgeLabel case final label?)
              Positioned(
                right: 3,
                bottom: 3,
                child: Text(
                  label,
                  style: const TextStyle(
                    color: _kAccountInk,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AccountAccordionSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final _AccountTypeScale typeScale;
  final bool expanded;
  final VoidCallback onTap;
  final Widget child;

  const _AccountAccordionSection({
    required this.title,
    required this.subtitle,
    required this.typeScale,
    required this.expanded,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _kAccountLine)),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 34, 0, 32),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color: _kAccountInk,
                            fontSize: typeScale.sectionTitle,
                            fontWeight: FontWeight.w500,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: _kAccountMuted,
                            fontSize: typeScale.supporting,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 18),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Icon(
                      expanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: _kAccountInk,
                      size: 34,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 34),
                    child: child,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _SignInPanel extends StatelessWidget {
  final _AccountTypeScale typeScale;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool passwordVisible;
  final bool canSubmit;
  final VoidCallback onPasswordVisibilityToggle;
  final VoidCallback onSubmit;

  const _SignInPanel({
    required this.typeScale,
    required this.emailController,
    required this.passwordController,
    required this.passwordVisible,
    required this.canSubmit,
    required this.onPasswordVisibilityToggle,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SocialButton(
          icon: const _GoogleMark(),
          label: 'Google',
          onPressed: () {},
        ),
        const SizedBox(height: 12),
        _SocialButton(
          icon: const _FacebookMark(),
          label: 'Facebook',
          onPressed: () {},
        ),
        const SizedBox(height: 28),
        Center(
          child: _UnderlinedTextButton(
            label: context.l10n.accountPrivacyNotice,
          ),
        ),
        const SizedBox(height: 30),
        const _OrDivider(),
        const SizedBox(height: 30),
        _AccountTextField(
          controller: emailController,
          typeScale: typeScale,
          label: context.l10n.accountEmailLabel,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
        ),
        const SizedBox(height: 26),
        _AccountTextField(
          controller: passwordController,
          typeScale: typeScale,
          label: context.l10n.accountPasswordLabel,
          obscureText: !passwordVisible,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          suffix: IconButton(
            onPressed: onPasswordVisibilityToggle,
            icon: Icon(
              passwordVisible
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: _kAccountMuted,
              size: 28,
            ),
          ),
          onSubmitted: canSubmit ? onSubmit : null,
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: _UnderlinedTextButton(
            label: context.l10n.accountForgotPassword,
          ),
        ),
        const SizedBox(height: 28),
        _AccountPrimaryButton(
          label: context.l10n.accountSignInButton,
          typeScale: typeScale,
          enabled: canSubmit,
          onPressed: onSubmit,
        ),
        const SizedBox(height: 54),
        const _LinkedAccountCopy(),
      ],
    );
  }
}

class _RegisterPanel extends StatelessWidget {
  final _AccountTypeScale typeScale;
  final VoidCallback onCreateAccount;

  const _RegisterPanel({
    required this.typeScale,
    required this.onCreateAccount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AccountPrimaryButton(
          label: context.l10n.accountCreateAccountButton,
          typeScale: typeScale,
          enabled: true,
          onPressed: onCreateAccount,
        ),
        const SizedBox(height: 34),
        _BenefitGrid(typeScale: typeScale),
      ],
    );
  }
}

class _OrderTrackingPanel extends StatelessWidget {
  final _AccountTypeScale typeScale;
  final TextEditingController emailController;
  final TextEditingController orderNumberController;
  final bool canSubmit;
  final VoidCallback onSubmit;

  const _OrderTrackingPanel({
    required this.typeScale,
    required this.emailController,
    required this.orderNumberController,
    required this.canSubmit,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AccountTextField(
          controller: emailController,
          typeScale: typeScale,
          label: context.l10n.accountEmailLabel,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
        ),
        const SizedBox(height: 30),
        _AccountTextField(
          controller: orderNumberController,
          typeScale: typeScale,
          label: context.l10n.accountOrderNumberLabel,
          textInputAction: TextInputAction.done,
          onSubmitted: canSubmit ? onSubmit : null,
        ),
        const SizedBox(height: 36),
        _AccountPrimaryButton(
          label: context.l10n.accountContinueButton,
          typeScale: typeScale,
          enabled: canSubmit,
          onPressed: onSubmit,
        ),
      ],
    );
  }
}

class _AccountTextField extends StatelessWidget {
  final TextEditingController controller;
  final _AccountTypeScale typeScale;
  final String label;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final Widget? suffix;
  final VoidCallback? onSubmitted;

  const _AccountTextField({
    required this.controller,
    required this.typeScale,
    required this.label,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.suffix,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      onSubmitted: (_) => onSubmitted?.call(),
      style: TextStyle(
        color: _kAccountInk,
        fontSize: typeScale.field,
        fontWeight: FontWeight.w400,
        height: 1.2,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: _kAccountInk,
          fontSize: typeScale.field,
          fontWeight: FontWeight.w400,
        ),
        floatingLabelStyle: TextStyle(
          color: _kAccountInk,
          fontSize: typeScale.supporting,
          fontWeight: FontWeight.w400,
        ),
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.only(top: 12, bottom: 12),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: _kAccountFieldLine, width: 1.4),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: _kAccountInk, width: 1.6),
        ),
      ),
    );
  }
}

class _AccountPrimaryButton extends StatelessWidget {
  final String label;
  final _AccountTypeScale typeScale;
  final bool enabled;
  final VoidCallback onPressed;

  const _AccountPrimaryButton({
    required this.label,
    required this.typeScale,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: _kAccountInk,
          disabledBackgroundColor: _kAccountDisabled,
          foregroundColor: Colors.white,
          disabledForegroundColor: _kAccountDisabledText,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: TextStyle(
            fontSize: typeScale.button,
            fontWeight: FontWeight.w500,
            height: 1,
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback onPressed;

  const _SocialButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: _kAccountInk,
          side: const BorderSide(color: _kAccountLine, width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            height: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [icon, const SizedBox(width: 18), Text(label)],
        ),
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 20,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / 120;
    canvas.save();
    canvas.scale(scale);

    canvas.drawPath(
      Path()
        ..moveTo(117.6, 61.3636364)
        ..cubicTo(
          117.6,
          57.1090909,
          117.218182,
          53.0181818,
          116.509091,
          49.0909091,
        )
        ..lineTo(60, 49.0909091)
        ..lineTo(60, 72.3)
        ..lineTo(92.2909091, 72.3)
        ..cubicTo(90.9, 79.8, 86.6727273, 86.1545455, 80.3181818, 90.4090909)
        ..lineTo(80.3181818, 105.463636)
        ..lineTo(99.7090909, 105.463636)
        ..cubicTo(111.054545, 95.0181818, 117.6, 79.6363636, 117.6, 61.3636364)
        ..close(),
      Paint()..color = const Color(0xFF4285F4),
    );
    canvas.drawPath(
      Path()
        ..moveTo(60, 120)
        ..cubicTo(76.2, 120, 89.7818182, 114.627273, 99.7090909, 105.463636)
        ..lineTo(80.3181818, 90.4090909)
        ..cubicTo(
          74.9454545,
          94.0090909,
          68.0727273,
          96.1363636,
          60,
          96.1363636,
        )
        ..cubicTo(
          44.3727273,
          96.1363636,
          31.1454545,
          85.5818182,
          26.4272727,
          71.4,
        )
        ..lineTo(6.38181818, 71.4)
        ..lineTo(6.38181818, 86.9454545)
        ..cubicTo(16.2545455, 106.554545, 36.5454545, 120, 60, 120)
        ..close(),
      Paint()..color = const Color(0xFF34A853),
    );
    canvas.drawPath(
      Path()
        ..moveTo(26.4272727, 71.4)
        ..cubicTo(25.2272727, 67.8, 24.5454545, 63.9545455, 24.5454545, 60)
        ..cubicTo(24.5454545, 56.0454545, 25.2272727, 52.2, 26.4272727, 48.6)
        ..lineTo(26.4272727, 33.0545455)
        ..lineTo(6.38181818, 33.0545455)
        ..cubicTo(2.31818182, 41.1545455, 0, 50.3181818, 0, 60)
        ..cubicTo(0, 69.6818182, 2.31818182, 78.8454545, 6.38181818, 86.9454545)
        ..lineTo(26.4272727, 71.4)
        ..close(),
      Paint()..color = const Color(0xFFFBBC05),
    );
    canvas.drawPath(
      Path()
        ..moveTo(60, 23.8636364)
        ..cubicTo(
          68.8090909,
          23.8636364,
          76.7181818,
          26.8909091,
          82.9363636,
          32.8363636,
        )
        ..lineTo(100.145455, 15.6272727)
        ..cubicTo(89.7545455, 5.94545455, 76.1727273, 0, 60, 0)
        ..cubicTo(36.5454545, 0, 16.2545455, 13.4454545, 6.38181818, 33.0545455)
        ..lineTo(26.4272727, 48.6)
        ..cubicTo(
          31.1454545,
          34.4181818,
          44.3727273,
          23.8636364,
          60,
          23.8636364,
        )
        ..close(),
      Paint()..color = const Color(0xFFEA4335),
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GoogleLogoPainter oldDelegate) => false;
}

class _FacebookMark extends StatelessWidget {
  const _FacebookMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: const BoxDecoration(
        color: Color(0xFF1877F2),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Text(
        'f',
        style: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w800,
          height: 0.95,
        ),
      ),
    );
  }
}

class _UnderlinedTextButton extends StatelessWidget {
  final String label;

  const _UnderlinedTextButton({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: _kAccountInk,
        fontSize: 14,
        height: 1.2,
        decoration: TextDecoration.underline,
        decorationColor: _kAccountInk,
        decorationThickness: 1.2,
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: _kAccountLine, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            context.l10n.accountOrDivider,
            style: const TextStyle(
              color: _kAccountMuted,
              fontSize: 18,
              height: 1,
            ),
          ),
        ),
        const Expanded(child: Divider(color: _kAccountLine, thickness: 1)),
      ],
    );
  }
}

class _LinkedAccountCopy extends StatelessWidget {
  const _LinkedAccountCopy();

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        text: context.l10n.accountLinkedCopyLead,
        children: const [
          TextSpan(
            text: "Kiki's Commerce.",
            style: TextStyle(
              decoration: TextDecoration.underline,
              decorationColor: _kAccountMuted,
              decorationThickness: 1.2,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: _kAccountMuted,
        fontSize: 14.5,
        height: 1.5,
      ),
    );
  }
}

class _BenefitGrid extends StatelessWidget {
  final _AccountTypeScale typeScale;

  const _BenefitGrid({required this.typeScale});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _BenefitItem(
                icon: Icons.location_on_outlined,
                label: context.l10n.accountBenefitOrderHistory,
                typeScale: typeScale,
              ),
            ),
            const SizedBox(width: 26),
            Expanded(
              child: _BenefitItem(
                icon: Icons.assignment_return_outlined,
                label: context.l10n.accountBenefitReturns,
                typeScale: typeScale,
              ),
            ),
          ],
        ),
        const SizedBox(height: 44),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _BenefitItem(
                icon: Icons.favorite_border,
                label: context.l10n.accountBenefitWishlist,
                typeScale: typeScale,
              ),
            ),
            const SizedBox(width: 26),
            Expanded(
              child: _BenefitItem(
                icon: Icons.chat_bubble_outline,
                label: context.l10n.accountBenefitAdvisor,
                typeScale: typeScale,
              ),
            ),
          ],
        ),
        const SizedBox(height: 44),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 54),
          child: _BenefitItem(
            icon: Icons.person_outline,
            label: context.l10n.accountBenefitManageAccount,
            typeScale: typeScale,
          ),
        ),
      ],
    );
  }
}

class _BenefitItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final _AccountTypeScale typeScale;

  const _BenefitItem({
    required this.icon,
    required this.label,
    required this.typeScale,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: _kAccountInk, size: 30),
        const SizedBox(height: 14),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _kAccountMuted,
            fontSize: typeScale.supporting,
            height: 1.45,
          ),
        ),
      ],
    );
  }
}

bool _looksLikeEmail(String value) {
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value.trim());
}
