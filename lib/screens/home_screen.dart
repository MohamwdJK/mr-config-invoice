import 'package:flutter/material.dart';
import '../db_helper.dart';
import '../models.dart';
import '../utils.dart';
import 'catalog_screen.dart';
import 'invoice_form_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<InvoiceDocument> _allInvoices = [];
  String _searchQuery = '';
  String _statusFilter = 'همه';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    setState(() => _loading = true);
    final list = await DatabaseHelper.instance.getAllInvoices();
    setState(() {
      _allInvoices = list;
      _loading = false;
    });
  }

  List<InvoiceDocument> get _filteredInvoices {
    return _allInvoices.where((inv) {
      final matchesSearch = inv.clientName.contains(_searchQuery) ||
          inv.invoiceNumber.contains(_searchQuery) ||
          inv.shamsiDate.contains(_searchQuery);
      final matchesStatus =
          _statusFilter == 'همه' || inv.paymentStatus == _statusFilter;
      return matchesSearch && matchesStatus;
    }).toList();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'پرداخت شده':
        return Colors.green.shade700;
      case 'پرداخت نشده':
        return Colors.red.shade700;
      default:
        return Colors.orange.shade800;
    }
  }

  Future<void> _duplicateInvoice(InvoiceDocument source) async {
    final nextNum = await DatabaseHelper.instance.getNextInvoiceNumber();
    final duplicated = InvoiceDocument(
      isOfficialInvoice: source.isOfficialInvoice,
      invoiceNumber: nextNum,
      shamsiDate: AppUtils.getCurrentShamsiDate(),
      clientName: source.clientName,
      clientPhone: source.clientPhone,
      clientNationalId: source.clientNationalId,
      clientAddress: source.clientAddress,
      currency: source.currency,
      items: source.items
          .map((e) => InvoiceLineItem.fromJson(e.toJson()))
          .toList(),
      overallDiscountValue: source.overallDiscountValue,
      isOverallDiscountPercent: source.isOverallDiscountPercent,
      enableTax: source.enableTax,
      taxPercent: source.taxPercent,
      depositPaid: 0,
      paymentStatus: 'در انتظار پرداخت',
      notesAndTerms: source.notesAndTerms,
    );
    await DatabaseHelper.instance.saveInvoice(duplicated);
    await _loadInvoices();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فاکتور با شماره جدید کپی شد.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          children: [
            Text('MR.Config',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('سامانه صدور فاکتور و پیش‌فاکتور مهندسی شبکه',
                style: TextStyle(fontSize: 11, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'کاتالوگ خدمات و تجهیزات',
            icon: const Icon(Icons.inventory_2_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CatalogScreen()),
              );
            },
          ),
          IconButton(
            tooltip: 'تنظیمات برند و فروشنده',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Status Filter Bar
          Container(
            color: const Color(0xFF0A192F),
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'جستجو بر اساس نام مشتری، شماره فاکتور یا تاریخ...',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      'همه',
                      'پرداخت شده',
                      'در انتظار پرداخت',
                      'پرداخت نشده'
                    ].map((status) {
                      final selected = _statusFilter == status;
                      return Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: ChoiceChip(
                          label: Text(status),
                          selected: selected,
                          selectedColor: const Color(0xFF0284C7),
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : Colors.black87,
                            fontSize: 12,
                          ),
                          onSelected: (_) =>
                              setState(() => _statusFilter = status),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          // Invoice Archive List
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredInvoices.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long_outlined,
                                size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            const Text(
                              'هیچ فاکتوری در آرشیو یافت نشد.',
                              style:
                                  TextStyle(fontSize: 15, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _filteredInvoices.length,
                        itemBuilder: (context, index) {
                          final inv = _filteredInvoices[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                              title: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      inv.clientName.isEmpty
                                          ? 'مشتری بدون نام'
                                          : inv.clientName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(inv.paymentStatus)
                                          .withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      inv.paymentStatus,
                                      style: TextStyle(
                                        color:
                                            _getStatusColor(inv.paymentStatus),
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 6),
                                  Text(
                                    '${inv.isOfficialInvoice ? "فاکتور رسمی" : "پیش‌فاکتور"} شماره ${AppUtils.toPersianDigits(inv.invoiceNumber)}  |  تاریخ: ${AppUtils.toPersianDigits(inv.shamsiDate)}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'مبلغ کل: ${AppUtils.formatNumber(inv.grandTotal)} ${inv.currency}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0284C7),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (action) async {
                                  if (action == 'edit') {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => InvoiceFormScreen(
                                            existingInvoice: inv),
                                      ),
                                    );
                                    _loadInvoices();
                                  } else if (action == 'duplicate') {
                                    await _duplicateInvoice(inv);
                                  } else if (action == 'delete') {
                                    await DatabaseHelper.instance
                                        .deleteInvoice(inv.id!);
                                    _loadInvoices();
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        Icon(Icons.edit, size: 18),
                                        SizedBox(width: 8),
                                        Text('ویرایش و خروجی PDF/عکس'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'duplicate',
                                    child: Row(
                                      children: [
                                        Icon(Icons.copy, size: 18),
                                        SizedBox(width: 8),
                                        Text('تکثیر (کپی فاکتور)'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline,
                                            size: 18, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text('حذف از آرشیو',
                                            style:
                                                TextStyle(color: Colors.red)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        InvoiceFormScreen(existingInvoice: inv),
                                  ),
                                );
                                _loadInvoices();
                              },
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0284C7),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('صدور فاکتور جدید',
            style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const InvoiceFormScreen()),
          );
          _loadInvoices();
        },
      ),
    );
  }
}
