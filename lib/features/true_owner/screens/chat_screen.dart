import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/routes/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/state_placeholders.dart';
import '../../../models/chat_thread_model.dart';
import '../../../services/chat_socket_service.dart';
import '../../../services/true_owner_service.dart';
import '../providers/true_owner_providers.dart';
import '../widgets/true_owner_widgets.dart';

/// WhatsApp-style thread between owner and finder, with the composer
/// swapped out per [ChatPhase]:
///
///   preVerification -> canned prompt chips + free text (backend already
///                       accepts arbitrary text pre-verification; the chips
///                       are just quick-start suggestions, not a lock)
///   verifying       -> locked, CTA to answer the challenge questions
///   verified        -> free text + complete-handover action
///   handedOver      -> read-only
class ChatScreen extends ConsumerStatefulWidget {
  final ChatThread thread;
  const ChatScreen({super.key, required this.thread});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scroll = ScrollController();
  final _composer = TextEditingController();

  late ChatThread _thread;
  List<ChatMessage> _messages = [];
  String? _error;
  bool _loading = true;
  bool _sending = false;

  StreamSubscription<ChatMessage>? _msgSub;
  StreamSubscription<String>? _errSub;
  StreamSubscription<String>? _phaseSub;
  StreamSubscription<Set<String>>? _presenceSub;
  Timer? _phasePoll;
  Set<String> _onlineEmails = {};

  String get _email => ref.read(currentEmailProvider) ?? '';

  /// Raw names come as "<regno> <actual name> <dept code>", e.g.
  /// "24SUCA11 Mithun Maharajan K B.C.A" — regno and dept sandwich the
  /// real name. Strip a leading regno-shaped token (digits+letters+digits,
  /// e.g. 24SUCA11) and a trailing dept-code token (short, all caps,
  /// optionally dotted, e.g. B.C.A, MBA, M.SC) and keep only the middle.
  static String _cleanName(String raw) {
    var working = raw.trim();
    // Backend prefixes some names with a generic "Campus Member" label
    // (e.g. pre-verification masking) — strip that label only, keep
    // whatever follows (masked or not) as-is.
    working = working.replaceFirst(RegExp(r'^Campus Member\s+', caseSensitive: false), '');

    final tokens = working.split(RegExp(r'\s+'));
    if (tokens.isEmpty || working.isEmpty) return working;

    final regNo = RegExp(r'^\d{2}[A-Za-z]{2,8}\d{1,4}$');
    final deptCode = RegExp(r'^[A-Z](\.[A-Z]){1,4}\.?$|^[A-Z]{2,6}$');

    var start = 0;
    var end = tokens.length;
    if (start < end && regNo.hasMatch(tokens[start])) start++;
    if (end > start && deptCode.hasMatch(tokens[end - 1])) end--;

    final middle = tokens.sublist(start, end);
    return middle.isEmpty ? working : middle.join(' ');
  }

