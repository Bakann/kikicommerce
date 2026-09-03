// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

import 'package:flutter/widgets.dart';

import 'pdp_atlas_image_exposure_data.dart';

const _legacyExposureRootId = 'atlas-product-image-exposure';
const _modalRootId = 'atlas-product-image-vision-modal';
const _modalSheetId = 'atlas-product-image-vision-sheet';
const _modalImageId = 'atlas-product-image-vision-image';
const _modalCloseId = 'atlas-product-image-vision-close';

void showPdpAtlasImageVisionModal(PdpAtlasImageExposureData data) {
  final imageUrl = data.imageUrl.trim();
  if (imageUrl.isEmpty) {
    hidePdpAtlasImageVisionModal();
    return;
  }

  _removeLegacyExposurePanel();

  final root = _getOrCreateModalRoot();
  final sheet = _getOrCreateSheet(root);
  final image = _getOrCreateImage(sheet);
  _getOrCreateCloseButton(sheet);

  image
    ..src = imageUrl
    ..alt = data.imageAlt.trim().isEmpty ? 'product image' : data.imageAlt;

  root.dataset['imageUrl'] = imageUrl;
  root.dataset['productId'] = data.productId;
  root.dataset['productCode'] = data.productCode;
}

void hidePdpAtlasImageVisionModal() {
  html.document.getElementById(_modalRootId)?.remove();
  _removeLegacyExposurePanel();
}

html.DivElement _getOrCreateModalRoot() {
  final existing = html.document.getElementById(_modalRootId);
  if (existing is html.DivElement) {
    return existing;
  }

  final root = html.DivElement()
    ..id = _modalRootId
    ..style.position = 'fixed'
    ..style.top = '0'
    ..style.right = '0'
    ..style.bottom = '0'
    ..style.left = '0'
    ..style.zIndex = '2147483647'
    ..style.background = 'rgba(10, 10, 10, 0.92)';
  html.document.body?.append(root);
  return root;
}

html.DivElement _getOrCreateSheet(html.DivElement root) {
  final existing = root.querySelector('#$_modalSheetId');
  if (existing is html.DivElement) {
    return existing;
  }

  final sheet = html.DivElement()
    ..id = _modalSheetId
    ..style.position = 'absolute'
    ..style.top = '0'
    ..style.right = '0'
    ..style.bottom = '0'
    ..style.left = '0'
    ..style.display = 'flex'
    ..style.alignItems = 'center'
    ..style.justifyContent = 'center'
    ..style.padding = '0'
    ..style.overflow = 'hidden';
  root.append(sheet);
  return sheet;
}

html.ImageElement _getOrCreateImage(html.DivElement sheet) {
  final existing = sheet.querySelector('#$_modalImageId');
  if (existing is html.ImageElement) {
    return existing;
  }

  final image = html.ImageElement()
    ..id = _modalImageId
    ..style.display = 'block'
    ..style.width = '100%'
    ..style.height = '100%'
    ..style.maxWidth = '100%'
    ..style.maxHeight = '100%'
    ..style.objectFit = 'contain';
  sheet.append(image);
  return image;
}

html.ButtonElement _getOrCreateCloseButton(html.DivElement sheet) {
  final existing = sheet.querySelector('#$_modalCloseId');
  if (existing is html.ButtonElement) {
    return existing;
  }

  final button = html.ButtonElement()
    ..id = _modalCloseId
    ..type = 'button'
    ..text = 'Close'
    ..style.position = 'absolute'
    ..style.top = '20px'
    ..style.right = '20px'
    ..style.border = '0'
    ..style.borderRadius = '999px'
    ..style.padding = '10px 16px'
    ..style.background = 'rgba(255, 255, 255, 0.92)'
    ..style.color = '#111111'
    ..style.cursor = 'pointer'
    ..style.fontSize = '14px'
    ..style.fontWeight = '600'
    ..style.boxShadow = '0 8px 24px rgba(0, 0, 0, 0.18)';
  button.onClick.listen((_) => hidePdpAtlasImageVisionModal());
  sheet.append(button);
  return button;
}

void _removeLegacyExposurePanel() {
  html.document.getElementById(_legacyExposureRootId)?.remove();
}

class PdpAtlasImageExposure extends StatefulWidget {
  final bool enabled;

  const PdpAtlasImageExposure({super.key, required this.enabled});

  @override
  State<PdpAtlasImageExposure> createState() => _PdpAtlasImageExposureState();
}

class _PdpAtlasImageExposureState extends State<PdpAtlasImageExposure> {
  @override
  void initState() {
    super.initState();
    _syncLifecycle();
  }

  @override
  void didUpdateWidget(covariant PdpAtlasImageExposure oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncLifecycle();
  }

  @override
  void dispose() {
    hidePdpAtlasImageVisionModal();
    super.dispose();
  }

  void _syncLifecycle() {
    _removeLegacyExposurePanel();
    if (!widget.enabled) {
      hidePdpAtlasImageVisionModal();
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
