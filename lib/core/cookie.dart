/// Cookie 解析：会话只认 `JSESSIONID`，其余字段一律丢掉。
library;

/// 从 `Set-Cookie` 响应头或 `Cookie` 请求串里取出 `JSESSIONID=...`。
///
/// 传输层抓响应头与「连接信息」解码各自实现过一遍（一个用正则、一个手写
/// 分号切分），这里统一成一处：只有键名正好是 `JSESSIONID` 才认，
/// `XJSESSIONID=` 这类前缀不同的键不算。
final RegExp _jsessionPattern = RegExp(
  r'(?:^|[;,\s])JSESSIONID=([^;,\s]+)',
  caseSensitive: false,
);

String? parseJsessionId(String? headerValue) {
  if (headerValue == null) return null;
  final value = _jsessionPattern.firstMatch(headerValue)?.group(1)?.trim();
  if (value == null || value.isEmpty) return null;
  return 'JSESSIONID=$value';
}
