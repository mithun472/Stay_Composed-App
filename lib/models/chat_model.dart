import 'package:equatable/equatable.dart';
import 'enums.dart';

enum MessageSender { self, other, system }

class ChatMessage extends Equatable {
  final String id;
  final String chatId;
  final MessageSender sender;
  final String senderName;
  final String text;
  final DateTime sentAt;

  const ChatMessage({
    required this.id,
    required this.chatId,
    required this.sender,
    required this.senderName,
    required this.text,
    required this.sentAt,
  });

  @override
  List<Object?> get props => [id, chatId, sender, text, sentAt];
}

class Chat extends Equatable {
  final String id;
  final String verificationRequestId;
  final String objectName;
  final String ownerId;
  final String ownerName;
  final String finderId;
  final String finderName;
  final ChatStatus status;
  final DateTime expiresAt;
  final List<ChatMessage> messages;

  const Chat({
    required this.id,
    required this.verificationRequestId,
    required this.objectName,
    required this.ownerId,
    required this.ownerName,
    required this.finderId,
    required this.finderName,
    this.status = ChatStatus.active,
    required this.expiresAt,
    this.messages = const [],
  });

  Duration get timeRemaining {
    final remaining = expiresAt.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  Chat copyWith({ChatStatus? status, List<ChatMessage>? messages}) {
    return Chat(
      id: id,
      verificationRequestId: verificationRequestId,
      objectName: objectName,
      ownerId: ownerId,
      ownerName: ownerName,
      finderId: finderId,
      finderName: finderName,
      status: status ?? this.status,
      expiresAt: expiresAt,
      messages: messages ?? this.messages,
    );
  }

  @override
  List<Object?> get props => [id, status, messages.length];
}
