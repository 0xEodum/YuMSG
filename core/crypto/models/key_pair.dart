class KeyPair {
  final String publicKey;
  final String privateKey;

  const KeyPair({
    required this.publicKey,
    required this.privateKey,
  });

  @override
  String toString() => 'KeyPair(publicKey: $publicKey)';
}