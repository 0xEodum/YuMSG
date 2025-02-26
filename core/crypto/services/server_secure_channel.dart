import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../exceptions/crypto_exception.dart';
import '../models/server_channel.dart';
import 'crypto_service.dart';

class ServerSecureChannel {
  final YuCryptoService _cryptoService;
  ServerChannel? _currentChannel;
  
  ServerSecureChannel({required YuCryptoService cryptoService}) 
    : _cryptoService = cryptoService;

  Future<void> establishSecureConnection() async {
    // Генерируем пару ключей для текущей сессии
    final keyPair = await _cryptoService.generateKeyPair();
    // Создаем новый ID канала
    final channelId = const Uuid().v4();
    
    _currentChannel = ServerChannel(
      channelId: channelId,
      publicKey: keyPair.publicKey,
      privateKey: keyPair.privateKey,
    );
  }

  Future<String> encryptData(String data) async {
    _validateChannel();

    if (_currentChannel!.sessionKey == null) {
      throw const CryptoException(
          'Secure channel not fully established - missing session key');
    }

    // Декодируем сессионный ключ из base64 перед использованием
    final keyBytes = base64.decode(_currentChannel!.sessionKey!);
    return _cryptoService.encryptSymmetric(data, _currentChannel!.sessionKey!);
  }

  Future<String> decryptData(String data) async {
    _validateChannel();

    if (_currentChannel!.sessionKey == null) {
      throw const CryptoException(
          'Secure channel not fully established - missing session key');
    }

    try {
      // Декодируем сессионный ключ из base64 перед использованием
      final keyBytes = base64.decode(_currentChannel!.sessionKey!);

      // Преобразуем ключ обратно в base64 строку для совместимости с API
      final keyBase64 = base64.encode(keyBytes);

      return _cryptoService.decryptSymmetric(data, keyBase64);
    } catch (e) {
      throw CryptoException('Failed to decrypt data with session key', e);
    }
  }

  Future<void> setSessionKey(String encryptedKey) async {
  try {
    print('Starting session key setup...');
    _validateChannel();
    print('Channel validated');
    
    print('Encrypted key length: ${encryptedKey.length}');
    print('Private key available: ${_currentChannel?.privateKey != null}');
    
    // Расшифровываем сессионный ключ приватным ключом канала
    try {
      final sessionKey = await _cryptoService.decryptAsymmetric(
        encryptedKey,
        _currentChannel!.privateKey,
      );
      print('Session key decrypted successfully');
      
      _currentChannel!.sessionKey = sessionKey;
      print('Session key stored in channel');
    } catch (e, stackTrace) {
      print('Error decrypting session key: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  } catch (e, stackTrace) {
    print('Error in setSessionKey: $e');
    print('Stack trace: $stackTrace');
    rethrow;
  }
}

  String get channelId => _currentChannel?.channelId ?? '';
  String get publicKey => _currentChannel?.publicKey ?? '';

  void _validateChannel() {
    if (_currentChannel == null) {
      throw const CryptoException('Secure channel not established');
    }
    
    if (_currentChannel!.isExpired) {
      throw const CryptoException('Secure channel expired');
    }
  }

  void dispose() {
    _currentChannel = null;
  }
}