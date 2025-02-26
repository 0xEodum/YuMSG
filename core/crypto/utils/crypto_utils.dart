// crypto_utils.dart
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:pointycastle/export.dart';

class CryptoUtils {
  static String encodeBase64(Uint8List data) {
    return base64.encode(data);
  }

  static Uint8List decodeBase64(String data) {
    return base64.decode(data);
  }

  static AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> generateRSAKeyPair({int bitLength = 2048}) {
    final keyParams = RSAKeyGeneratorParameters(BigInt.parse('65537'), bitLength, 64);
    final secureRandom = _getSecureRandom();
    final rngParams = ParametersWithRandom(keyParams, secureRandom);

    final generator = RSAKeyGenerator();
    generator.init(rngParams);

    final pair = generator.generateKeyPair();
    final publicKey = pair.publicKey as RSAPublicKey;
    final privateKey = pair.privateKey as RSAPrivateKey;

    return AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey>(publicKey, privateKey);
  }

  static Uint8List rsaEncrypt(RSAPublicKey publicKey, Uint8List dataToEncrypt) {
    final cipher = PKCS1Encoding(RSAEngine())
      ..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));
    return _processInBlocks(cipher, dataToEncrypt);
  }

  static Uint8List rsaDecrypt(RSAPrivateKey privateKey, Uint8List dataToDecrypt) {
  try {
    print('Starting RSA decryption...');
    print('Input data length: ${dataToDecrypt.length}');
    print('Private key modulus length: ${privateKey.n?.bitLength}');
    
    final cipher = PKCS1Encoding(RSAEngine())
      ..init(false, PrivateKeyParameter<RSAPrivateKey>(privateKey));
      
    print('Cipher initialized');
    
    final result = _processInBlocks(cipher, dataToDecrypt);
    print('Decryption completed, result length: ${result.length}');
    
    return result;
  } catch (e, stackTrace) {
    print('Error in RSA decryption: $e');
    print('Stack trace: $stackTrace');
    rethrow;
  }
}

  static Uint8List _processInBlocks(AsymmetricBlockCipher engine, Uint8List input) {
    final numBlocks = (input.length / engine.inputBlockSize).ceil();
    final output = <int>[];

    for (var i = 0; i < numBlocks; i++) {
      final start = i * engine.inputBlockSize;
      final end = math.min(start + engine.inputBlockSize, input.length);
      final block = input.sublist(start, end);
      output.addAll(engine.process(block));
    }

    return Uint8List.fromList(output);
  }

  static Uint8List generateSecureRandomBytes(int length) {
    final secureRandom = _getSecureRandom();
    return secureRandom.nextBytes(length);
  }

  static SecureRandom _getSecureRandom() {
    final secureRandom = FortunaRandom();
    final seedSource = math.Random.secure();
    final seeds = <int>[];
    for (var i = 0; i < 32; i++) {
      seeds.add(seedSource.nextInt(256));
    }
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));
    return secureRandom;
  }

  static Uint8List deriveKey(List<int> keyMaterial, {int length = 32}) {
    final digest = Digest("SHA-256");
    var hash = digest.process(Uint8List.fromList(keyMaterial));

    if (length == hash.length) {
      return hash;
    } else if (length < hash.length) {
      return hash.sublist(0, length);
    } else {
      var output = <int>[];
      var counter = 0;
      while (output.length < length) {
        final data = Uint8List.fromList(hash + [counter]);
        final block = digest.process(data);
        output.addAll(block);
        counter++;
      }
      return Uint8List.fromList(output.sublist(0, length));
    }
  }
}
