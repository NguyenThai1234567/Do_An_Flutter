import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CashReconciliationRecord {
  final String id;
  final DateTime timestamp;
  final String staffName;
  final String? branchName;
  final double expectedCash;
  final double actualCash;
  final double discrepancy;
  final Map<int, int> denominations;
  final String? notes;

  CashReconciliationRecord({
    required this.id,
    required this.timestamp,
    required this.staffName,
    this.branchName,
    required this.expectedCash,
    required this.actualCash,
    required this.discrepancy,
    required this.denominations,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'staffName': staffName,
      'branchName': branchName,
      'expectedCash': expectedCash,
      'actualCash': actualCash,
      'discrepancy': discrepancy,
      'denominations': denominations.map((k, v) => MapEntry(k.toString(), v)),
      'notes': notes,
    };
  }

  factory CashReconciliationRecord.fromJson(Map<String, dynamic> json) {
    final rawDenoms = json['denominations'] as Map<String, dynamic>? ?? {};
    final denoms = <int, int>{};
    rawDenoms.forEach((k, v) {
      final key = int.tryParse(k) ?? 0;
      final val = (v as num?)?.toInt() ?? 0;
      if (key > 0) denoms[key] = val;
    });

    return CashReconciliationRecord(
      id: (json['id'] ?? '').toString(),
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
      staffName: (json['staffName'] ?? 'Nhân viên').toString(),
      branchName: json['branchName']?.toString(),
      expectedCash: (json['expectedCash'] as num?)?.toDouble() ?? 0.0,
      actualCash: (json['actualCash'] as num?)?.toDouble() ?? 0.0,
      discrepancy: (json['discrepancy'] as num?)?.toDouble() ?? 0.0,
      denominations: denoms,
      notes: json['notes']?.toString(),
    );
  }
}

class CashReconciliationService {
  static const String _storageKey = 'EMARKET_CASH_RECONCILIATION_HISTORY';
  static final CashReconciliationService _instance = CashReconciliationService._internal();
  factory CashReconciliationService() => _instance;
  CashReconciliationService._internal();

  Future<List<CashReconciliationRecord>> getHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) return [];

      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((item) => CashReconciliationRecord.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> saveRecord(CashReconciliationRecord record) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = await getHistory();
      // Add new record to front
      current.insert(0, record);
      // Keep up to 100 recent sessions
      final limited = current.take(100).toList();
      final raw = jsonEncode(limited.map((e) => e.toJson()).toList());
      return await prefs.setString(_storageKey, raw);
    } catch (_) {
      return false;
    }
  }

  Future<bool> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return await prefs.remove(_storageKey);
  }
}
