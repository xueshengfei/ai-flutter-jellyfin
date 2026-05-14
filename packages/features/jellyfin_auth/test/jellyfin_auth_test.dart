import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jellyfin_auth/jellyfin_auth.dart';

void main() {
  group('DiscoveredServer', () {
    test('fromJson 解析 UDP 响应', () {
      final server = DiscoveredServer.fromJson({
        'Id': 'abc123',
        'Name': 'MyServer',
        'Address': 'http://192.168.1.100:8096',
        'EndpointAddress': 'http://192.168.1.100:8096',
      });
      expect(server.id, 'abc123');
      expect(server.name, 'MyServer');
      expect(server.address, 'http://192.168.1.100:8096');
      expect(server.endpointAddress, 'http://192.168.1.100:8096');
      expect(server.version, isNull);
    });

    test('fromPublicInfo 解析 Public Info 响应', () {
      final server = DiscoveredServer.fromPublicInfo({
        'Id': 'abc123',
        'ServerName': 'MyServer',
        'Version': '10.9.11',
        'LocalAddress': 'http://192.168.1.100:8096',
        'StartupWizardCompleted': true,
      }, 'http://192.168.1.100:8096');
      expect(server.id, 'abc123');
      expect(server.name, 'MyServer');
      expect(server.version, '10.9.11');
      expect(server.localAddress, 'http://192.168.1.100:8096');
      expect(server.startupWizardCompleted, true);
    });

    test('mergeWith 合并 UDP 和 PublicInfo 结果', () {
      final udp = DiscoveredServer.fromJson({
        'Id': 'abc',
        'Name': 'UDP',
        'Address': 'http://192.168.1.1:8096',
      });
      final http = DiscoveredServer.fromPublicInfo({
        'Id': 'abc',
        'ServerName': 'HTTP',
        'Version': '10.9.0',
      }, 'http://192.168.1.1:8096');
      final merged = udp.mergeWith(http);
      expect(merged.id, 'abc');
      expect(merged.name, 'HTTP');
      expect(merged.address, 'http://192.168.1.1:8096');
      expect(merged.version, '10.9.0');
    });

    test('mergeWith 保留非空值', () {
      final base = DiscoveredServer(
        id: '1',
        name: '',
        address: '',
        version: '1.0',
      );
      final other = DiscoveredServer(
        id: '2',
        name: 'Server',
        address: 'http://x:8096',
      );
      final merged = base.mergeWith(other);
      expect(merged.id, '2');
      expect(merged.name, 'Server');
      expect(merged.address, 'http://x:8096');
      expect(merged.version, '1.0');
    });
  });

  group('LoginPage', () {
    testWidgets('无 discoveryService 时不显示局域网区域', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: LoginPage(
          onLogin: ({required serverUrl, required username, required password}) async => null,
        ),
      ));
      expect(find.text('局域网服务器'), findsNothing);
    });

    testWidgets('默认值填充正确', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: LoginPage(
          defaultServerUrl: 'http://test:8096',
          defaultUsername: 'testuser',
          defaultPassword: 'testpass',
          onLogin: ({required serverUrl, required username, required password}) async => null,
        ),
      ));
      expect(find.text('http://test:8096'), findsOneWidget);
    });
  });
}
