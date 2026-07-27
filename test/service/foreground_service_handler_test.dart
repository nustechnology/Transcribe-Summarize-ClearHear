import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe_summarize_clearhear/service/foreground_service_handler.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('clearhear/foreground_service');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    ForegroundServiceHandler.debugIsAndroid = true;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    ForegroundServiceHandler.debugIsAndroid = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('start and stop invoke MethodChannel on Android path', () async {
    await ForegroundServiceHandler.start();
    await ForegroundServiceHandler.stop();

    expect(calls.map((c) => c.method), ['start', 'stop']);
  });

  test('start/stop are no-ops when not Android', () async {
    ForegroundServiceHandler.debugIsAndroid = false;

    await ForegroundServiceHandler.start();
    await ForegroundServiceHandler.stop();

    expect(calls, isEmpty);
  });

  test('channel errors are swallowed', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(code: 'FAIL', message: 'boom');
    });

    await ForegroundServiceHandler.start();
    await ForegroundServiceHandler.stop();
  });
}
