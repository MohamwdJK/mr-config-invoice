import 'dart:convert';

class SellerProfile {
  String brandName;
  String subtitle;
  String phone;
  String address;
  String website;
  String cardNumber;
  String shebaNumber;
  String accountHolder;
  String? logoPath;
  String? stampPath;

  SellerProfile({
    this.brandName = 'MR.Config',
    this.subtitle = 'مهندسی شبکه، راه‌اندازی زیرساخت و تجهیزات نظارت تصویری',
    this.phone = '09120000000',
    this.address = 'تهران، خیابان ولیعصر، مرکز کامپیوتر و شبکه',
    this.website = 'www.mrconfig.ir | @mr.config',
    this.cardNumber = '6037-9970-0000-0000',
    this.shebaNumber = 'IR000000000000000000000000',
    this.accountHolder = 'مهندس شبکه (MR.Config)',
    this.logoPath,
    this.stampPath,
  });

  Map<String, dynamic> toJson() => {
        'brandName': brandName,
        'subtitle': subtitle,
        'phone': phone,
        'address': address,
        'website': website,
        'cardNumber': cardNumber,
        'shebaNumber': shebaNumber,
        'accountHolder': accountHolder,
        'logoPath': logoPath,
        'stampPath': stampPath,
      };

  factory SellerProfile.fromJson(Map<String, dynamic> json) => SellerProfile(
        brandName: json['brandName'] ?? 'MR.Config',
        subtitle: json['subtitle'] ??
            'مهندسی شبکه، راه‌اندازی زیرساخت و تجهیزات نظارت تصویری',
        phone: json['phone'] ?? '',
        address: json['address'] ?? '',
        website: json['website'] ?? '',
        cardNumber: json['cardNumber'] ?? '',
        shebaNumber: json['shebaNumber'] ?? '',
        accountHolder: json['accountHolder'] ?? '',
        logoPath: json['logoPath'],
        stampPath: json['stampPath'],
      );
}

class CatalogItem {
  int? id;
  String description;
  String category; // 'تجهیزات' or 'خدمات و اجرت'
  String unit; // 'عدد', 'متر', 'شاخه', 'ساعت', 'پروژه'
  double defaultPrice;

  CatalogItem({
    this.id,
    required this.description,
    required this.category,
    required this.unit,
    required this.defaultPrice,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'description': description,
        'category': category,
        'unit': unit,
        'defaultPrice': defaultPrice,
      };

  factory CatalogItem.fromMap(Map<String, dynamic> map) => CatalogItem(
        id: map['id'],
        description: map['description'],
        category: map['category'],
        unit: map['unit'],
        defaultPrice: (map['defaultPrice'] as num).toDouble(),
      );
}

class InvoiceLineItem {
  String description;
  String category;
  double quantity;
  String unit;
  double unitPrice;
  double discountValue;
  bool isDiscountPercent;

  InvoiceLineItem({
    this.description = '',
    this.category = 'تجهیزات',
    this.quantity = 1.0,
    this.unit = 'عدد',
    this.unitPrice = 0.0,
    this.discountValue = 0.0,
    this.isDiscountPercent = false,
  });

  double get grossTotal => quantity * unitPrice;

  double get discountAmount {
    if (isDiscountPercent) {
      return grossTotal * (discountValue / 100.0);
    }
    return discountValue;
  }

  double get netTotal {
    final total = grossTotal - discountAmount;
    return total < 0 ? 0 : total;
  }

  Map<String, dynamic> toJson() => {
        'description': description,
        'category': category,
        'quantity': quantity,
        'unit': unit,
        'unitPrice': unitPrice,
        'discountValue': discountValue,
        'isDiscountPercent': isDiscountPercent,
      };

