import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:do_an_flutter/core/constants/app_theme.dart';
import 'package:do_an_flutter/core/utils/formatters.dart';
import 'package:do_an_flutter/data/models/product_model.dart';
import 'package:do_an_flutter/ui/screens/suppliers/supplier_debt_payment_history_dialog.dart';
import 'package:do_an_flutter/ui/screens/suppliers/pay_supplier_debt_dialog.dart';

void main() {
  final mockDebt = SupplierDebtModel(
    debtId: 4,
    supplierId: 10,
    supplierName: 'Công ty Thực phẩm Sạch Á Châu',
    purchaseOrderId: 102,
    totalAmount: 50000000,
    paidAmount: 20000000,
    unpaidAmount: 30000000,
    status: 'PARTIAL',
    createdAt: DateTime.now().subtract(const Duration(days: 10)),
    dueDate: DateTime.now().add(const Duration(days: 20)),
  );

  test('ThousandsSeparatorInputFormatter & Formatters.parseNumber handles long numbers cleanly', () {
    final formatter = ThousandsSeparatorInputFormatter();
    
    // Simulate user typing raw string "28937697821"
    const input = TextEditingValue(
      text: '28937697821',
      selection: TextSelection.collapsed(offset: 11),
    );
    final formatted = formatter.formatEditUpdate(TextEditingValue.empty, input);

    expect(formatted.text, '28.937.697.821');
    expect(Formatters.parseNumber(formatted.text), 28937697821.0);
    expect(Formatters.parseInt(formatted.text), 28937697821);
  });

  testWidgets('PaySupplierDebtDialog renders amount formatted with dots (30.000.000) and proof picker', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: PaySupplierDebtDialog(
            debt: mockDebt,
            onPaid: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Thanh toán Công nợ NCC'), findsOneWidget);
    // Verifies remaining amount is pre-filled with dot thousand separator
    expect(find.text('30.000.000'), findsOneWidget);
    expect(find.text('Minh chứng thanh toán'), findsOneWidget);
    expect(find.text('Chụp ảnh'), findsOneWidget);
    expect(find.text('Chọn thư viện'), findsOneWidget);
    expect(find.text('Xác nhận trả'), findsOneWidget);
  });

  testWidgets('SupplierDebtPaymentHistoryDialog renders header and metric cards without overflow', (tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: SupplierDebtPaymentHistoryDialog(
            debt: mockDebt,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.textContaining('Lịch sử trả nợ • Khoản nợ #4'), findsOneWidget);
    expect(find.text('Tổng nợ gốc'), findsOneWidget);
    expect(find.text('Đã thanh toán'), findsOneWidget);
    expect(find.text('Còn phải trả'), findsOneWidget);
  });
}
