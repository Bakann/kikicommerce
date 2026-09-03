import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const kCheckoutBackground = Color(0xFFF8F8F8);
const kCheckoutCardBorder = Color(0xFFE0E0E0);
const kCheckoutMuted = Color(0xFF7F858A);
const kCheckoutPrimary = Color(0xFF343A40);
const kCheckoutHeading = Color(0xFF2E3032);
const kCheckoutPlaceholder = Color(0xFFC8C8C8);
const kCheckoutImagePanel = Color(0xFFF4F4F4);
const kCheckoutCardRadius = 4.0;
const kCheckoutDesktopBreakpoint = 900.0;
const kCheckoutDesktopMaxWidth = 1680.0;
const kCheckoutDesktopSummaryWidth = 456.0;

TextStyle checkoutSans({
  double fontSize = 15,
  FontWeight fontWeight = FontWeight.w400,
  Color color = kCheckoutHeading,
  double? height,
  TextDecoration? decoration,
  Color? decorationColor,
}) {
  return TextStyle(
    fontFamily: 'Montserrat',
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: height,
    decoration: decoration,
    decorationColor: decorationColor,
  );
}

TextStyle checkoutSerif({
  double fontSize = 25,
  FontWeight fontWeight = FontWeight.w500,
  Color color = kCheckoutHeading,
  double? height,
}) {
  return GoogleFonts.cormorantGaramond(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    height: height,
  );
}
