import 'package:flutter/widgets.dart';

import '../../../application/storefront/storefront_sport_segment.dart';
import '../../../l10n/app_localizations.dart';
import '../../l10n/l10n_extension.dart';

String localizedSportSegmentLabel(
  BuildContext context,
  StorefrontSportSegment segment,
) {
  final l10n = context.l10n;
  return switch (segment) {
    StorefrontSportSegment.homme => l10n.sportSegmentMen,
    StorefrontSportSegment.femme => l10n.sportSegmentWomen,
    StorefrontSportSegment.enfant => l10n.sportSegmentKids,
  };
}

String localizedLegacyCmsText(BuildContext context, String value) {
  return localizedLegacyCmsTextFor(context.l10n, value);
}

String localizedLegacyCmsTextFor(AppLocalizations l10n, String value) {
  return switch (value.trim()) {
    'Homme' => l10n.sportSegmentMen,
    'Femme' => l10n.sportSegmentWomen,
    'Enfant' => l10n.sportSegmentKids,
    'Parcourir' => l10n.cmsBrowse,
    'Découvrir' => l10n.cmsDiscover,
    'Voir tout' => l10n.cmsViewAll,
    'Chaussures' => l10n.cmsShoes,
    'Vêtements' => l10n.cmsClothing,
    'Accessoires' => l10n.cmsAccessories,
    'En ce moment' => l10n.cmsNikeTrendingNow,
    'Choisis ton aventure' => l10n.cmsNikeChooseYourAdventure,
    "Articles d'été" => l10n.cmsNikeSummerEssentials,
    "Pack Ballon d'Or" => l10n.cmsNikeBallonDOrPack,
    'Modèles iconiques' => l10n.cmsNikeIconicStyles,
    'Nos marques' => l10n.cmsNikeOurBrands,
    'Dernières sorties' => l10n.productCardLatestReleases,
    _ => value,
  };
}
