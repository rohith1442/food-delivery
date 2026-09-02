import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/main.dart';

void main() {
  testWidgets('App loads successfully', (tester) async {
    await tester.pumpWidget(const FoodDeliveryApp());

    expect(find.text('Food Delivery'), findsOneWidget);
  });
}