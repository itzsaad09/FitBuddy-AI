import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fitbuddy_ai/main.dart';
import 'package:fitbuddy_ai/services/theme_service.dart';
import 'package:fitbuddy_ai/models/user_profile.dart';

void main() {
  testWidgets('App loads successfully smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeService()),
          ChangeNotifierProvider(create: (_) => UserProfileProvider()),
        ],
        child: const FitBuddyAI(),
      ),
    );

    expect(find.byType(FitBuddyAI), findsOneWidget);
  });
}
