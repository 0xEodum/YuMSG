class ServerChannel {
  final String channelId;
  final String publicKey;
  final String privateKey;
  String? sessionKey;
  final DateTime createdAt;
  
  bool get isExpired => 
    DateTime.now().difference(createdAt).inMinutes >= 5;

  ServerChannel({
    required this.channelId,
    required this.publicKey,
    required this.privateKey,
    this.sessionKey,  
  }) : createdAt = DateTime.now();
}