  factory InvoiceLineItem.fromJson(Map<String, dynamic> json) => InvoiceLineItem(
        description: json['description'] ?? '',
        category: json['category'] ?? 'تجهیزات',
        quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
        unit: json['unit'] ?? 'عدد',
        unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
        discountValue: (json['discountValue'] as num?)?.toDouble() ?? 0.0,
        isDiscountPercent: json['isDiscountPercent'] ?? false,
      );
}

class InvoiceDocument {
  int? id;
  bool isOfficialInvoice; // true: فاکتور رسمی فروش و خدمات, false: پیش‌فاکتور
  String invoiceNumber;
  String shamsiDate;
  String clientName;
  String clientPhone;
  String clientNationalId;
  String clientAddress;
  String currency; // 'تومان' or 'ریال'
  List<InvoiceLineItem> items;
  double overallDiscountValue;
  bool isOverallDiscountPercent;
  bool enableTax;
  double taxPercent;
  double depositPaid;
  String paymentStatus; // 'پرداخت شده', 'پرداخت نشده', 'در انتظار پرداخت'
  String notesAndTerms;

  InvoiceDocument({
    this.id,
    this.isOfficialInvoice = true,
    required this.invoiceNumber,
    required this.shamsiDate,
    this.clientName = '',
    this.clientPhone = '',
    this.clientNationalId = '',
    this.clientAddress = '',
    this.currency = 'تومان',
    List<InvoiceLineItem>? items,
    this.overallDiscountValue = 0.0,
    this.isOverallDiscountPercent = false,
    this.enableTax = false,
    this.taxPercent = 10.0,
    this.depositPaid = 0.0,
    this.paymentStatus = 'در انتظار پرداخت',
    this.notesAndTerms =
        'تمامی تجهیزات دارای گارانتی اصلی بوده و خدمات نصب و راه‌اندازی شبکه شامل ۴۸ ساعت مهلت تست و تایید کارفرما می‌باشد.',
  }) : items = items ?? [InvoiceLineItem()];

  double get subtotal => items.fold(0.0, (sum, item) => sum + item.netTotal);

  double get overallDiscountAmount {
    if (isOverallDiscountPercent) {
      return subtotal * (overallDiscountValue / 100.0);
    }
    return overallDiscountValue;
  }

  double get taxableAmount {
    final amt = subtotal - overallDiscountAmount;
    return amt < 0 ? 0 : amt;
  }

  double get taxAmount => enableTax ? taxableAmount * (taxPercent / 100.0) : 0.0;

  double get grandTotal => (taxableAmount + taxAmount).roundToDouble();

  double get remainingBalance {
    final rem = grandTotal - depositPaid;
    return rem < 0 ? 0 : rem;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'isOfficialInvoice': isOfficialInvoice ? 1 : 0,
        'invoiceNumber': invoiceNumber,
        'shamsiDate': shamsiDate,
        'clientName': clientName,
        'clientPhone': clientPhone,
        'clientNationalId': clientNationalId,
        'clientAddress': clientAddress,
        'currency': currency,
        'itemsJson': jsonEncode(items.map((e) => e.toJson()).toList()),
        'overallDiscountValue': overallDiscountValue,
        'isOverallDiscountPercent': isOverallDiscountPercent ? 1 : 0,
        'enableTax': enableTax ? 1 : 0,
        'taxPercent': taxPercent,
        'depositPaid': depositPaid,
        'paymentStatus': paymentStatus,
        'notesAndTerms': notesAndTerms,
      };

  factory InvoiceDocument.fromMap(Map<String, dynamic> map) {
    final rawItems = jsonDecode(map['itemsJson'] ?? '[]') as List;
    return InvoiceDocument(
      id: map['id'],
      isOfficialInvoice: map['isOfficialInvoice'] == 1,
      invoiceNumber: map['invoiceNumber'] ?? '',
      shamsiDate: map['shamsiDate'] ?? '',
      clientName: map['clientName'] ?? '',
      clientPhone: map['clientPhone'] ?? '',
      clientNationalId: map['clientNationalId'] ?? '',
      clientAddress: map['clientAddress'] ?? '',
      currency: map['currency'] ?? 'تومان',
      items: rawItems.map((e) => InvoiceLineItem.fromJson(e)).toList(),
      overallDiscountValue: (map['overallDiscountValue'] as num).toDouble(),
      isOverallDiscountPercent: map['isOverallDiscountPercent'] == 1,
      enableTax: map['enableTax'] == 1,
      taxPercent: (map['taxPercent'] as num).toDouble(),
      depositPaid: (map['depositPaid'] as num).toDouble(),
      paymentStatus: map['paymentStatus'] ?? 'در انتظار پرداخت',
      notesAndTerms: map['notesAndTerms'] ?? '',
    );
  }
}
