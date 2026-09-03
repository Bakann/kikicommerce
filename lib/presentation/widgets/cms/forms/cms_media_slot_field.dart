import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../application/cms/cms_models.dart';
import '../../media_picker_modal.dart';
import '../cms_admin_auth.dart';

/// Reusable media slot used by section forms (hero, editorial, …).
///
/// Renders a small thumbnail preview when [value] is set, otherwise a dashed
/// placeholder. Below the preview: a "Pick a media" button (hooks into the
/// existing [MediaPickerModal]) and a clear button when a value is present.
///
/// The picker auto-prompts the [AdminLoginDialog] via [ensureAdminToken] when
/// no admin token is available yet, so the form never silently fails.
class CmsMediaSlotField extends ConsumerWidget {
  final String label;
  final CmsMediaRef? value;
  final ValueChanged<CmsMediaRef?> onChanged;

  const CmsMediaSlotField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  Future<void> _pick(BuildContext context, WidgetRef ref) async {
    final token = await ensureAdminToken(context, ref);
    if (token == null || !context.mounted) return;
    final initialSelection = value == null || !value!.isUsable
        ? null
        : MediaPickerInitialSelection(
            mediaId: value!.recordId,
            previewUrl: value!.thumbUrl(size: '300x200'),
            title: value!.filename,
            altText: value!.alt,
          );
    final result = await MediaPickerModal.show(
      context,
      authToken: token,
      currentMediaId: value?.recordId,
      initialSelection: initialSelection,
    );
    if (result == null) return;
    onChanged(
      CmsMediaRef(
        recordId: result.media.id,
        collectionId: result.media.collectionId,
        filename: result.media.file,
        alt: result.media.altText,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasValue = value != null && value!.isUsable;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        Container(
          height: 120,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F2),
            border: Border.all(color: const Color(0xFFDADAD2)),
            borderRadius: BorderRadius.circular(4),
          ),
          clipBehavior: Clip.hardEdge,
          child: hasValue
              ? _MediaPreview(media: value!)
              : const _EmptyPlaceholder(),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () => _pick(context, ref),
              icon: const Icon(Icons.image_outlined, size: 16),
              label: Text(hasValue ? 'Remplacer' : 'Choisir un média'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                textStyle: const TextStyle(fontSize: 13),
              ),
            ),
            if (hasValue) ...[
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Retirer',
                onPressed: () => onChanged(null),
                icon: const Icon(Icons.close, size: 18),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ],
        ),
        if (hasValue) ...[
          const SizedBox(height: 4),
          Text(
            value!.filename,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF6F6F6F),
              fontFamily: 'monospace',
            ),
          ),
        ],
      ],
    );
  }
}

class _MediaPreview extends StatelessWidget {
  final CmsMediaRef media;

  const _MediaPreview({required this.media});

  @override
  Widget build(BuildContext context) {
    if (media.isVideo) {
      return Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.play_circle_outline, color: Colors.white, size: 32),
            SizedBox(height: 4),
            Text('Vidéo', style: TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: media.thumbUrl(size: '300x200'),
      fit: BoxFit.cover,
      placeholder: (_, _) => Container(color: const Color(0xFFEDEAE3)),
      errorWidget: (_, _, _) => Container(color: const Color(0xFFEDEAE3)),
    );
  }
}

class _EmptyPlaceholder extends StatelessWidget {
  const _EmptyPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_outlined, color: Color(0xFF9A9A92), size: 24),
          SizedBox(height: 4),
          Text(
            'Aucun média',
            style: TextStyle(color: Color(0xFF6F6F6F), fontSize: 12),
          ),
        ],
      ),
    );
  }
}
