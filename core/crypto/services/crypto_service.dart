// crypto_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pointycastle/export.dart';

import '../exceptions/crypto_exception.dart';
import '../models/key_pair.dart';
import '../utils/crypto_utils.dart';

class YuCryptoService {
  // Используем кеш для хранения расшифрованных данных
  final Map<String, String> _decryptionCache = {};
  final int _maxCacheSize = 100;

  Future<KeyPair> generateKeyPair() async {
    try {
      final pair = CryptoUtils.generateRSAKeyPair();
      final publicKey = pair.publicKey;
      final privateKey = pair.privateKey;

      final publicKeyString = _encodeRSAPublicKey(publicKey);
      final privateKeyString = _encodeRSAPrivateKey(privateKey);
      debugPrint('KeyPair generated successfully');
      return KeyPair(publicKey: publicKeyString, privateKey: privateKeyString);
    } catch (e) {
      debugPrint('Error generating RSA key pair: $e');
      throw CryptoException('Error generating RSA key pair', e);
    }
  }

  Future<String> encryptAsymmetric(String data, String publicKey) async {
    try {
      debugPrint('Starting asymmetric encryption of data length: ${data.length}');
      final rsaPublicKey = _decodeRSAPublicKey(publicKey);
      final dataBytes = Uint8List.fromList(utf8.encode(data));
      
      debugPrint('Data encoded to bytes, length: ${dataBytes.length}');
      
      final encryptedBytes = CryptoUtils.rsaEncrypt(rsaPublicKey, dataBytes);
      debugPrint('Data encrypted successfully, length: ${encryptedBytes.length}');
      
      final base64Result = base64.encode(encryptedBytes);
      debugPrint('Encrypted data encoded to base64, length: ${base64Result.length}');
      
      return base64Result;
    } catch (e, stackTrace) {
      debugPrint('Error encrypting data asymmetrically: $e');
      debugPrint('Stack trace: $stackTrace');
      throw CryptoException('Error encrypting data asymmetrically', e);
    }
  }

  Future<String> decryptAsymmetric(String encryptedData, String privateKey, {bool asBase64 = true}) async {
  try {
    debugPrint('Starting asymmetric decryption...');
    debugPrint('Encrypted data length: ${encryptedData.length}');
    debugPrint('Return as base64: $asBase64');
    
    // Проверяем кеш сначала
    final cacheKey = '$encryptedData-$privateKey-$asBase64';
    if (_decryptionCache.containsKey(cacheKey)) {
      debugPrint('Cache hit for decryption');
      return _decryptionCache[cacheKey]!;
    }
    
    // Если нет в кеше, выполняем расшифровку
    final rsaPrivateKey = _decodeRSAPrivateKey(privateKey);
    debugPrint('Private key decoded successfully');
    
    try {
      // Очищаем входные данные от возможных пробелов
      final cleanedEncryptedData = encryptedData.trim();
      
      // Декодируем из base64
      final encryptedBytes = base64.decode(cleanedEncryptedData);
      debugPrint('Encrypted data decoded from base64, length: ${encryptedBytes.length}');
      
      // Расшифровываем
      final decryptedBytes = CryptoUtils.rsaDecrypt(rsaPrivateKey, encryptedBytes);
      debugPrint('Data decrypted successfully, length: ${decryptedBytes.length}');
      
      String result;
      
      if (asBase64) {
        // Возвращаем как base64 для бинарных данных (сессионные ключи)
        result = base64.encode(decryptedBytes);
        debugPrint('Decrypted data encoded to base64, length: ${result.length}');
      } else {
        try {
          // Пытаемся распознать, содержит ли результат уже закодированные Base64 данные
          // Это решает проблему двойного кодирования
          if (_isValidBase64(utf8.decode(decryptedBytes))) {
            // Если данные уже в Base64, возвращаем их напрямую
            result = utf8.decode(decryptedBytes);
            debugPrint('Detected base64 in decrypted data, returning raw');
          } else {
            // Если не Base64, декодируем как UTF-8 для текстовых данных
            result = utf8.decode(decryptedBytes);
            debugPrint('Decrypted data decoded as UTF-8 successfully');
          }
        } catch (e) {
          // Если не UTF-8, все равно возвращаем как base64
          debugPrint('Warning: Could not decode as UTF-8, falling back to base64');
          result = base64.encode(decryptedBytes);
        }
      }
      
      // Сохраняем результат в кеш
      _addToCache(cacheKey, result);
      
      return result;
    } catch (e, stackTrace) {
      debugPrint('Error during standard decryption: $e');
      debugPrint('Stack trace: $stackTrace');
      
      // В случае ошибки возвращаем пустую строку вместо повторной попытки,
      // чтобы избежать зацикливания и неконсистентных результатов
      return "";
    }
  } catch (e, stackTrace) {
    debugPrint('Error in decryptAsymmetric: $e');
    debugPrint('Stack trace: $stackTrace');
    throw CryptoException('Error decrypting data asymmetrically', e);
  }
}
bool _isValidBase64(String str) {
  try {
    // Проверяем, содержит ли строка только допустимые символы Base64
    if (RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(str)) {
      // Пробуем декодировать строку как Base64
      base64.decode(str);
      return true;
    }
    return false;
  } catch (e) {
    return false;
  }
}

