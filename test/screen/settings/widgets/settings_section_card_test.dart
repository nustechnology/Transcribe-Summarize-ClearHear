import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:transcribe_summarize_clearhear/screen/settings/widgets/settings_section_card.dart';

void main() {
  testWidgets('SettingsSectionCard shows title icon and children',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SettingsSectionCard(
            icon: Icons.settings,
            title: 'Appearance',
            children: [
              Text('Child row'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Child row'), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);
  });

  testWidgets('SettingsRowLabel shows optional subtitle', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SettingsRowLabel(
            title: 'Caption size',
            subtitle: 'Affects live captions',
          ),
        ),
      ),
    );

    expect(find.text('Caption size'), findsOneWidget);
    expect(find.text('Affects live captions'), findsOneWidget);
  });

  testWidgets('SettingsNavRow invokes onTap', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SettingsNavRow(
            title: 'About',
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('About'));
    expect(tapped, isTrue);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('SettingsDivider renders a divider', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: SettingsDivider()),
      ),
    );

    expect(find.byType(Divider), findsOneWidget);
  });
}
