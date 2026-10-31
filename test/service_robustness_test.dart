import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ichino/config/strings.dart';
import 'package:ichino/config/title_server_config.dart';
import 'package:ichino/core/cookie.dart';
import 'package:ichino/core/json_value.dart';
import 'package:ichino/pages/home/home_tab_view.dart';
import 'package:ichino/services/user_all_payload_builder.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _config = TitleServerConfig(
  titleServerUrl: 'http://127.0.0.1:9999',
  aesKey: '0123456789abcdef',
  aesIv: '0123456789abcdef',
  clientId: 'A63E01C2805',
);

Map<String, dynamic> _upsert(
  Map<String, Map<String, dynamic>> serverData,
) {
  final builder = UserAllPayloadBuilder(_config);
  final packet = builder.build(
    userId: 42,
    loginId: 7,
    loginDateTime: 1700000000,
    musicData: UserAllPayloadBuilder.placeholderMusicData(),
    generalUserInfo: serverData,
  );
  return packet['upsertUserAll'] as Map<String, dynamic>;
}

void main() {
  group('UpsertUserAll 包体容错', () {
    // 服务器缺段时不能往包里塞 null：服务端反序列化 UserExtend /
    // UserActivity 时会整包失败，而这两种响应在私服上确实可能整个不回。
    test('服务器没有回 userExtend / userActivity 时补空对象而不是 null', () {
      final upsert = _upsert(const {});

      for (final key in ['userExtend', 'userActivityList']) {
        final rows = upsert[key] as List;
        expect(rows, hasLength(1), reason: '$key 应该仍是一行');
        expect(rows.first, isA<Map<String, dynamic>>(), reason: '$key 不能是 null');
      }
    });

    test('任务列表里混入 null / 非对象行时不抛异常，只跳过该行', () {
      final upsert = _upsert(const {
        'GetUserMissionDataApi': {
          'userMissionDataList': [
            null,
            'garbage',
            {'type': 1, 'difficulty': 2, 'clearFlag': 0},
          ],
        },
      });

      final missions = upsert['userMissionDataList'] as List;
      expect(missions, hasLength(1));
      expect((missions.first as Map)['type'], 1);
    });
  });

  group('jsonBool', () {
    test('认得出的布尔串照常解析', () {
      expect(jsonBool('1'), isTrue);
      expect(jsonBool('TRUE'), isTrue);
      expect(jsonBool('0'), isFalse);
      expect(jsonBool('false'), isFalse);
      expect(jsonBool(2), isTrue);
    });

    test('认不出的字符串走 fallback，与 jsonInt 行为一致', () {
      expect(jsonBool('未知', fallback: true), isTrue);
      expect(jsonBool('未知'), isFalse);
    });
  });

  group('parseJsessionId', () {
    test('从 Set-Cookie 头里取值，忽略 Path 等属性', () {
      expect(
        parseJsessionId('JSESSIONID=ABC123; Path=/; HttpOnly'),
        'JSESSIONID=ABC123',
      );
    });

    test('从 Cookie 串里取值', () {
      expect(
        parseJsessionId('other=1; JSESSIONID=XYZ; foo=bar'),
        'JSESSIONID=XYZ',
      );
    });

    test('键名必须正好是 JSESSIONID', () {
      expect(parseJsessionId('XJSESSIONID=ABC'), isNull);
      expect(parseJsessionId('JSESSIONID='), isNull);
      expect(parseJsessionId(null), isNull);
    });
  });

  group('主页状态视图', () {
    // 错误文本长度不可控（socket / HTTP 原样带出），窄窗口下也必须能滚。
    testWidgets('加载失败的说明在 320 宽下不溢出', (tester) async {
      SharedPreferences.setMockInitialValues({});
      // 配好 Title Server，否则走的是「未配置」分支而不是错误分支。
      await TitleServerConfigHolder().update(_config);
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HomeTabView(
              userId: 42,
              token: 't',
              cookies: null,
              preview: null,
              userData: null,
              loading: false,
              error: 'SocketException: 连接被拒绝（很长的一行错误文本）' * 3,
              isGameLoggedIn: false,
              forcePreviewApi: false,
              showRestoredNotice: false,
              rawJson: null,
              onRetry: () {},
              onOpenSettings: () {},
              onLogin: () {},
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text(AppStrings.loadFailed), findsOneWidget);
    });
  });
}
