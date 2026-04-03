import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sige_mx/features/messaging/inbox_screen.dart';
import 'package:sige_mx/features/messaging/messaging_provider.dart';
import 'package:sige_mx/shared/models/message.dart';

void main() {
  testWidgets('inbox shows empty state', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inboxProvider.overrideWith((_) => Future.value(<Message>[])),
          sentProvider.overrideWith((_) => Future.value(<Message>[])),
        ],
        child: const MaterialApp(home: InboxScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Sin mensajes'), findsWidgets);
  });

  testWidgets('inbox shows unread message in bold', (tester) async {
    final msgs = [
      Message(id: 'm1', content: 'Hola mundo', createdAt: '2026-04-03', read: false),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inboxProvider.overrideWith((_) => Future.value(msgs)),
          sentProvider.overrideWith((_) => Future.value(<Message>[])),
        ],
        child: const MaterialApp(home: InboxScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hola mundo'), findsOneWidget);
  });
}
