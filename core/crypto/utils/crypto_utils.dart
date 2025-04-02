// crypto_utils.dart
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
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
    try {
      debugPrint('Starting RSA encryption...');
      
      // Используем PKCS1 padding для совместимости
      final cipher = PKCS1Encoding(RSAEngine())
        ..init(true, PublicKeyParameter<RSAPublicKey>(publicKey));
      
      // Определяем максимальный размер блока для шифрования
      final keyBitLength = publicKey.modulus?.bitLength ?? 2048;
      final maxBlockSize = (keyBitLength ~/ 8) - 11; // PKCS1 padding требует 11 байт
      
      debugPrint('RSA encryption: data length: ${dataToEncrypt.length}, max block size: $maxBlockSize');
      
      // Если данные меньше максимального размера блока, шифруем их целиком
      if (dataToEncrypt.length <= maxBlockSize) {
        return cipher.process(dataToEncrypt);
      }
      
      // Иначе шифруем по блокам
      final output = <int>[];
      for (var offset = 0; offset < dataToEncrypt.length; offset += maxBlockSize) {
        final end = math.min(offset + maxBlockSize, dataToEncrypt.length);
        final block = dataToEncrypt.sublist(offset, end);
        
        final encrypted = cipher.process(block);
        output.addAll(encrypted);
      }
      
      return Uint8List.fromList(output);
    } catch (e, stackTrace) {
      debugPrint('Error in RSA encryption: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  static Uint8List rsaDecrypt(RSAPrivateKey privateKey, Uint8List dataToDecrypt) {
    try {
      debugPrint('Starting RSA decryption...');
      debugPrint('Input data length: ${dataToDecrypt.length}');
      debugPrint('Private key modulus length: ${privateKey.n?.bitLength}');
      
      // Используем PKCS1 padding для совместимости
      final cipher = PKCS1Encoding(RSAEngine())
        ..init(false, PrivateKeyParameter<RSAPrivateKey>(privateKey));
      
      debugPrint('Cipher initialized');
      
      // Определяем размер блока для дешифрования
      final keyBitLength = privateKey.n?.bitLength ?? 2048;
      final blockSize = keyBitLength ~/ 8;
      
      debugPrint('RSA block size for decryption: $blockSize');
      
      // Проверяем, соответствует ли размер входных данных размеру ключа
      if (dataToDecrypt.length == blockSize) {
        // Если данные точно соответствуют размеру блока, дешифруем их целиком
        try {
          return cipher.process(dataToDecrypt);
        } catch (e) {
          debugPrint('Error in single block decryption: $e');
          rethrow;
        }
      }
      
      // Если данные не кратны размеру блока, это может быть проблемой
      if (dataToDecrypt.length % blockSize != 0) {
        debugPrint('Warning: Input data length is not a multiple of block size');
        
        // Если данные короче блока, пытаемся обработать их как есть
        if (dataToDecrypt.length < blockSize) {
          try {
            return cipher.process(dataToDecrypt);
          } catch (e) {
            debugPrint('Error decrypting data shorter than block size: $e');
            rethrow;
          }
        }
        
        // Если данные длиннее блока, но не кратны ему, обрабатываем только полные блоки
        debugPrint('Processing only complete blocks');
      }
      
      // Дешифруем по блокам
      final output = <int>[];
      
      for (var offset = 0; offset < dataToDecrypt.length; offset += blockSize) {
        // Обрабатываем только полные блоки
        if (offset + blockSize <= dataToDecrypt.length) {
          try {
            final block = dataToDecrypt.sublist(offset, offset + blockSize);
            final decrypted = cipher.process(block);
            output.addAll(decrypted);
            debugPrint('Block at offset $offset processed, size: ${decrypted.length}');
          } catch (e) {
            debugPrint('Error processing block at offset $offset: $e');
            // При ошибке в одном блоке продолжаем с другими блоками
          }
        }
      }
      
      if (output.isEmpty) {
        throw Exception('No blocks could be decrypted');
      }
      
      final result = Uint8List.fromList(output);
      debugPrint('Decryption completed, result length: ${result.length}');
      return result;
    } catch (e, stackTrace) {
      debugPrint('Error in RSA decryption: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
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