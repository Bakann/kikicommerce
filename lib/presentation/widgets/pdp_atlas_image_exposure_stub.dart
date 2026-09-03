import 'package:flutter/widgets.dart';

import 'pdp_atlas_image_exposure_data.dart';

void showPdpAtlasImageVisionModal(PdpAtlasImageExposureData data) {}

void hidePdpAtlasImageVisionModal() {}

/// No-op on non-web platforms so the PDP can stay platform agnostic.
class PdpAtlasImageExposure extends StatelessWidget {
  final bool enabled;

  const PdpAtlasImageExposure({super.key, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
