import 'package:flutter/material.dart';

import '../../l10n/l10n_extension.dart';
import 'checkout_packaging.dart';
import 'checkout_tokens.dart';

class CheckoutAddressOptionCard extends StatelessWidget {
  final bool selected;
  final String title;
  final List<String> detailLines;
  final String? actionLabel;
  final VoidCallback onTap;
  final VoidCallback? onActionTap;

  const CheckoutAddressOptionCard({
    super.key,
    required this.selected,
    required this.title,
    required this.onTap,
    this.detailLines = const [],
    this.actionLabel,
    this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? const Color(0xFFD9D4CB) : kCheckoutCardBorder,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 26),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: RadioDot(selected: selected),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: kCheckoutHeading,
                                height: 1.35,
                              ),
                            ),
                          ),
                          if (actionLabel case final label?) ...[
                            const SizedBox(width: 16),
                            TextButton(
                              onPressed: onActionTap ?? onTap,
                              style: TextButton.styleFrom(
                                minimumSize: Size.zero,
                                padding: EdgeInsets.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                label,
                                style: const TextStyle(
                                  fontSize: 16,
                                  color: kCheckoutHeading,
                                  decoration: TextDecoration.underline,
                                  decorationColor: kCheckoutHeading,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (detailLines.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        for (final line in detailLines)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              line,
                              style: const TextStyle(
                                fontSize: 17,
                                color: kCheckoutMuted,
                                height: 1.35,
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CheckoutAccessOptionTile extends StatelessWidget {
  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? child;

  const CheckoutAccessOptionTile({
    super.key,
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: RadioDot(selected: selected),
                  ),
                  const SizedBox(width: 17),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: checkoutSans(
                            fontSize: 14.5,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: kCheckoutHeading,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          subtitle,
                          style: checkoutSans(
                            fontSize: 12.5,
                            color: kCheckoutMuted,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (child case final content?) ...[
                const SizedBox(height: 48),
                content,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class CheckoutSignInForm extends StatelessWidget {
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool passwordObscured;
  final bool canSubmit;
  final VoidCallback onChanged;
  final VoidCallback onPasswordVisibilityToggle;
  final VoidCallback onSubmit;

  const CheckoutSignInForm({
    super.key,
    required this.emailController,
    required this.passwordController,
    required this.passwordObscured,
    required this.canSubmit,
    required this.onChanged,
    required this.onPasswordVisibilityToggle,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CheckoutAccessTextField(
          controller: emailController,
          label: context.l10n.checkoutEmailLabel,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          onChanged: onChanged,
        ),
        const SizedBox(height: 38),
        _CheckoutAccessTextField(
          controller: passwordController,
          label: context.l10n.checkoutPasswordLabel,
          obscureText: passwordObscured,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          onChanged: onChanged,
          onSubmitted: canSubmit ? onSubmit : null,
          suffix: IconButton(
            onPressed: onPasswordVisibilityToggle,
            icon: Icon(
              passwordObscured
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: kCheckoutMuted,
              size: 22,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          ),
        ),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerLeft,
          child: _CheckoutUnderlinedText(
            label: context.l10n.checkoutForgotPassword,
            color: kCheckoutMuted,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 28),
        CheckoutAccessContinueButton(
          onPressed: onSubmit,
          enabled: canSubmit,
          expanded: true,
        ),
        const SizedBox(height: 34),
        _CheckoutAccessDivider(label: context.l10n.checkoutOrContinueWith),
        const SizedBox(height: 28),
        _CheckoutSocialButton(
          icon: const _CheckoutGoogleMark(),
          label: 'Google',
          onPressed: () {},
        ),
        const SizedBox(height: 10),
        _CheckoutSocialButton(
          icon: const _CheckoutFacebookMark(),
          label: 'Facebook',
          onPressed: () {},
        ),
        const SizedBox(height: 26),
        Center(
          child: _CheckoutUnderlinedText(
            label: context.l10n.checkoutPrivacyNotice,
            color: kCheckoutHeading,
            fontSize: 12.5,
          ),
        ),
      ],
    );
  }
}

class _CheckoutAccessTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final Widget? suffix;
  final VoidCallback? onChanged;
  final VoidCallback? onSubmitted;

  const _CheckoutAccessTextField({
    required this.controller,
    required this.label,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.suffix,
    this.onChanged,
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
      onChanged: (_) => onChanged?.call(),
      onSubmitted: (_) => onSubmitted?.call(),
      style: checkoutSans(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: kCheckoutHeading,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: checkoutSans(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: kCheckoutHeading,
        ),
        floatingLabelStyle: checkoutSans(
          fontSize: 12.5,
          color: kCheckoutHeading,
        ),
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.only(top: 12, bottom: 12),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: Color(0xFF7E7E7E), width: 1),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: kCheckoutHeading, width: 1.2),
        ),
      ),
    );
  }
}

class CheckoutAccessContinueButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool enabled;
  final bool expanded;

  const CheckoutAccessContinueButton({
    super.key,
    required this.onPressed,
    this.enabled = true,
    this.expanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: expanded ? double.infinity : 124,
      height: 48,
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          backgroundColor: kCheckoutPrimary,
          disabledBackgroundColor: const Color(0xFFE4E4E4),
          foregroundColor: Colors.white,
          disabledForegroundColor: const Color(0xFFA6ADB2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kCheckoutCardRadius),
          ),
        ),
        child: Text(
          context.l10n.checkoutContinue,
          style: checkoutSans(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: enabled ? Colors.white : const Color(0xFFA6ADB2),
          ),
        ),
      ),
    );
  }
}

class _CheckoutAccessDivider extends StatelessWidget {
  final String label;

  const _CheckoutAccessDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Divider(color: kCheckoutCardBorder, thickness: 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            label,
            style: checkoutSans(fontSize: 12.5, color: kCheckoutHeading),
          ),
        ),
        const Expanded(
          child: Divider(color: kCheckoutCardBorder, thickness: 1),
        ),
      ],
    );
  }
}

class _CheckoutSocialButton extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback onPressed;

  const _CheckoutSocialButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: kCheckoutHeading,
          side: const BorderSide(color: kCheckoutCardBorder, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kCheckoutCardRadius),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 12),
            Text(
              label,
              style: checkoutSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: kCheckoutHeading,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckoutUnderlinedText extends StatelessWidget {
  final String label;
  final Color color;
  final double fontSize;

  const _CheckoutUnderlinedText({
    required this.label,
    required this.color,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: checkoutSans(
        fontSize: fontSize,
        color: color,
        decoration: TextDecoration.underline,
        decorationColor: color,
      ),
    );
  }
}

class _CheckoutGoogleMark extends StatelessWidget {
  const _CheckoutGoogleMark();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 20,
      child: CustomPaint(painter: _CheckoutGoogleLogoPainter()),
    );
  }
}

class _CheckoutGoogleLogoPainter extends CustomPainter {
  const _CheckoutGoogleLogoPainter();

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
  bool shouldRepaint(covariant _CheckoutGoogleLogoPainter oldDelegate) => false;
}

class _CheckoutFacebookMark extends StatelessWidget {
  const _CheckoutFacebookMark();

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
