import 'dart:collection';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Token生成相关工具类
class TokenGenerator {
  /// 生成RTC Token
  /// @param appId 应用ID
  /// @param appKey 应用密钥
  /// @param roomId 房间ID
  /// @param userId 用户ID
  /// @param expireTime 过期时间(秒)
  static Future<String> generateToken({
    required String appId,
    required String appKey,
    required String roomId,
    required String userId,
    int expireTime = 7200,
  }) async {
    // 创建 token
    AccessToken accessToken = AccessToken(
      appId,
      appKey,
      roomId,
      userId,
    );

    // 设置过期时间和权限
    int expireTimestamp = Utils.getTimestamp() + expireTime;
    accessToken.expireTime(expireTimestamp);
    accessToken.addPrivilege(Privileges.privPublishStream, expireTimestamp);
    accessToken.addPrivilege(Privileges.privSubscribeStream, expireTimestamp);

    // 序列化生成token
    return accessToken.serialize();
  }
}

/// 权限枚举
class Privileges {
  static const int privPublishStream = 0;
  static const int privPublishAudioStream = 1;
  static const int privPublishVideoStream = 2;
  static const int privPublishDataStream = 3;
  static const int privSubscribeStream = 4;
}

/// AccessToken 类用于生成和验证RTC Token
class AccessToken {
  String appID;
  String appKey;
  String roomID;
  String userID;
  int issuedAt;
  int expireAt;
  int nonce;
  SplayTreeMap<int, int> privileges;
  Uint8List? signature;

  /// 构造函数
  AccessToken(this.appID, this.appKey, this.roomID, this.userID)
      : issuedAt = Utils.getTimestamp(),
        expireAt = 0,
        nonce = Utils.randomInt(),
        privileges = SplayTreeMap<int, int>();

  /// 获取版本号
  static String getVersion() => '001';

  /// 添加权限
  void addPrivilege(int privilege, int expireTimestamp) {
    privileges[privilege] = expireTimestamp;

    if (privilege == Privileges.privPublishStream) {
      privileges[Privileges.privPublishVideoStream] = expireTimestamp;
      privileges[Privileges.privPublishAudioStream] = expireTimestamp;
      privileges[Privileges.privPublishDataStream] = expireTimestamp;
    }
  }

  /// 设置过期时间
  void expireTime(int expireTimestamp) {
    expireAt = expireTimestamp;
  }

  /// 打包消息
  Uint8List packMsg() {
    final buffer = ByteBuf();
    return buffer
        .putInt32(nonce)
        .putInt32(issuedAt)
        .putInt32(expireAt)
        .putString(roomID)
        .putString(userID)
        .putIntMap(privileges)
        .asBytes();
  }

  /// 序列化生成token字符串
  String serialize() {
    final msg = packMsg();
    signature = Utils.hmacSign(appKey, msg);

    final buffer = ByteBuf();
    final content = buffer.putBytes(msg).putBytes(signature!).asBytes();

    return '${getVersion()}$appID${Utils.base64Encode(content)}';
  }
}

/// 工具类
class Utils {
  static const int HMAC_SHA256_LENGTH = 32;
  static const int VERSION_LENGTH = 3;
  static const int APP_ID_LENGTH = 24;

  /// 使用 HMAC-SHA256 算法对消息进行签名
  static Uint8List hmacSign(String keyString, Uint8List msg) {
    final key = utf8.encode(keyString);
    final hmac = Hmac(sha256, key);
    final digest = hmac.convert(msg);
    return Uint8List.fromList(digest.bytes);
  }

  /// Base64 编码
  static String base64Encode(Uint8List data) {
    return base64.encode(data);
  }

  /// Base64 解码
  static Uint8List base64Decode(String data) {
    return base64.decode(data);
  }

  /// 获取当前时间戳（秒）
  static int getTimestamp() {
    return DateTime.now().millisecondsSinceEpoch ~/ 1000;
  }

  /// 生成随机整数
  static int randomInt() {
    return Random.secure().nextInt(0x7FFFFFFF);
  }
}

/// 二进制缓冲区处理类
class ByteBuf {
  late ByteData _buffer;
  int _position = 0;
  static const int _initialSize = 1024;

  ByteBuf() {
    _buffer = ByteData(_initialSize);
  }

  ByteBuf.fromBytes(Uint8List bytes) {
    _buffer = ByteData.view(bytes.buffer);
  }

  Uint8List asBytes() {
    return Uint8List.view(_buffer.buffer, 0, _position);
  }

  ByteBuf putInt32(int v) {
    _ensureSpace(4);
    _buffer.setInt32(_position, v, Endian.little);
    _position += 4;
    return this;
  }

  ByteBuf putBytes(Uint8List v) {
    if (v.length > 0xFFFF) {
      throw RangeError('Byte array too long: ${v.length} bytes');
    }
    putInt16(v.length);
    _ensureSpace(v.length);
    Uint8List.view(_buffer.buffer, _position, v.length).setAll(0, v);
    _position += v.length;
    return this;
  }

  ByteBuf putInt16(int v) {
    _ensureSpace(2);
    _buffer.setInt16(_position, v, Endian.little);
    _position += 2;
    return this;
  }

  ByteBuf putString(String v) {
    return putBytes(Uint8List.fromList(utf8.encode(v)));
  }

  ByteBuf putIntMap(Map<int, int> map) {
    putInt16(map.length);
    map.forEach((key, value) {
      putInt16(key);
      putInt32(value);
    });
    return this;
  }

  void _ensureSpace(int additionalBytes) {
    if (_position + additionalBytes > _buffer.lengthInBytes) {
      int newSize = _buffer.lengthInBytes * 2;
      while (newSize < _position + additionalBytes) {
        newSize *= 2;
      }
      final newBuffer = ByteData(newSize);
      Uint8List.view(newBuffer.buffer)
          .setAll(0, Uint8List.view(_buffer.buffer, 0, _position));
      _buffer = newBuffer;
    }
  }
}
