import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../core/config/backend_config.dart';
import '../models/chat_thread_model.dart';

/// Live chat over `WebSocket /chat/ws/{thread_id}?email=`.
///
/// Requires `web_socket_channel` in pubspec.yaml.
///
/// Frame shapes, straight from `app/routers/chat.py`:
///   New message      {"type": "message", "id", "threadId", "senderEmail", "text", "sentAt"}
///   Rejected message {"type": "error", "message", ["allowedMessages"]}
///   Phase changed     {"event": "phase_changed", "status": "verification_pending" | "verified" | "handed_over"}
///   (legacy, redundant with phase_changed — ignored here)
///     {"type": "verification_started", "startedAt"}
///     {"type": "verification_completed", "verified"}
///     {"type": "handover_completed", "completedBy", "handedOverAt"}
///
/// The base URL is the same one Settings stores for REST, with the scheme
/// swapped (https -> wss, http -> ws) so switching ngrok tunnels needs no
/// extra configuration.
class ChatSocketService {
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  final _messages = StreamController<ChatMessage>.broadcast();
  final _errors = StreamController<String>.broadcast();

  /// Backend `status` value from a `phase_changed` event
  /// ("verification_pending" | "verified" | "handed_over") — note this is
  /// NOT the same string as [ChatThread.status] ("verifying" for the
  /// pending case); callers map it, they don't compare it directly.
  final _phaseChanges = StreamController<String>.broadcast();

  Stream<ChatMessage> get messages => _messages.stream;
  Stream<String> get errors => _errors.stream;
  Stream<String> get phaseChanges => _phaseChanges.stream;
  bool get isConnected => _channel != null;

  static Uri? _socketUri(String baseUrl, String threadId, String email) {
    final base = Uri.tryParse(baseUrl);
    if (base == null) return null;
    final scheme = base.scheme == 'https' ? 'wss' : 'ws';
    final threadSegment = Uri.encodeComponent(threadId).replaceAll('%3A', ':');
    return Uri.parse(
      '$scheme://${base.authority}${base.path}/chat/ws/$threadSegment'
      '?email=${Uri.encodeQueryComponent(email)}',
    );
  }

  Future<bool> connect({required String threadId, required String email}) async {
    await disconnect();

    final baseUrl = await BackendConfig.getBaseUrl();
    if (baseUrl == null || baseUrl.isEmpty) {
      _errors.add('Backend URL not set. Add your ngrok URL in Settings first.');
      return false;
    }

    final uri = _socketUri(baseUrl, threadId, email);
    if (uri == null) {
      _errors.add('Backend URL looks invalid. Check it in Settings.');
      return false;
    }

    try {
      final channel = WebSocketChannel.connect(uri);
      _channel = channel;
      _sub = channel.stream.listen(
        _handleFrame,
        onError: (Object e) => _errors.add('Chat connection error: $e'),
        onDone: () {
          // The server closes with code 4403 if the thread doesn't exist
          // or this email isn't a participant — surface that distinctly
          // rather than a generic disconnect.
          final code = _channel?.closeCode;
          _channel = null;
          _errors.add(code == 4403 ? 'You are not part of this chat.' : 'Chat disconnected.');
        },
        cancelOnError: false,
      );
      return true;
    } catch (e) {
      _channel = null;
      _errors.add('Could not connect to chat: $e');
      return false;
    }
  }

  void _handleFrame(dynamic frame) {
    Map<String, dynamic> decoded;
    try {
      final parsed = jsonDecode(frame.toString());
      if (parsed is! Map<String, dynamic>) return;
      decoded = parsed;
    } catch (_) {
      return; // Not JSON — ignore rather than surface noise to the user.
    }

    final event = decoded['event'];
    if (event == 'phase_changed') {
      final status = decoded['status']?.toString();
      if (status != null) _phaseChanges.add(status);
      return;
    }

    final type = decoded['type'];
    if (type == 'message') {
      _messages.add(ChatMessage.fromJson(decoded));
      return;
    }
    if (type == 'error') {
      final base = decoded['message']?.toString() ?? 'Message not allowed.';
      final allowed = decoded['allowedMessages'];
      if (allowed is List && allowed.isNotEmpty) {
        _errors.add('$base\n\u2022 ${allowed.join('\n\u2022 ')}');
      } else {
        _errors.add(base);
      }
      return;
    }
    // verification_started / verification_completed / handover_completed:
    // redundant with the phase_changed event above — nothing to do.
  }

  /// Send is intentionally dumb: the screen decides whether the current
  /// phase permits this text at all. The server re-validates regardless
  /// and will bounce back a `type: "error"` frame if it doesn't.
  void send(String text) {
    final channel = _channel;
    if (channel == null) {
      _errors.add('Not connected to chat.');
      return;
    }
    channel.sink.add(jsonEncode({'text': text}));
  }

  Future<void> disconnect() async {
    await _sub?.cancel();
    _sub = null;
    await _channel?.sink.close();
    _channel = null;
  }

  Future<void> dispose() async {
    await disconnect();
    await _messages.close();
    await _errors.close();
    await _phaseChanges.close();
  }
}

final chatSocketServiceProvider = Provider.autoDispose<ChatSocketService>((ref) {
  final service = ChatSocketService();
  ref.onDispose(service.dispose);
  return service;
});
