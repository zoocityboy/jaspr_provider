import 'package:jaspr/jaspr.dart';
import 'package:jaspr_provider/jaspr_provider.dart';
import 'package:jaspr_provider/src/provider.dart';
import 'package:jaspr_test/jaspr_test.dart';

import 'common.dart';
import 'matchers.dart';

void main() {
  late PostEventSpy spy;
  late ComponentTester tester;

  setUpAll(() {
    tester = ComponentTester.setUp();
  });

  setUp(() {
    spy = spyPostEvent();
  });

  tearDown(() => spy.dispose());

  test('calls postEvent whenever a provider is updated', () async {
    final notifier = ValueNotifier(42);

    await tester.pumpComponent(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: notifier),
        ],
        child: Consumer<ValueNotifier<int>>(
          builder: (context, value, child) sync* {
            yield Container();
          },
        ),
      ),
    );

    final notifierId = ProviderBinding.debugInstance.providerDetails.keys.single;

    spy.logs.clear();

    notifier.notifyListeners();

    expect(spy.logs, isEmpty);

    await tester.pump();

    expect(
      spy.logs,
      [
        isPostEventCall(
          'provider:provider_changed',
          <String, dynamic>{'id': notifierId},
        ),
      ],
    );
    spy.logs.clear();
  });

  test('calls postEvent whenever a provider is mounted/unmounted', () async {
    Provider.value(value: 42);

    expect(spy.logs, isEmpty);
    expect(ProviderBinding.debugInstance.providerDetails, isEmpty);

    await tester.pumpComponent(
      MultiProvider(
        providers: [
          Provider.value(value: 42),
        ],
        child: Container(),
      ),
    );

    final intProviderId = ProviderBinding.debugInstance.providerDetails.keys.first;

    expect(ProviderBinding.debugInstance.providerDetails, {
      intProviderId: isA<ProviderNode>()
          .having((e) => e.id, 'id', intProviderId)
          .having((e) => e.type, 'type', 'Provider<int>')
          .having((e) => e.value, 'value', 42),
    });
    expect(
      spy.logs,
      [isPostEventCall('provider:provider_list_changed', isEmpty)],
    );
    spy.logs.clear();

    await tester.pumpComponent(
      MultiProvider(
        providers: [
          Provider.value(value: 42),
          Provider.value(value: '42'),
        ],
        child: Container(),
      ),
    );

    final stringProviderId = ProviderBinding.debugInstance.providerDetails.keys.last;

    expect(intProviderId, isNot(stringProviderId));
    expect(ProviderBinding.debugInstance.providerDetails, {
      intProviderId: isA<ProviderNode>()
          .having((e) => e.id, 'id', intProviderId)
          .having((e) => e.type, 'type', 'Provider<int>')
          .having((e) => e.value, 'value', 42),
      stringProviderId: isA<ProviderNode>()
          .having((e) => e.id, 'id', stringProviderId)
          .having((e) => e.type, 'type', 'Provider<String>')
          .having((e) => e.value, 'value', '42'),
    });
    expect(
      spy.logs,
      [isPostEventCall('provider:provider_list_changed', isEmpty)],
    );
    spy.logs.clear();

    await tester.pumpComponent(
      MultiProvider(
        providers: [
          Provider.value(value: 42),
        ],
        child: Container(),
      ),
    );

    expect(ProviderBinding.debugInstance.providerDetails, {
      intProviderId: isA<ProviderNode>()
          .having((e) => e.id, 'id', intProviderId)
          .having((e) => e.type, 'type', 'Provider<int>')
          .having((e) => e.value, 'value', 42),
    });
    expect(
      spy.logs,
      [isPostEventCall('provider:provider_list_changed', isEmpty)],
    );
    spy.logs.clear();
  });
}
