import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:loongpos/main.dart'; // หรือ path ตามชื่อ project/app จริงของคุณ

void main() {
  testWidgets('POS UI renders and buttons work', (WidgetTester tester) async {
    await tester.pumpWidget(const POSApp());

    // เช็คว่าเจอข้อความ 'POS System' ใน AppBar
    expect(find.text('POS System'), findsOneWidget);

    // ยังไม่มีสินค้าใด ๆ ปรากฏ
    expect(find.byType(ElevatedButton), findsNothing);

    // ลองกดปุ่ม "+" เปิด dialog
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();

    // ควรเห็น Dialog 'Add Product'
    expect(find.text('Add Product'), findsOneWidget);
  });
}