  @override
  void initState() {
    super.initState();
    _thread = widget.thread;
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _msgSub?.cancel();
    _errSub?.cancel();
    _phaseSub?.cancel();
    _presenceSub?.cancel();
    _phasePoll?.cancel();
    _scroll.dispose();
    _composer.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      await _loadHistory();
      await _connectSocket();
    } catch (e) {
      // Anything unexpected here would otherwise escape as an unhandled
      // async error (since nothing awaits _init()) and show Flutter's raw
      // error screen instead of our own AppErrorView.
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
      return;
    }
    // Primary path: the server pushes a `phase_changed` event the instant
    // the finder starts verification or a claim/handover completes (see
    // ChatSocketService.phaseChanges). The poll below is only a safety net
    // for a dropped socket, so it can run slowly.
    _phasePoll = Timer.periodic(const Duration(seconds: 20), (_) => _refreshPhase());
  }

  /// Backend event status -> local thread status. Deliberately not the
  /// same strings: the socket event says "verification_pending" while
  /// ChatThread/REST use "verifying" for that phase.
  static const Map<String, String> _eventStatusToThreadStatus = {
    'verification_pending': 'verifying',
    'verified': 'verified',
    'handed_over': 'handed_over',
  };

  void _applyPhaseEvent(String eventStatus) {
    final mapped = _eventStatusToThreadStatus[eventStatus];
    if (mapped == null || !mounted) return;
    final now = DateTime.now();
    setState(() {
      _thread = _thread.copyWith(
        status: mapped,
        verificationStartedAt: mapped == 'verifying' ? now : null,
        handedOverAt: mapped == 'handed_over' ? now : null,
      );
    });
    // A phase flip usually means the composer/locking rules changed and,
    // for "verified", that a new system message may exist — refresh.
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final result = await ref.read(trueOwnerServiceProvider).getMessages(_thread.threadId, _email);
    if (!mounted) return;
    result.when(
      success: (messages) => setState(() {
        _messages = messages;
        _loading = false;
        _error = null;
      }),
      failure: (message) => setState(() {
        _loading = false;
        _error = message;
      }),
    );
    _scrollToEnd();
  }

  Future<void> _connectSocket() async {
    // Reconnect can be triggered mid-session (see _send); drop the old
    // subscriptions first so they don't pile up on a fresh channel.
    await _msgSub?.cancel();
    await _errSub?.cancel();
    await _phaseSub?.cancel();
    await _presenceSub?.cancel();

    final socket = ref.read(chatSocketServiceProvider);
    _msgSub = socket.messages.listen((message) {
      if (!mounted) return;
      // Real msg with this id already in list (rare double-broadcast) — skip.
      if (message.id.isNotEmpty && _messages.any((m) => m.id == message.id)) return;

      // Own message echoing back from server: id here is 'local-...'
      // (optimistic bubble) vs real 'msg-...' (server id) — they never
      // match on id, so the old check let both sit in the list forever.
      // That's the double-send: "Hello" shows once from _send()'s local
      // bubble, once from this echo. Swap the placeholder for the real
      // one instead of appending a second bubble.
      if (message.senderEmail.toLowerCase() == _email.toLowerCase()) {
        final localIdx = _messages.indexWhere(
          (m) => m.id.startsWith('local-') && m.text == message.text,
        );
        if (localIdx != -1) {
          setState(() {
            final updated = [..._messages];
            updated[localIdx] = message;
            _messages = updated;
          });
          _scrollToEnd();
          return;
        }
      }
      setState(() => _messages = [..._messages, message]);
      _scrollToEnd();
    });
    _errSub = socket.errors.listen((message) {
      if (mounted) _snack(message);
    });
    _phaseSub = socket.phaseChanges.listen(_applyPhaseEvent);
    _presenceSub = socket.presence.listen((emails) {
      if (mounted) setState(() => _onlineEmails = emails);
    });
    await socket.connect(threadId: _thread.threadId, email: _email);
  }

  /// The provider is `.autoDispose` and this screen only ever `ref.read`s
  /// it — a read alone registers no listener, so without this watch the
  /// provider (and its socket) gets torn down again right after connect,
  /// on the very next frame. That's what produced "Reconnecting..." on
  /// every quick-message tap: the socket was already dead by the time you
  /// tapped. Watching here (result unused) just keeps a listener alive
  /// for as long as this screen is mounted, which is exactly the socket's
  /// intended lifetime.
  void _keepSocketAlive() => ref.watch(chatSocketServiceProvider);

  Future<void> _refreshPhase() async {
    final result = await ref.read(trueOwnerServiceProvider).getMyThreads(_email);
    if (!mounted) return;
    result.when(
      success: (threads) {
        for (final t in threads) {
          if (t.threadId == _thread.threadId && t.phase != _thread.phase) {
            setState(() => _thread = t);
            _loadHistory();
          }
        }
      },
      failure: (_) {}, // Silent — polling failures shouldn't nag mid-chat.
    );
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _send(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _sending) return;

    final socket = ref.read(chatSocketServiceProvider);
    if (!socket.isConnected) {
      _snack('Reconnecting to chat...');
      _connectSocket();
      return;
    }

    setState(() => _sending = true);
    socket.send(trimmed);
    _composer.clear();

    // Optimistic bubble so the thread feels instant; the server echo
    // replaces nothing (ids differ) but ordering stays correct.
    final local = ChatMessage(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      threadId: _thread.threadId,
      senderEmail: _email,
      text: trimmed,
      sentAt: DateTime.now(),
    );
    setState(() {
      _messages = [..._messages, local];
      _sending = false;
    });
    _scrollToEnd();
  }

  bool get _isFounder =>
      _email.isNotEmpty && _email.toLowerCase() == _thread.founderEmail.toLowerCase();

  Future<void> _openClaim() async {
    // Guard: only the claimant answers the challenge. The finder set the
    // questions — they must never be the one submitting answers to them.
    if (_isFounder) return;
    final changed = await context.push<bool>(AppRoutes.claim, extra: _thread);
    if (changed == true && mounted) {
      await _refreshPhase();
      ref.refreshTrueOwner();
    }
  }

  Future<void> _completeHandover() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Handover complete?'),
        content: const Text(
          'Confirm only once the item is physically in your hands. This closes '
          'both reports and ends this chat permanently.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Not yet')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (confirmed != true) return;

    final result = await ref.read(trueOwnerServiceProvider).completeHandover(_thread.threadId, _email);
    if (!mounted) return;
    result.when(
      success: (_) {
        ref.refreshTrueOwner();
        setState(() => _thread = _thread.copyWith(status: 'handed_over', handedOverAt: DateTime.now()));
        _snack('Handover recorded. This chat is now closed.');
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
    _keepSocketAlive();
    final phase = _thread.phase;
    final otherEmail = _email.toLowerCase() == _thread.founderEmail.toLowerCase()
        ? _thread.claimantEmail
        : _thread.founderEmail;
    final isOtherOnline = _onlineEmails.contains(otherEmail.toLowerCase());
    // Show the OTHER party, never me — I already know who I am. Role is
    // whichever the other email actually matches on the thread, never
    // hardcoded, so it can't show my own label back to me.
    final otherIsFounder = otherEmail.toLowerCase() == _thread.founderEmail.toLowerCase();
    final otherRoleLabel = otherIsFounder ? 'Founder' : 'Claimant';
    final otherName = _cleanName(_thread.nameForEmail(otherEmail));
    final otherDisplay = (otherName.isNotEmpty && otherName != otherEmail)
        ? '$otherRoleLabel: $otherName'
        : otherRoleLabel;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              otherDisplay,
              style: const TextStyle(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(phase.label, style: AppTextStyles.caption),
                if (phase != ChatPhase.handedOver) ...[
                  const Text('  \u2022  ', style: AppTextStyles.caption),
                  Icon(
                    Icons.circle,
                    size: 8,
                    color: isOtherOnline ? AppColors.success : AppColors.textDisabled,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isOtherOnline ? 'Online' : 'Offline',
                    style: AppTextStyles.caption,
                  ),
                ],
              ],
            ),
          ],
        ),
        actions: [
          if (phase == ChatPhase.verified)
            IconButton(
              tooltip: 'Complete handover',
              icon: const Icon(Icons.check_circle_outline_rounded),
              onPressed: _completeHandover,
            ),
        ],
      ),
      body: Column(
        children: [
          _PhaseBanner(phase: phase, onAnswer: _openClaim, isFounder: _isFounder),
          Expanded(
            child: _loading
                ? const AppLoadingView(message: 'Loading chat...')
                : _error != null
                    ? AppErrorView(message: _error!, onRetry: _loadHistory)
                    : _messages.isEmpty
                        ? AppEmptyView(
                            icon: Icons.forum_outlined,
                            title: 'Say hello',
                            message: 'Use one of the prompts below to start. '
                                'Never share your secret details in chat.',
                          )
                        : ListView.builder(
                            controller: _scroll,
                            padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final m = _messages[index];
                              return _Bubble(message: m, isMine: m.isMine(_email));
                            },
                          ),
          ),
          _Composer(
            phase: phase,
            controller: _composer,
            onSend: _send,
            onAnswer: _openClaim,
            isFounder: _isFounder,
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;
  const _Bubble({required this.message, required this.isMine});

  String get _time {
    final t = message.sentAt;
    if (t == null) return '';
    final local = t.toLocal();
    final h = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m ${local.hour >= 12 ? "PM" : "AM"}';
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 7),
        decoration: BoxDecoration(
          color: isMine ? AppColors.trueOwner : AppColors.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isMine ? 14 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 14),
          ),
          border: isMine ? null : Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.text,
              style: AppTextStyles.body.copyWith(
                color: isMine ? Colors.white : AppColors.textPrimary,
              ),
            ),
            if (_time.isNotEmpty)
              Text(
                _time,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 10,
                  color: isMine ? Colors.white70 : AppColors.textDisabled,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PhaseBanner extends StatelessWidget {
  final ChatPhase phase;
  final VoidCallback onAnswer;
  final bool isFounder;
  const _PhaseBanner({required this.phase, required this.onAnswer, this.isFounder = false});

  @override
  Widget build(BuildContext context) {
    final (bg, fg, icon, text) = switch (phase) {
      ChatPhase.preVerification => (
          AppColors.infoLight,
          AppColors.info,
          Icons.shield_outlined,
          'Identities are hidden. Never share your secret details here \u2014 you\u2019ll enter them in the verification step.',
        ),
      ChatPhase.verifying => isFounder
          ? (
              AppColors.warningLight,
              AppColors.warning,
              Icons.lock_outline_rounded,
              'Waiting for the claimant to answer your challenge questions.',
            )
          : (
              AppColors.warningLight,
              AppColors.warning,
              Icons.lock_outline_rounded,
              'The finder started verification. Chat is locked until you answer their questions.',
            ),
      ChatPhase.verified => (
          AppColors.successLight,
          AppColors.success,
          Icons.verified_outlined,
          'Ownership verified. Arrange a handover in a public campus spot.',
        ),
      ChatPhase.handedOver => (
          AppColors.surfaceMuted,
          AppColors.textSecondary,
          Icons.task_alt_rounded,
          'Handover complete. This chat is closed.',
        ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: bg,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: AppTextStyles.bodyMuted)),
          if (phase == ChatPhase.verifying && !isFounder)
            TextButton(onPressed: onAnswer, child: const Text('Answer')),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final ChatPhase phase;
  final TextEditingController controller;
  final void Function(String text) onSend;
  final VoidCallback onAnswer;
  final bool isFounder;

  const _Composer({
    required this.phase,
    required this.controller,
    required this.onSend,
    required this.onAnswer,
    this.isFounder = false,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: switch (phase) {
          ChatPhase.preVerification => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CannedComposer(onSend: onSend, isFounder: isFounder),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'Message (never share secret details)',
                          filled: true,
                          fillColor: AppColors.surfaceMuted,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(24)),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onSubmitted: onSend,
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      backgroundColor: AppColors.trueOwner,
                      child: IconButton(
                        icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                        onPressed: () => onSend(controller.text),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ChatPhase.verifying => isFounder
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.hourglass_empty_rounded, size: 16, color: AppColors.textDisabled),
                    const SizedBox(width: 8),
                    Text('Waiting for claimant to verify.', style: AppTextStyles.bodyMuted),
                  ],
                )
              : SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onAnswer,
                    icon: const Icon(Icons.fact_check_outlined, size: 18),
                    label: const Text('Answer verification questions'),
                  ),
                ),
          ChatPhase.verified => Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Message',
                      filled: true,
                      fillColor: AppColors.surfaceMuted,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(24)),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: onSend,
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: AppColors.trueOwner,
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    onPressed: () => onSend(controller.text),
                  ),
                ),
              ],
            ),
          ChatPhase.handedOver => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.textDisabled),
                const SizedBox(width: 8),
                Text('This chat is closed.', style: AppTextStyles.bodyMuted),
              ],
            ),
        },
      ),
    );
  }
}

/// Pre-verification composer: tap-to-send prompts, no free text field.
class _CannedComposer extends StatelessWidget {
  final void Function(String text) onSend;
  final bool isFounder;
  const _CannedComposer({required this.onSend, this.isFounder = false});

  @override
  Widget build(BuildContext context) {
    final prompts = isFounder ? CannedPrompts.forFinder : CannedPrompts.forOwner;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.shield_outlined, size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              isFounder
                  ? 'Finder templates (Questions & Answers)'
                  : 'Owner templates (Questions & Answers)',
              style: AppTextStyles.caption,
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: prompts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final prompt = prompts[index];
              return ActionChip(
                label: Text(prompt),
                backgroundColor: AppColors.trueOwnerLight,
                side: const BorderSide(color: AppColors.border),
                onPressed: () => onSend(prompt),
              );
            },
          ),
        ),
      ],
    );
  }
}