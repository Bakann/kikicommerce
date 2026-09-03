import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/app_localizations_fr.dart';

/// Presentation-layer shorthand for `AppLocalizations.of(context)`.
///
/// Use `context.l10n.someKey` inside `lib/presentation/**` widgets only. The
/// data/domain/application layers must not depend on [AppLocalizations]; map
/// stable codes/enums to strings at the render site instead.
extension L10nX on BuildContext {
  AppLocalizations get l10n {
    final resolved = Localizations.of<AppLocalizations>(this, AppLocalizations);
    assert(() {
      if (resolved == null) {
        debugPrint(
          'Missing AppLocalizations in BuildContext; falling back to fr.',
        );
      }
      return true;
    }());
    return resolved ?? AppLocalizationsFr();
  }
}
