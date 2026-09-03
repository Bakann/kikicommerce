import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../widgets/storefront_layout.dart';
import '../product_detail_layout_spec.dart';

class ProductDetailFooter extends StatelessWidget {
  const ProductDetailFooter({super.key});

  static const _columns = [
    (
      title: 'Services',
      links: ['Contactez-nous', 'Livraison', 'Retours & échanges'],
    ),
    (title: 'La Maison', links: ['Savoir-faire', 'Nos boutiques', 'Carrières']),
    (title: 'Suivez-nous', links: ['Instagram', 'Pinterest', 'Newsletter']),
  ];

  @override
  Widget build(BuildContext context) {
    return StorefrontFullBleed(
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF7F7F5),
          border: Border(top: BorderSide(color: productDetailDividerColor)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(64, 54, 64, 42),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Kiki',
                        style: GoogleFonts.notoSerif(
                          fontSize: 34,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF2D2D2A),
                          height: 1,
                        ),
                      ),
                    ),
                    for (final column in _columns)
                      Expanded(
                        child: _ProductDetailFooterColumn(
                          title: column.title,
                          links: column.links,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 52),
                const Divider(height: 1, color: productDetailDividerColor),
                const SizedBox(height: 22),
                const Row(
                  children: [
                    Text(
                      'France - Français',
                      style: TextStyle(
                        fontSize: 12,
                        color: productDetailMutedTextColor,
                      ),
                    ),
                    Spacer(),
                    Text(
                      'Conditions générales    Confidentialité    Cookies',
                      style: TextStyle(
                        fontSize: 12,
                        color: productDetailMutedTextColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProductDetailFooterColumn extends StatelessWidget {
  final String title;
  final List<String> links;

  const _ProductDetailFooterColumn({required this.title, required this.links});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2D2D2A),
            height: 1.25,
          ),
        ),
        const SizedBox(height: 18),
        for (final link in links)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              link,
              style: const TextStyle(
                fontSize: 13,
                color: productDetailMutedTextColor,
                height: 1.2,
              ),
            ),
          ),
      ],
    );
  }
}
