part of '../app_state.dart';

class ExpenseCorrectionSnapshot {
  const ExpenseCorrectionSnapshot({
    required this.title,
    required this.category,
    required this.amount,
    this.expenseDate,
    this.modifiedAt,
  });

  final String title;
  final String category;
  final double amount;
  final DateTime? expenseDate;
  final DateTime? modifiedAt;

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'title': title,
      'category': category,
      'amount': amount,
    };
    if (expenseDate != null) {
      map['expenseDate'] = Timestamp.fromDate(expenseDate!);
    }
    if (modifiedAt != null) {
      map['modifiedAt'] = Timestamp.fromDate(modifiedAt!);
    }
    return map;
  }

  factory ExpenseCorrectionSnapshot.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    return ExpenseCorrectionSnapshot(
      title: map['title'] as String? ?? '',
      category: map['category'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      expenseDate: parseDate(map['expenseDate']),
      modifiedAt: parseDate(map['modifiedAt']),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExpenseCorrectionSnapshot &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          category == other.category &&
          amount == other.amount &&
          expenseDate == other.expenseDate &&
          modifiedAt == other.modifiedAt;

  @override
  int get hashCode =>
      Object.hash(title, category, amount, expenseDate, modifiedAt);
}

class HouseholdExpense {
  const HouseholdExpense({
    this.id = '',
    required this.title,
    required this.category,
    required this.amount,
    required this.createdAt,
    this.source = 'manual',
    this.expenseDate,
    this.isVoided = false,
    this.voidedAt,
    this.voidReason,
    this.updatedAt,
    this.history = const <ExpenseCorrectionSnapshot>[],
  });

  /// Stable Firestore document ID; empty only for local demo entries.
  final String id;
  final String title;
  final String category;
  final double amount;
  final DateTime createdAt;

  /// Either manual or voice. The field records how the entry was initiated,
  /// not whether the user confirmed it.
  final String source;

  final DateTime? expenseDate;
  final bool isVoided;
  final DateTime? voidedAt;
  final String? voidReason;
  final DateTime? updatedAt;
  final List<ExpenseCorrectionSnapshot> history;

  DateTime get effectiveDate => expenseDate ?? createdAt;

  factory HouseholdExpense.fromMap(
    Map<String, dynamic> data, {
    String id = '',
  }) {
    DateTime? parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is String) return DateTime.tryParse(value);
      return null;
    }

    final createdAt = parseDate(data['createdAt']) ?? DateTime.now();
    final expenseDate = parseDate(data['expenseDate']);
    final isVoided = data['isVoided'] == true;
    final voidedAt = parseDate(data['voidedAt']);
    final voidReason = data['voidReason'] as String?;
    final updatedAt = parseDate(data['updatedAt']);

    final historyRaw = data['history'];
    final history = <ExpenseCorrectionSnapshot>[];
    if (historyRaw is List) {
      for (final item in historyRaw) {
        if (item is Map) {
          history.add(ExpenseCorrectionSnapshot.fromMap(
            Map<String, dynamic>.from(item),
          ));
        }
      }
    }

    return HouseholdExpense(
      id: id.isNotEmpty ? id : (data['id'] as String? ?? ''),
      title: data['title'] as String? ?? '',
      category: data['category'] as String? ?? 'Other',
      amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
      createdAt: createdAt,
      source: data['source'] as String? ?? 'manual',
      expenseDate: expenseDate,
      isVoided: isVoided,
      voidedAt: voidedAt,
      voidReason: voidReason,
      updatedAt: updatedAt,
      history: history,
    );
  }

  HouseholdExpense copyWith({
    String? id,
    String? title,
    String? category,
    double? amount,
    DateTime? createdAt,
    String? source,
    DateTime? expenseDate,
    bool? isVoided,
    DateTime? voidedAt,
    String? voidReason,
    DateTime? updatedAt,
    List<ExpenseCorrectionSnapshot>? history,
  }) {
    return HouseholdExpense(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      createdAt: createdAt ?? this.createdAt,
      source: source ?? this.source,
      expenseDate: expenseDate ?? this.expenseDate,
      isVoided: isVoided ?? this.isVoided,
      voidedAt: voidedAt ?? this.voidedAt,
      voidReason: voidReason ?? this.voidReason,
      updatedAt: updatedAt ?? this.updatedAt,
      history: history ?? this.history,
    );
  }
}
