// lib/features/chat/domain/models/chat_key.dart
class ChatKey {
  final String chatId;
  final String userId;
  final String publicKey;
  final String privateKey;
  final String? remotePublicKey;
  final String partialKey;
  final String? symmetricKey;
  final bool isComplete;

  const ChatKey({
    required this.chatId,
    required this.userId,
    required this.publicKey,
    required this.privateKey,
    required this.partialKey,
    this.remotePublicKey,
    this.symmetricKey,
    this.isComplete = false,
  });

  ChatKey copyWith({
    String? chatId,
    String? userId,
    String? publicKey,
    String? privateKey,
    String? remotePublicKey,
    String? partialKey,
    String? symmetricKey,
    bool? isComplete,
  }) {
    return ChatKey(
      chatId: chatId ?? this.chatId,
      userId: userId ?? this.userId,
      publicKey: publicKey ?? this.publicKey,
      privateKey: privateKey ?? this.privateKey,
      remotePublicKey: remotePublicKey ?? this.remotePublicKey,
      partialKey: partialKey ?? this.partialKey,
      symmetricKey: symmetricKey ?? this.symmetricKey,
      isComplete: isComplete ?? this.isComplete,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'chatId': chatId,
      'userId': userId,
      'publicKey': publicKey,
      'privateKey': privateKey,
      'remotePublicKey': remotePublicKey,
      'partialKey': partialKey,
      'symmetricKey': symmetricKey,
      'isComplete': isComplete,
    };
  }

  factory ChatKey.fromJson(Map<String, dynamic> json) {
    return ChatKey(
      chatId: json['chatId'],
      userId: json['userId'],
      publicKey: json['publicKey'],
      privateKey: json['privateKey'],
      remotePublicKey: json['remotePublicKey'],
      partialKey: json['partialKey'],
      symmetricKey: json['symmetricKey'],
      isComplete: json['isComplete'],
    );
  }
}