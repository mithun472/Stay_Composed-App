import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../models/chat_thread_model.dart';
import '../../../models/claim_model.dart';
import '../../../models/item_model.dart';
import '../../../services/true_owner_service.dart';
import '../providers/true_owner_providers.dart';

/// `POST /claims` — the owner answers the finder's challenge questions.
///
/// The questions come from the matched found item's `challengeQuestions`,
/// and `answers[i]` is matched positionally against the found item's
/// stored answer hash at index `i` (app/routers/claims.py) — there is no
/// fallback to the owner's own `secretFeatures`, those are a completely
/// separate field on a different item. A found item created through this
/// app always has at least one challenge question (the backend rejects
/// creation otherwise), so an empty list here only happens for a
/// pre-existing/legacy record — in that case the backend itself refuses
/// the claim with a 400, so we show that state up front instead of
/// rendering a form that can't succeed.
///
/// Pops `true` when verification succeeds so the chat screen refreshes.
class ClaimScreen extends ConsumerStatefulWidget {
  final ChatThread thread;
  const ClaimScreen({super.key, required this.thread});

  @override
  ConsumerState<ClaimScreen> createState() => _ClaimScreenState();
}

class _ClaimScreenState extends ConsumerState<ClaimScreen> {
  final _formKey = GlobalKey<FormState>();
  List<TextEditingController> _controllers = [];
  List<String> _questions = [];
  bool _built = false;
  bool _noChallengeConfigured = false;
  bool _submitting = false;
  ClaimResult? _result;

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _buildFields(MyItems mine) {
    if (_built) return;

    Item? candidate;
    for (final m in mine.candidateMatches) {
      if (m.candidate.id == widget.thread.foundItemId) {
        candidate = m.candidate;
        break;
      }
    }

    final questions = candidate?.challengeQuestions ?? const <String>[];
    if (questions.isEmpty) {
      _noChallengeConfigured = true;
      _built = true;
      return;
    }

    _questions = questions;
    _controllers = List.generate(questions.length, (_) => TextEditingController());
    _built = true;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final email = ref.read(currentEmailProvider);
    if (email == null) {
      _snack('Sign in with your college email first.');
      return;
    }

    setState(() => _submitting = true);

    final result = await ref.read(trueOwnerServiceProvider).submitClaim(
          complaintId: widget.thread.complaintId,
          foundItemId: widget.thread.foundItemId,
          answers: _controllers.map((c) => c.text.trim()).toList(),
          claimantEmail: email,
        );

    if (!mounted) return;
    setState(() => _submitting = false);

    result.when(
      success: (claim) {
        setState(() => _result = claim);
        ref.refreshTrueOwner();
      },
      failure: _snack,
    );
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final mine = ref.watch(myItemsProvider).value;
    if (mine != null) _buildFields(mine);

    return Scaffold(
      appBar: AppBar(title: const Text('Prove it\u2019s yours')),
      body: _result != null
          ? _ResultView(
              result: _result!,
              onDone: () => Navigator.of(context).pop(_result!.verified),
              onRetry: _result!.verified || _result!.isOnCooldown
                  ? null
                  : () => setState(() => _result = null),
            )
          : !_built
              ? const Center(child: CircularProgressIndicator())
              : _noChallengeConfigured
                  ? _NoChallengeView(onBack: () => Navigator.of(context).pop(false))
                  : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.infoLight,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.fact_check_outlined, size: 18, color: AppColors.info),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Answer in your own words. You pass when more than half your '
                                'answers match what the finder recorded.',
                                style: AppTextStyles.bodyMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      for (int i = 0; i < _questions.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_questions[i], style: AppTextStyles.cardTitle),
                              const SizedBox(height: 8),
                              TextFormField(
                                controller: _controllers[i],
                                decoration: const InputDecoration(hintText: 'Your answer'),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty) ? 'Answer this to continue' : null,
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                      PrimaryButton(
                        label: 'Submit verification',
                        icon: Icons.verified_outlined,
                        backgroundColor: AppColors.trueOwner,
                        isLoading: _submitting,
                        onPressed: _submit,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }
}

/// Shown when the matched found item has no challenge questions configured
/// — a legacy-data case the backend itself refuses with a 400, so there's
/// no form worth rendering here.
class _NoChallengeView extends StatelessWidget {
  final VoidCallback onBack;
  const _NoChallengeView({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(color: AppColors.errorLight, shape: BoxShape.circle),
              child: const Icon(Icons.error_outline_rounded, size: 36, color: AppColors.error),
            ),
            const SizedBox(height: 18),
            Text('No verification challenge set up', style: AppTextStyles.sectionTitle, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'This found item doesn\u2019t have a challenge question configured, so it can\u2019t be verified yet. '
              'Ask the finder to check their report, or contact admin support.',
              style: AppTextStyles.bodyMuted,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton(onPressed: onBack, child: const Text('Back to chat')),
          ],
        ),
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  final ClaimResult result;
  final VoidCallback onDone;
  final VoidCallback? onRetry;

  const _ResultView({required this.result, required this.onDone, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final ok = result.verified;
    final color = ok ? AppColors.success : AppColors.error;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: ok ? AppColors.successLight : AppColors.errorLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                ok ? Icons.verified_rounded : Icons.close_rounded,
                size: 36,
                color: color,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              ok ? 'Ownership verified' : 'Not verified',
              style: AppTextStyles.sectionTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              result.message.isNotEmpty
                  ? result.message
                  : '${result.matchedFields} of ${result.totalFields} details matched.',
              style: AppTextStyles.bodyMuted,
              textAlign: TextAlign.center,
            ),
            if (result.isOnCooldown) ...[
              const SizedBox(height: 10),
              Text(
                'You can try again after ${result.cooldownUntil!.toLocal()}.',
                style: AppTextStyles.caption,
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 26),
            if (onRetry != null) ...[
              OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
              const SizedBox(height: 10),
            ],
            PrimaryButton(
              label: ok ? 'Back to chat' : 'Close',
              onPressed: onDone,
              backgroundColor: ok ? AppColors.trueOwner : null,
            ),
          ],
        ),
      ),
    );
  }
}
