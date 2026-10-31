/// 机台与 title server 都按 UTC+8 记录日期，客户端格式见
/// `TimeManager.GetDateString` / `GetNowDateString`。
library;

const Duration shanghaiOffset = Duration(hours: 8);

DateTime shanghaiNow() => DateTime.now().toUtc().add(shanghaiOffset);

DateTime shanghaiFromUnixSeconds(int seconds) =>
    DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true)
        .add(shanghaiOffset);

/// 两位左补齐。`ApiService` 的 `yymmddHHmmss` 时间戳也用它，不再各写一份。
String twoDigits(int value) => value.toString().padLeft(2, '0');

String _two(int value) => twoDigits(value);

String formatDate(DateTime dt) =>
    '${dt.year}-${_two(dt.month)}-${_two(dt.day)}';

String formatDateTime(DateTime dt) =>
    '${formatDate(dt)} ${_two(dt.hour)}:${_two(dt.minute)}:${_two(dt.second)}';

/// `ToString("yyyy-MM-dd HH:mm:ss.f")`：秒后固定带一位小数。
String formatPlayDateTime(DateTime dt) => '${formatDateTime(dt)}.0';