  // Метод для добавления результата в кеш
  void _addToCache(String key, String value) {
    // Если кеш переполнен, удаляем самый старый ключ
    if (_decryptionCache.length >= _maxCacheSize) {
      final oldestKey = _decryptionCache.keys.first;
      _decryptionCache.remove(oldestKey);
    }
    
    _decryptionCache[key] = value;
  }

  Future<String> generateRandomBytes(int length) async {
    try {
      final bytes = CryptoUtils.generateSecureRandomBytes(length);
      return base64.encode(bytes);
    } catch (e) {
      throw CryptoException('Error generating random bytes', e);
    }
  }

  Future<String> deriveKey(String input) async {
    try {
      final inputBytes = utf8.encode(input);
      final keyBytes = CryptoUtils.deriveKey(inputBytes, length: 32);
      return base64.encode(keyBytes);
    } catch (e) {
      throw CryptoException('Error deriving key', e);
    }
  }

  Future<String> encryptSymmetric(String data, String key) async {
    try {
      final keyBytes = CryptoUtils.decodeBase64(key);
      final dataBytes = utf8.encode(data);
      final iv = CryptoUtils.generateSecureRandomBytes(16);
      
      final cipher = PaddedBlockCipher('AES/CBC/PKCS7')
        ..init(
          true,
          PaddedBlockCipherParameters<CipherParameters, CipherParameters>(
            ParametersWithIV<KeyParameter>(KeyParameter(keyBytes), iv),
            null,
          ),
        );

      final encrypted = cipher.process(Uint8List.fromList(dataBytes));
      
      final result = Uint8List(iv.length + encrypted.length)
        ..setAll(0, iv)
        ..setAll(iv.length, encrypted);

      return CryptoUtils.encodeBase64(result);
    } catch (e) {
      throw CryptoException('Failed to encrypt data symmetrically', e);
    }
  }

  Future<String> decryptSymmetric(String encryptedData, String key) async {
    try {
      final keyBytes = base64.decode(key);
      final dataBytes = base64.decode(encryptedData);

      // Извлекаем IV из начала данных
      final iv = dataBytes.sublist(0, 16);
      final data = dataBytes.sublist(16);

      final cipher = PaddedBlockCipher('AES/CBC/PKCS7')
        ..init(
          false,
          PaddedBlockCipherParameters<CipherParameters, CipherParameters>(
            ParametersWithIV<KeyParameter>(KeyParameter(keyBytes), iv),
            null,
          ),
        );

      final decrypted = cipher.process(data);
      return utf8.decode(decrypted);
    } catch (e) {
      throw CryptoException('Failed to decrypt data symmetrically', e);
    }
  }

  String _encodeRSAPublicKey(RSAPublicKey publicKey) {
    final keyMap = {
      'modulus': publicKey.modulus?.toRadixString(16),
      'exponent': publicKey.exponent?.toRadixString(16),
    };
    return json.encode(keyMap);
  }

  RSAPublicKey _decodeRSAPublicKey(String keyString) {
    final keyMap = json.decode(keyString);
    final modulus = BigInt.parse(keyMap['modulus'], radix: 16);
    final exponent = BigInt.parse(keyMap['exponent'], radix: 16);
    return RSAPublicKey(modulus, exponent);
  }

  String _encodeRSAPrivateKey(RSAPrivateKey privateKey) {
    final keyMap = {
      'modulus': privateKey.n?.toRadixString(16),
      'exponent': privateKey.exponent?.toRadixString(16),
      'p': privateKey.p?.toRadixString(16),
      'q': privateKey.q?.toRadixString(16),
    };
    return json.encode(keyMap);
  }

  RSAPrivateKey _decodeRSAPrivateKey(String keyString) {
    final keyMap = json.decode(keyString);
    final modulus = BigInt.parse(keyMap['modulus'], radix: 16);
    final exponent = BigInt.parse(keyMap['exponent'], radix: 16);
    final p = keyMap['p'] != null ? BigInt.parse(keyMap['p'], radix: 16) : null;
    final q = keyMap['q'] != null ? BigInt.parse(keyMap['q'], radix: 16) : null;
    return RSAPrivateKey(modulus, exponent, p, q);
  }

  // Метод очистки кеша
  void clearCache() {
    _decryptionCache.clear();
  }
}