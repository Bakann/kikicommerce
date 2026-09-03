import 'package:flutter/widgets.dart';

import '../presentation/providers/locale_provider.dart';

class LocaleRouteResolution {
  final Locale? pathLocale;
  final Locale? queryLocale;
  final Locale effectiveLocale;
  final Uri canonicalUri;
  final bool shouldRedirect;
  final bool isPublicLocalizedRoute;
  final bool isNeutralRoute;
  final String routePath;

  const LocaleRouteResolution({
    required this.pathLocale,
    required this.queryLocale,
    required this.effectiveLocale,
    required this.canonicalUri,
    required this.shouldRedirect,
    required this.isPublicLocalizedRoute,
    required this.isNeutralRoute,
    required this.routePath,
  });

  Locale? get urlLocale => pathLocale ?? queryLocale;
}

LocaleRouteResolution resolveLocaleRoute(
  Uri uri, {
  String? sessionLocale,
  String? persistedLocale,
}) {
  final originalPath = uri.path.isEmpty ? '/' : uri.path;
  final originalSegments = uri.pathSegments;
  final firstSegment = originalSegments.isEmpty ? null : originalSegments.first;
  final pathLocale = supportedLocaleFromCode(firstSegment);
  final hasValidPathLocale = pathLocale != null;
  final hasInvalidPathLocale =
      !hasValidPathLocale && _looksLikeLocaleSegment(firstSegment);
  final hasPathLocaleCandidate = hasValidPathLocale || hasInvalidPathLocale;
  final routeSegments = hasPathLocaleCandidate
      ? originalSegments.skip(1).toList(growable: false)
      : originalSegments;
  final routePath = _pathFromSegments(routeSegments);
  final isPublicRoute = _isPublicLocalizedRoute(routePath);
  final isNeutralRoute = _isNeutralRoute(routePath);
  // The site root `/` is the natural entry point rather than a legacy content
  // URL, so it honours the user's session/persisted language. Every other
  // legacy public URL stays a deterministic alias to the French default
  // (stable canonicalisation / SEO), independent of session or preference.
  final isRootRoute = routePath == '/';
  final queryLocale = hasPathLocaleCandidate
      ? null
      : _queryLocale(uri.queryParametersAll);
  final session = supportedLocaleFromCode(sessionLocale);
  final persisted = supportedLocaleFromCode(persistedLocale);

  final effectiveLocale =
      pathLocale ??
      (hasInvalidPathLocale && (isPublicRoute || isNeutralRoute)
          ? kFallbackLocale
          : null) ??
      queryLocale ??
      (isPublicRoute && !isRootRoute ? kFallbackLocale : null) ??
      session ??
      persisted ??
      kFallbackLocale;

  final canonicalUri = _canonicalUri(
    uri,
    originalPath: originalPath,
    routePath: routePath,
    pathLocale: pathLocale,
    hasInvalidPathLocale: hasInvalidPathLocale,
    effectiveLocale: effectiveLocale,
    isPublicRoute: isPublicRoute,
    isNeutralRoute: isNeutralRoute,
  );

  return LocaleRouteResolution(
    pathLocale: pathLocale,
    queryLocale: queryLocale,
    effectiveLocale: effectiveLocale,
    canonicalUri: canonicalUri,
    shouldRedirect: canonicalUri.toString() != uri.toString(),
    isPublicLocalizedRoute: isPublicRoute,
    isNeutralRoute: isNeutralRoute,
    routePath: routePath,
  );
}

Uri localizedUriFor(Uri uri, {required String locale}) {
  final targetLocale = supportedLocaleFromCode(locale) ?? kFallbackLocale;
  final resolution = resolveLocaleRoute(
    uri,
    sessionLocale: targetLocale.languageCode,
    persistedLocale: targetLocale.languageCode,
  );
  if (resolution.isNeutralRoute) {
    return _uriWith(path: resolution.routePath, source: uri);
  }
  if (!resolution.isPublicLocalizedRoute) {
    return uri;
  }
  return _uriWith(
    path: _localizedPath(targetLocale.languageCode, resolution.routePath),
    source: uri,
  );
}

