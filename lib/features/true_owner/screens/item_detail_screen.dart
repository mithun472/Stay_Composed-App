import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../models/item_model.dart';
import '../../../services/true_owner_service.dart';
import '../providers/true_owner_providers.dart';
import '../widgets/true_owner_widgets.dart';

/// One of the user's own reports, plus the AI candidates for it.
///
/// Secret details are shown here because this screen is only ever reached
/// from the user's own list — never from a match.
class ItemDetailScreen extends ConsumerStatefulWidget {
  final Item item;
  const ItemDetailScreen({super.key, required this.item});

  @override
  ConsumerState<ItemDetailScreen> createState() => _ItemDetailScreenState();
}

class _ItemDetailScreenState extends ConsumerState<ItemDetailScreen> {
  bool _openingThread = false;

  Future<void> _openChat(CandidateMatch match) async {
    final email = ref.read(currentEmailProvider);
    if (email == null) {
      _snack('Sign in with your college email first.');
      return;
    }

    setState(() => _openingThread = true);

    final result = await ref.read(trueOwnerServiceProvider).openThread(
          complaintId: widget.item.id,
          foundItemId: match.candidate.id,
          requesterEmail: email,
        );

    if (!mounted) return;
    setState(() => _openingThread = false);

    result.when(
      success: (thread) {
        ref.refreshTrueOwner();
        context.push(AppRoutes.chat, extra: thread);
      },
      // The backend owns the confidence rule — if it refuses, show exactly
      // what it said rather than inventing our own wording.
      failure: _snack,
    );
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final async = ref.watch(myItemsProvider);
    final mine = async.value;
    final matches = mine?.matchesFor(item.id) ?? const <CandidateMatch>[];
    final threshold = mine?.chatConfidenceThreshold;

    return Scaffold(
      appBar: AppBar(title: Text(item.isLost ? 'Lost report' : 'Found report')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            children: [
              if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    item.imageUrl!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(child: Text(item.title, style: AppTextStyles.brandTitle)),
                  StatusBadge(label: item.status, color: StatusColors.forGeneric(item.status)),
                ],
              ),
              const SizedBox(height: 14),
              _DetailRow(icon: Icons.category_outlined, label: 'Category', value: item.category),
              _DetailRow(
                icon: Icons.place_outlined,
                label: 'Location',
                value: [item.location, item.locationDetail].where((e) => e != null && e.isNotEmpty).join(' \u00b7 '),
              ),
              _DetailRow(icon: Icons.event_outlined, label: 'Date', value: item.date),
              if (item.description.isNotEmpty)
                _DetailRow(icon: Icons.notes_outlined, label: 'Description', value: item.description),
              const SizedBox(height: 20),
              if (item.secretFeatures.isNotEmpty) _SecretBox(features: item.secretFeatures),
              if (item.challengeQuestions.isNotEmpty) ...[
                const SizedBox(height: 14),
                _QuestionsBox(questions: item.challengeQuestions),
              ],
              if (item.isLost) ...[
                const SizedBox(height: 28),
                Text('Possible matches', style: AppTextStyles.sectionTitle),
                const SizedBox(height: 10),
                const MatchDisclaimer(),
                const SizedBox(height: 14),
                if (async.isLoading && mine == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (matches.isEmpty)
                  _NoMatchesYet(onRefresh: () => ref.invalidate(myItemsProvider))
                else
                  for (final match in matches)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: MatchCard(
                        match: match,
                        canChat: threshold == null || match.confidence >= threshold,
                        blockedReason: threshold != null && match.confidence < threshold
                            ? 'Chat unlocks at $threshold% confidence. This match is at ${match.confidence}%.'
                            : null,
                        onChat: () => _openChat(match),
                      ),
                    ),
              ],
            ],
          ),
          if (_openingThread)
            Container(
              color: Colors.black.withValues(alpha: 0.15),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.caption),
                Text(value, style: AppTextStyles.body),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SecretBox extends StatelessWidget {
  final List<String> features;
  const _SecretBox({required this.features});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.trueOwnerLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.trueOwner),
              const SizedBox(width: 8),
              Text('Your secret details', style: AppTextStyles.sectionTitle),
            ],
          ),
          const SizedBox(height: 6),
          Text('Visible only to you. Never share these in chat.', style: AppTextStyles.bodyMuted),
          const SizedBox(height: 12),
          for (final f in features)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('\u2022  '),
                  Expanded(child: Text(f, style: AppTextStyles.body)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _QuestionsBox extends StatelessWidget {
  final List<String> questions;
  const _QuestionsBox({required this.questions});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Challenge questions', style: AppTextStyles.sectionTitle),
          const SizedBox(height: 6),
          Text('Claimants answer these to prove the item is theirs.', style: AppTextStyles.bodyMuted),
          const SizedBox(height: 12),
          for (final q in questions)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('\u2022  $q', style: AppTextStyles.body),
            ),
        ],
      ),
    );
  }
}

class _NoMatchesYet extends StatelessWidget {
  final VoidCallback onRefresh;
  const _NoMatchesYet({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.hourglass_empty_rounded, color: AppColors.textDisabled),
          const SizedBox(height: 10),
          Text('No matches yet', style: AppTextStyles.cardTitle),
          const SizedBox(height: 4),
          Text(
            'Nothing found on campus matches this yet. We\u2019ll keep checking as new items come in.',
            style: AppTextStyles.bodyMuted,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Check again'),
          ),
        ],
      ),
    );
  }
}
