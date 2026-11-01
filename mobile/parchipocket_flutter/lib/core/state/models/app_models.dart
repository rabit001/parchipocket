part of '../app_state.dart';

enum UserRole { customer, shopOwner, streetVendor }

enum CloudProfileStatus { unknown, loading, loaded, missing, failed }

extension UserRoleLabel on UserRole {
  String get label => switch (this) {
        UserRole.customer => 'Home & Family',
        UserRole.shopOwner => 'Shop Owner',
        UserRole.streetVendor => 'Street Vendor',
      };
}

class BillLine {
  BillLine(
      {required this.name, required this.quantity, required this.unitPrice});

  final String name;
  final int quantity;
  final double unitPrice;
  double get total => quantity * unitPrice;
}

class DemoBill {
  DemoBill({
    required this.id,
    required this.store,
    required this.items,
    required this.createdAt,
    required this.paymentMode,
    this.customerPhone = '',
    this.isUdhaar = false,
    this.isSettled = false,
    this.isSaved = true,
  });

  final String id;
  final String store;
  final List<BillLine> items;
  final DateTime createdAt;
  final String paymentMode;
  final String customerPhone;
  bool isUdhaar;
  bool isSettled;
  bool isSaved;
  String get displayNumber {
    if (id.startsWith('PP-')) return id;
    return 'PP-$id';
  }

  double get total => items.fold<double>(0, (sum, item) => sum + item.total);
}

/// A deliberately minimized, read-only copy of a bill claimed by this user.
class ClaimedReceipt {
  const ClaimedReceipt({
    required this.ownerUid,
    required this.sourceBillId,
    required this.bill,
    required this.claimedAt,
  });

  final String ownerUid;
  final String sourceBillId;
  final DemoBill bill;
  final DateTime claimedAt;
}

class DemoExpense {
  DemoExpense({
    this.id = '',
    required this.title,
    required this.category,
    required this.amount,
    required this.createdAt,
  });

  /// Stable Firestore document ID for cloud writes; empty for local demo rows.
  final String id;
  final String title;
  final String category;
  final double amount;
  final DateTime createdAt;
}
