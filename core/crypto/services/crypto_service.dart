// crypto_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';

import '../exceptions/crypto_exception.dart';
import '../models/key_pair.dart';
import '../utils/crypto_utils.dart';


class YuCryptoService {
  Future<KeyPair> generateKeyPair() async {
    try {
      final pair = CryptoUtils.generateRSAKeyPair();
      final publicKey = pair.publicKey;
      final privateKey = pair.privateKey;

      final publicKeyString = _encodeRSAPublicKey(publicKey);
      final privateKeyString = _encodeRSAPrivateKey(privateKey);
      return KeyPair(publicKey: publicKeyString, privateKey: privateKeyString);
    } catch (e) {
      throw CryptoException('Error generating RSA key pair', e);
    }
  }

  Future<String> encryptAsymmetric(String data, String publicKey) async {
    try {
      final rsaPublicKey = _decodeRSAPublicKey(publicKey);
      final dataBytes = Uint8List.fromList(utf8.encode(data));
      final encryptedBytes = CryptoUtils.rsaEncrypt(rsaPublicKey, dataBytes);
      return base64.encode(encryptedBytes);
    } catch (e) {
      throw CryptoException('Error encrypting data asymmetrically', e);
    }
  }

  Future<String> decryptAsymmetric(String encryptedData, String privateKey) async {
  try {
    print('Starting asymmetric decryption...');
    print('Encrypted data length: ${encryptedData.length}');
    
    final rsaPrivateKey = _decodeRSAPrivateKey(privateKey);
    print('Private key decoded');
    
    final encryptedBytes = base64.decode(encryptedData);
    print('Encrypted data decoded from base64, length: ${encryptedBytes.length}');
    
    try {
      final decryptedBytes = CryptoUtils.rsaDecrypt(rsaPrivateKey, encryptedBytes);
      print('Data decrypted successfully');
      
      // Вместо преобразования в UTF-8 строку, кодируем байты в base64
      final result = base64.encode(decryptedBytes);
      print('Decrypted data encoded to base64 successfully');
      
      return result;
    } catch (e, stackTrace) {
      print('Error during RSA decryption: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  } catch (e, stackTrace) {
    print('Error in decryptAsymmetric: $e');
    print('Stack trace: $stackTrace');
    throw CryptoException('Error decrypting data asymmetrically', e);
  }
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
}
