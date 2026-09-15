import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../models/item_model.dart';
import '../../../models/chat_thread_model.dart';

/// Canned prompts shown before verification.
///
/// These strings are checked for EXACT equality against
/// `PRE_VERIFICATION_MESSAGES` in the backend's `app/routers/chat.py` —
/// this is a real server-side allowlist, not just a client-side rail, so
/// the two lists must stay byte-for-byte identical or a tap here comes
/// back as a rejected message.
class CannedPrompts {
  CannedPrompts._();

  static const List<String> forOwner = [
    'Where exactly did you find it?',
    'What time did you find it?',
    'Can you describe the item\'s condition?',
    'Can you share a safe public meeting point?',
    'Are you ready to initiate the verification challenge?',
    'I lost it on campus earlier today.',
    'I lost it near the library / canteen area.',
    'It has my personal marks and contents inside.',
    'I can verify the secret challenge questions.',
    'Yes, I am available to meet and verify.',
  ];

  static const List<String> forFinder = [
    'Can you describe key details or unique marks on the item?',
    'When and where approximately did you lose it?',
    'What brand, color, or model is the item?',
    'Are you ready to answer the verification challenge?',
    'Can you share a safe public meeting point?',
    'I found it near the campus grounds / academic block.',
    'I found it earlier today and kept it safe.',
    'The item is in good condition and kept securely.',
    'Let\'s coordinate at a campus security desk or public spot.',
    'Please answer the verification challenge so we can proceed.',
  ];
}

/// Confidence pill. Deliberately worded as a suggestion — a match is
/// never proof of ownership, and the UI should never imply otherwise.
class ConfidenceChip extends StatelessWidget {
  final int confidence;
  const ConfidenceChip({super.key, required this.confidence});

  @override
  Widget build(BuildContext context) {
    final color = confidence >= 75
        ? AppColors.success
        : confidence >= 50
            ? AppColors.warning
            : AppColors.textSecondary;
    return StatusBadge(
      label: '$confidence% match',
      color: color,
      icon: Icons.auto_awesome_rounded,
    );
  }
}

/// Small square image with a graceful fallback — Cloudinary URLs can 404
/// and a broken icon looks worse than a neutral placeholder.
class ItemThumbnail extends StatelessWidget {
  final String? imageUrl;
  final double size;
  const ItemThumbnail({super.key, this.imageUrl, this.size = 56});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.inventory_2_outlined, color: AppColors.textDisabled, size: size * 0.45),
    );

    if (imageUrl == null || imageUrl!.isEmpty) return placeholder;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        imageUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
      ),
    );
  }
}

/// Row used in the dashboard lists for the user's own items.
class ItemCard extends StatelessWidget {
  final Item item;
  final int matchCount;
  final VoidCallback? onTap;

  const ItemCard({super.key, required this.item, this.matchCount = 0, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ItemThumbnail(imageUrl: item.imageUrl),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: AppTextStyles.cardTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    '${item.category} · ${item.location}',
                    style: AppTextStyles.bodyMuted,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      StatusBadge(
                        label: item.status,
                        color: StatusColors.forGeneric(item.status),
                      ),
                      if (matchCount > 0)
                        StatusBadge(
                          label: matchCount == 1 ? '1 possible match' : '$matchCount possible matches',
                          color: AppColors.trueOwner,
                          icon: Icons.auto_awesome_rounded,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textDisabled),
          ],
        ),
      ),
    );
  }
}

/// Card for one AI-suggested found item under a complaint.
class MatchCard extends StatelessWidget {
  final CandidateMatch match;
  final bool canChat;
  final String? blockedReason;
  final VoidCallback onChat;

  const MatchCard({
    super.key,
    required this.match,
    required this.canChat,
    required this.onChat,
    this.blockedReason,
  });

  @override
  Widget build(BuildContext context) {
    final c = match.candidate;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ItemThumbnail(imageUrl: c.imageUrl, size: 64),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.title, style: AppTextStyles.cardTitle),
                    const SizedBox(height: 2),
                    Text('Found at ${c.location}', style: AppTextStyles.bodyMuted),
                    Text('Reported by ${c.reportedBy ?? "a student"}', style: AppTextStyles.caption),
                    const SizedBox(height: 8),
                    ConfidenceChip(confidence: match.confidence),
                  ],
                ),
              ),
            ],
          ),
          if (c.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(c.description, style: AppTextStyles.body),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: canChat ? onChat : null,
              icon: const Icon(Icons.forum_outlined, size: 18),
              label: const Text('Chat with finder'),
            ),
          ),
          if (!canChat && blockedReason != null) ...[
            const SizedBox(height: 8),
            Text(blockedReason!, style: AppTextStyles.caption, textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}

/// Persistent reminder that a match is a suggestion, not proof.
class MatchDisclaimer extends StatelessWidget {
  const MatchDisclaimer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.infoLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.info),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'These are AI suggestions, not proof of ownership. You still have to '
              'answer the finder\u2019s verification questions before anything is handed over.',
              style: AppTextStyles.bodyMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Thread row in the chat list.
class ThreadCard extends StatelessWidget {
  final ChatThread thread;
  final String title;
  final VoidCallback onTap;

  const ThreadCard({super.key, required this.thread, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final phase = thread.phase;
    final color = switch (phase) {
      ChatPhase.preVerification => AppColors.info,
      ChatPhase.verifying => AppColors.warning,
      ChatPhase.verified => AppColors.success,
      ChatPhase.handedOver => AppColors.textSecondary,
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(color: AppColors.trueOwnerLight, shape: BoxShape.circle),
              child: const Icon(Icons.forum_outlined, color: AppColors.trueOwner, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.cardTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      StatusBadge(label: phase.label, color: color),
                      const SizedBox(width: 8),
                      Text('${thread.confidence}%', style: AppTextStyles.caption),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textDisabled),
          ],
        ),
      ),
    );
  }
}
