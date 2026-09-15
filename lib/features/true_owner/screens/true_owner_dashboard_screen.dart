import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/state_placeholders.dart';
import '../../../models/item_model.dart';
import '../providers/true_owner_providers.dart';
import '../widgets/true_owner_widgets.dart';

/// Home of the true-owner flow: everything the signed-in user has
/// reported, plus their chat threads. All three tabs come from two
/// endpoints (`/items/mine`, `/chat/my-threads`) so the whole screen
/// refreshes with one pull.
class TrueOwnerDashboardScreen extends ConsumerWidget {
  const TrueOwnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('TrueOwner'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Lost'),
              Tab(text: 'Found'),
              Tab(text: 'Chats'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _MyItemsTab(type: 'lost'),
            _MyItemsTab(type: 'found'),
            _ChatsTab(),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.trueOwner,
          foregroundColor: Colors.white,
          onPressed: () => _chooseReportType(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Report'),
        ),
      ),
    );
  }

  Future<void> _chooseReportType(BuildContext context) async {
    final type = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('What would you like to report?', style: AppTextStyles.sectionTitle),
            ),
            ListTile(
              leading: const Icon(Icons.search_off_rounded, color: AppColors.trueOwner),
              title: const Text('I lost something'),
              subtitle: const Text('We\u2019ll look for matching found reports.'),
              onTap: () => Navigator.pop(context, 'lost'),
            ),
            ListTile(
              leading: const Icon(Icons.volunteer_activism_outlined, color: AppColors.trueOwner),
              title: const Text('I found something'),
              subtitle: const Text('Only the real owner will be able to claim it.'),
              onTap: () => Navigator.pop(context, 'found'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );

    if (type != null && context.mounted) {
      context.push(type == 'lost' ? AppRoutes.reportLost : AppRoutes.reportFound);
    }
  }
}

class _MyItemsTab extends ConsumerWidget {
  final String type;
  const _MyItemsTab({required this.type});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myItemsProvider);

    return async.when(
      loading: () => const AppLoadingView(message: 'Loading your reports...'),
      error: (e, _) => AppErrorView(
        message: e.toString().replaceFirst('Exception: ', ''),
        onRetry: () => ref.invalidate(myItemsProvider),
      ),
      data: (mine) {
        final items = type == 'lost' ? mine.myComplaints : mine.myFoundItems;

        if (items.isEmpty) {
          return AppEmptyView(
            icon: type == 'lost' ? Icons.search_off_rounded : Icons.volunteer_activism_outlined,
            title: type == 'lost' ? 'No lost reports yet' : 'No found reports yet',
            message: type == 'lost'
                ? 'Report something you lost and we\u2019ll surface matching found items here.'
                : 'Report something you found so its owner can come forward.',
            actionLabel: 'Refresh',
            onAction: () => ref.invalidate(myItemsProvider),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.refreshTrueOwner(),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final Item item = items[index];
              final matchCount = type == 'lost' ? mine.matchesFor(item.id).length : 0;
              return ItemCard(
                item: item,
                matchCount: matchCount,
                onTap: () => context.push(AppRoutes.itemDetail, extra: item),
              );
            },
          ),
        );
      },
    );
  }
}

class _ChatsTab extends ConsumerWidget {
  const _ChatsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myThreadsProvider);
    final items = ref.watch(myItemsProvider).value;

    return async.when(
      loading: () => const AppLoadingView(message: 'Loading your chats...'),
      error: (e, _) => AppErrorView(
        message: e.toString().replaceFirst('Exception: ', ''),
        onRetry: () => ref.invalidate(myThreadsProvider),
      ),
      data: (threads) {
        if (threads.isEmpty) {
          return AppEmptyView(
            icon: Icons.forum_outlined,
            title: 'No chats yet',
            message: 'When a found item matches one of your reports, you can start a chat from it.',
            actionLabel: 'Refresh',
            onAction: () => ref.invalidate(myThreadsProvider),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => ref.refreshTrueOwner(),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: threads.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final thread = threads[index];
              final title = items?.complaintById(thread.complaintId)?.title ?? 'Matched item';
              return ThreadCard(
                thread: thread,
                title: title,
                onTap: () => context.push(AppRoutes.chat, extra: thread),
              );
            },
          ),
        );
      },
    );
  }
}