Uri _canonicalUri(
  Uri uri, {
  required String originalPath,
  required String routePath,
  required Locale? pathLocale,
  required bool hasInvalidPathLocale,
  required Locale effectiveLocale,
  required bool isPublicRoute,
  required bool isNeutralRoute,
}) {
  if (pathLocale != null) {
    if (isNeutralRoute) {
      return _uriWith(path: routePath, source: uri);
    }
    if (isPublicRoute || routePath != originalPath) {
      return _uriWith(
        path: _localizedPath(pathLocale.languageCode, routePath),
        source: uri,
      );
    }
  }

  if (hasInvalidPathLocale) {
    if (isPublicRoute) {
      return _uriWith(
        path: _localizedPath(kFallbackLocale.languageCode, routePath),
        source: uri,
      );
    }
    if (isNeutralRoute) {
      return _uriWith(path: routePath, source: uri);
    }
    return uri;
  }

  if (isPublicRoute) {
    // `effectiveLocale` already encodes the legacy-vs-root rule: a non-root
    // public URL resolves to the French default here, while the root honours
    // the query/session/persisted locale.
    return _uriWith(
      path: _localizedPath(effectiveLocale.languageCode, routePath),
      source: uri,
    );
  }

  if (isNeutralRoute) {
    return _uriWith(path: routePath, source: uri);
  }

  return uri;
}

Uri _uriWith({required String path, required Uri source}) {
  final queryParameters = _nonLocaleQueryParameters(source.queryParametersAll);
  return Uri(
    path: path,
    queryParameters: queryParameters.isEmpty ? null : queryParameters,
    fragment: source.fragment.isEmpty ? null : source.fragment,
  );
}

Map<String, Object> _nonLocaleQueryParameters(
  Map<String, List<String>> parameters,
) {
  final result = <String, Object>{};
  for (final entry in parameters.entries) {
    final key = entry.key;
    if (_isLocaleQueryKey(key)) continue;
    final values = entry.value;
    result[key] = values.length == 1 ? values.single : values;
  }
  return result;
}

Locale? _queryLocale(Map<String, List<String>> parameters) {
  for (final entry in parameters.entries) {
    if (!_isLocaleQueryKey(entry.key)) continue;
    if (entry.value.isEmpty) return null;
    final locale = supportedLocaleFromCode(entry.value.first);
    if (locale != null) return locale;
  }
  return null;
}

bool _isLocaleQueryKey(String key) {
  final normalized = key.trim().toLowerCase();
  return normalized == 'lang' || normalized == 'locale';
}

String _localizedPath(String locale, String routePath) {
  if (routePath == '/') return '/$locale';
  return '/$locale$routePath';
}

String _pathFromSegments(List<String> segments) {
  final normalized = segments.toList(growable: true);
  while (normalized.isNotEmpty && normalized.last.isEmpty) {
    normalized.removeLast();
  }
  if (normalized.isEmpty) return '/';
  return '/${normalized.map(Uri.encodeComponent).join('/')}';
}

bool _looksLikeLocaleSegment(String? segment) {
  if (segment == null || segment.isEmpty) return false;
  return RegExp(r'^[A-Za-z]{2}(-[A-Za-z]{2})?$').hasMatch(segment);
}

bool _isPublicLocalizedRoute(String path) {
  return path == '/' ||
      path == '/catalog' ||
      path.startsWith('/catalog/') ||
      path == '/product' ||
      path == '/search' ||
      path == '/sport' ||
      path.startsWith('/sport/');
}

bool _isNeutralRoute(String path) {
  return path == '/admin' ||
      path == '/cart' ||
      path == '/checkout' ||
      path.startsWith('/checkout/') ||
      path == '/lab' ||
      path.startsWith('/lab/');
}
