import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/api_result.dart';
import '../../../core/widgets/state_placeholders.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../models/blood_alert_model.dart';
import '../../../models/item_model.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../true_owner/providers/true_owner_providers.dart';
import '../../../services/blood_alert_service.dart';

/// Equivalent of the Next.js `/profile` page: avatar + account status,
/// combined lost/found report history (myComplaints + myFoundItems, same
/// source as TrueOwner's own screens), and blood alert history — that last
/// section previously only lived inside the Blood Donation module
/// (MyBloodAlertsScreen); it's surfaced here too now, same data/service,
/// nothing duplicated or reimplemented.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  ApiResult<List<BloodAlert>>? _bloodResult;

  @override
  void initState() {
    super.initState();
    _loadBloodAlerts();
  }

  Future<void> _loadBloodAlerts() async {
    final email = ref.read(authControllerProvider).user?.collegeEmail;
    if (email == null) {
      setState(() => _bloodResult = ApiResult.failure('Sign in with your college email first.'));
      return;
    }
    setState(() => _bloodResult = null);
    final result = await ref.read(bloodAlertServiceProvider).getMine(email);
    if (mounted) setState(() => _bloodResult = result);
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text("You'll need to sign in again with your college email."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log out', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).signOut();
      if (mounted) context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).user;
    final itemsAsync = ref.watch(myItemsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Backend settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push(AppRoutes.settings),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.refreshTrueOwner();
          await _loadBloodAlerts();
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: [
            _ProfileHeader(
              name: user?.name ?? 'Student',
              email: user?.collegeEmail ?? '',
              photoUrl: user?.photoUrl,
              onLogout: _confirmLogout,
            ),
            const SizedBox(height: 16),
            _AccountStatusCard(email: user?.collegeEmail),
            const SizedBox(height: 28),
            Text('My Lost & Found Reports', style: AppTextStyles.sectionTitle),
            const SizedBox(height: 12),
            switch (itemsAsync) {
              AsyncData(:final value) => _ItemHistoryList(
                  items: [...value.myComplaints, ...value.myFoundItems],
                ),
              AsyncError() => AppErrorView(
                  message: "Couldn't load your reports.",
                  onRetry: () => ref.refreshTrueOwner(),
                ),
              _ => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
            },
            const SizedBox(height: 28),
            Text('My Blood Alert Broadcasts', style: AppTextStyles.sectionTitle),
            const SizedBox(height: 12),
            _BloodAlertHistoryList(result: _bloodResult, onRetry: _loadBloodAlerts),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatefulWidget {
  final String name;
  final String email;
  final String? photoUrl;
  final VoidCallback onLogout;

  const _ProfileHeader({
    required this.name,
    required this.email,
    required this.photoUrl,
    required this.onLogout,
  });

  @override
  State<_ProfileHeader> createState() => _ProfileHeaderState();
}

class _ProfileHeaderState extends State<_ProfileHeader> {
  // Same stateful fallback pattern as home_screen.dart's _Avatar: a
  // network image can fail (offline, expired Google URL) after the
  // initial build, and CircleAvatar can't swap its own child in response
  // — only a rebuild triggered from onBackgroundImageError can.
  bool _loadFailed = false;

  @override
  void didUpdateWidget(covariant _ProfileHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoUrl != widget.photoUrl) _loadFailed = false;
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = widget.photoUrl != null && widget.photoUrl!.isNotEmpty && !_loadFailed;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            backgroundImage: hasPhoto ? NetworkImage(widget.photoUrl!) : null,
            onBackgroundImageError: hasPhoto
                ? (_, __) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _loadFailed = true);
                    });
                  }
                : null,
            child: hasPhoto
                ? null
                : Text(
                    widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?',
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 24),
                  ),
          ),
          const SizedBox(height: 12),
          Text(widget.name, style: AppTextStyles.sectionTitle),
          if (widget.email.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(widget.email, style: AppTextStyles.bodyMuted),
          ],
          const SizedBox(height: 10),
          TextButton(
            onPressed: widget.onLogout,
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Sign out of account'),
          ),
        ],
      ),
    );
  }
}

class _AccountStatusCard extends StatelessWidget {
  final String? email;
  const _AccountStatusCard({required this.email});

  @override
  Widget build(BuildContext context) {
    final isCollegeAccount = email != null && email!.toLowerCase().endsWith('.in');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.infoLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_user_outlined, color: AppColors.info, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Verified Campus Member', style: AppTextStyles.cardTitle.copyWith(color: AppColors.info)),
                const SizedBox(height: 2),
                Text(
                  isCollegeAccount
                      ? 'Authenticated via your college account.'
                      : 'Authenticated via campus sign-in.',
                  style: AppTextStyles.bodyMuted,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemHistoryList extends StatelessWidget {
  final List<Item> items;
  const _ItemHistoryList({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const AppEmptyView(
        icon: Icons.inventory_2_outlined,
        title: 'No reports yet',
        message: 'Lost or found reports you file will show up here.',
      );
    }
    return Column(
      children: items.map((item) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
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
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: item.isLost ? AppColors.trueOwnerLight : AppColors.infoLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.isLost ? 'LOST COMPLAINT' : 'FOUND REPORT',
                      style: AppTextStyles.caption.copyWith(
                        fontWeight: FontWeight.w700,
                        color: item.isLost ? AppColors.trueOwner : AppColors.info,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (item.createdAt != null)
                    Text(
                      '${item.createdAt!.day}/${item.createdAt!.month}/${item.createdAt!.year}',
                      style: AppTextStyles.caption,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(item.title, style: AppTextStyles.cardTitle),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.sell_outlined, size: 13, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(item.category, style: AppTextStyles.caption),
                  if (item.location.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    Icon(Icons.place_outlined, size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(child: Text(item.location, style: AppTextStyles.caption, overflow: TextOverflow.ellipsis)),
                  ],
                  const Spacer(),
                  StatusBadge(label: item.status, color: StatusColors.forGeneric(item.status)),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _BloodAlertHistoryList extends StatelessWidget {
  final ApiResult<List<BloodAlert>>? result;
  final VoidCallback onRetry;
  const _BloodAlertHistoryList({required this.result, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return switch (result) {
      null => const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(child: CircularProgressIndicator()),
        ),
      ApiFailure<List<BloodAlert>>(message: final message) => AppErrorView(message: message, onRetry: onRetry),
      ApiSuccess<List<BloodAlert>>(data: final alerts) when alerts.isEmpty => const AppEmptyView(
          icon: Icons.favorite_border_rounded,
          title: 'No broadcasts yet',
          message: 'Emergency blood alerts you send will show up here.',
        ),
      ApiSuccess<List<BloodAlert>>(data: final alerts) => Column(
          children: alerts.map((alert) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
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
                    decoration: const BoxDecoration(color: AppColors.bloodLight, shape: BoxShape.circle),
                    child: Text(
                      alert.bloodType,
                      style: AppTextStyles.cardTitle.copyWith(color: AppColors.blood),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(alert.studentName, style: AppTextStyles.cardTitle),
                        Text(alert.phoneNumber, style: AppTextStyles.bodyMuted),
                      ],
                    ),
                  ),
                  if (alert.status != null) Text(alert.status!, style: AppTextStyles.caption),
                ],
              ),
            );
          }).toList(),
        ),
      _ => const SizedBox.shrink(),
    };
  }
}
