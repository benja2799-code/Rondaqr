import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PinAuthService extends ChangeNotifier {
  PinAuthService._internal();

  static final PinAuthService instance = PinAuthService._internal();

  static const String _prefix = 'rondaqr_pin_hash_';
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  String? _preparedUserId;
  bool _preparedUserHasPin = false;
  String? _unlockedUserId;

  bool get hasPreparedPin => _preparedUserHasPin;

  bool get isPreparedUserUnlocked {
    final String? userId = _preparedUserId;
    return userId != null && userId.isNotEmpty && _unlockedUserId == userId;
  }

  Future<void> prepareForUser(String? userId) async {
    final String normalizedUserId = userId?.trim() ?? '';
    _preparedUserId = normalizedUserId.isEmpty ? null : normalizedUserId;
    _preparedUserHasPin = normalizedUserId.isEmpty
        ? false
        : await hasPinForUser(normalizedUserId);

    if (_unlockedUserId != normalizedUserId) {
      _unlockedUserId = null;
    }

    notifyListeners();
  }

  bool shouldRequirePinFor(String? userId) {
    final String normalizedUserId = userId?.trim() ?? '';
    return normalizedUserId.isNotEmpty &&
        _preparedUserId == normalizedUserId &&
        _preparedUserHasPin &&
        _unlockedUserId != normalizedUserId;
  }

  Future<bool> hasPinForUser(String userId) async {
    final String saved = await _storage.read(key: _keyForUser(userId)) ?? '';
    return saved.trim().isNotEmpty;
  }

  Future<void> createOrUpdatePin({
    required String userId,
    required String pin,
  }) async {
    _validatePin(pin);

    final String normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      throw StateError('No existe usuario activo para guardar el PIN.');
    }

    final String salt = _generateSalt();
    final String hash = _hashPin(
      userId: normalizedUserId,
      salt: salt,
      pin: pin,
    );

    await _storage.write(
      key: _keyForUser(normalizedUserId),
      value: 'v1:$salt:$hash',
    );

    _preparedUserId = normalizedUserId;
    _preparedUserHasPin = true;
    _unlockedUserId = normalizedUserId;
    notifyListeners();
  }

  Future<bool> verifyPin({required String userId, required String pin}) async {
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      return false;
    }

    final String normalizedUserId = userId.trim();
    final String saved =
        await _storage.read(key: _keyForUser(normalizedUserId)) ?? '';
    final List<String> parts = saved.split(':');

    if (parts.length != 3 || parts.first != 'v1') {
      return false;
    }

    final String expected = _hashPin(
      userId: normalizedUserId,
      salt: parts[1],
      pin: pin,
    );
    final bool valid = _constantTimeEquals(expected, parts[2]);

    if (valid) {
      _preparedUserId = normalizedUserId;
      _preparedUserHasPin = true;
      _unlockedUserId = normalizedUserId;
      notifyListeners();
    }

    return valid;
  }

  Future<void> deletePinForUser(String userId) async {
    final String normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return;
    }

    await _storage.delete(key: _keyForUser(normalizedUserId));

    if (_preparedUserId == normalizedUserId) {
      _preparedUserHasPin = false;
    }
    if (_unlockedUserId == normalizedUserId) {
      _unlockedUserId = null;
    }

    notifyListeners();
  }

  void markUnlockedForUser(String userId) {
    final String normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return;
    }

    _preparedUserId = normalizedUserId;
    _unlockedUserId = normalizedUserId;
    notifyListeners();
  }

  void clearUnlock() {
    _unlockedUserId = null;
    notifyListeners();
  }

  String _keyForUser(String userId) {
    return '$_prefix${userId.trim()}';
  }

  void _validatePin(String pin) {
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      throw StateError('El PIN debe tener 4 dígitos.');
    }
  }

  String _generateSalt() {
    final Random random = Random.secure();
    final List<int> bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  String _hashPin({
    required String userId,
    required String salt,
    required String pin,
  }) {
    final List<int> bytes = utf8.encode('$userId:$salt:$pin');
    return sha256.convert(bytes).toString();
  }

  bool _constantTimeEquals(String left, String right) {
    if (left.length != right.length) {
      return false;
    }

    int difference = 0;
    for (int index = 0; index < left.length; index++) {
      difference |= left.codeUnitAt(index) ^ right.codeUnitAt(index);
    }

    return difference == 0;
  }
}
