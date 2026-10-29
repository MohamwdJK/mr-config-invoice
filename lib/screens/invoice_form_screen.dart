import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shamsi_date/shamsi_date.dart';
import '../db_helper.dart';
import '../models.dart';
import '../pdf_generator.dart';
import '../utils.dart';

class InvoiceFormScreen extends StatefulWidget {
  final InvoiceDocument? existingInvoice;

  const InvoiceFormScreen({super.key, this.existingInvoice});

  @override
  State<InvoiceFormScreen> createState() => _InvoiceFormScreenState();
}

class _InvoiceFormScreenState extends State<InvoiceFormScreen> {
  late InvoiceDocument _invoice;
  final _invoiceNumCtrl = TextEditingController();
  final _dateCtrl = TextEditingController();
  final _clientNameCtrl = TextEditingController();
  final _clientPhoneCtrl = TextEditingController();
  final _clientNatIdCtrl = TextEditingController();
  final _clientAddressCtrl = TextEditingController();
  final _overallDiscountCtrl = TextEditingController();
  final _taxPercentCtrl = TextEditingController();
  final _depositCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  bool _isSaving = false;

  static const List<String> _categories = ['تجهیزات', 'خدمات و اجرت'];
  static const List<String> _units = ['عدد', 'متر', 'شاخه', 'ساعت', 'پروژه'];
  static const List<String> _statuses = [
    'در انتظار پرداخت',
    'پرداخت شده',
    'پرداخت نشده'
  ];

  @override
  void initState() {
    super.initState();
    _initDocument();
  }

  Future<void> _initDocument() async {
    if (widget.existingInvoice != null) {
      _invoice = InvoiceDocument.fromMap(widget.existingInvoice!.toMap());
      _populateControllers();
    } else {
      final nextNo = await DatabaseHelper.instance.getNextInvoiceNumber();
      _invoice = InvoiceDocument(
        invoiceNumber: nextNo,
        shamsiDate: AppUtils.getCurrentShamsiDate(),
      );
      _populateControllers();
      if (mounted) setState(() {});
    }
  }

  void _populateControllers() {
    _invoiceNumCtrl.text = _invoice.invoiceNumber;
    _dateCtrl.text = _invoice.shamsiDate;
    _clientNameCtrl.text = _invoice.clientName;
    _clientPhoneCtrl.text = _invoice.clientPhone;
    _clientNatIdCtrl.text = _invoice.clientNationalId;
    _clientAddressCtrl.text = _invoice.clientAddress;
    _overallDiscountCtrl.text = _invoice.overallDiscountValue > 0
        ? _invoice.overallDiscountValue.round().toString()
        : '';
    _taxPercentCtrl.text = _invoice.taxPercent.toString();
    _depositCtrl.text = _invoice.depositPaid > 0
        ? _invoice.depositPaid.round().toString()
        : '';
    _notesCtrl.text = _invoice.notesAndTerms;
  }

  void _syncModelFromControllers() {
    _invoice.invoiceNumber = AppUtils.toEnglishDigits(_invoiceNumCtrl.text);
    _invoice.shamsiDate = AppUtils.toEnglishDigits(_dateCtrl.text);
    _invoice.clientName = _clientNameCtrl.text;
    _invoice.clientPhone = _clientPhoneCtrl.text;
    _invoice.clientNationalId = _clientNatIdCtrl.text;
    _invoice.clientAddress = _clientAddressCtrl.text;
    _invoice.overallDiscountValue =
        AppUtils.parseCurrency(_overallDiscountCtrl.text);
    _invoice.taxPercent =
        double.tryParse(AppUtils.toEnglishDigits(_taxPercentCtrl.text)) ?? 10.0;
    _invoice.depositPaid = AppUtils.parseCurrency(_depositCtrl.text);
    _invoice.notesAndTerms = _notesCtrl.text;
  }

  void _toggleCurrency(String newCurrency) {
    if (_invoice.currency == newCurrency) return;
    setState(() {
      _syncModelFromControllers();
      final factor = (newCurrency == 'ریال') ? 10.0 : 0.1;
      for (var item in _invoice.items) {
        item.unitPrice = (item.unitPrice * factor).roundToDouble();
        if (!item.isDiscountPercent) {
          item.discountValue = (item.discountValue * factor).roundToDouble();
        }
      }
      if (!_invoice.isOverallDiscountPercent) {
        _invoice.overallDiscountValue =
            (_invoice.overallDiscountValue * factor).roundToDouble();
        _overallDiscountCtrl.text = _invoice.overallDiscountValue > 0
            ? _invoice.overallDiscountValue.round().toString()
            : '';
      }
      _invoice.depositPaid = (_invoice.depositPaid * factor).roundToDouble();
      _depositCtrl.text = _invoice.depositPaid > 0
          ? _invoice.depositPaid.round().toString()
          : '';
      _invoice.currency = newCurrency;
    });
  }

  Future<void> _showJalaliDatePicker() async {
    final now = Jalali.now();
    int selYear = now.year;
    int selMonth = now.month;
    int selDay = now.day;

    final parts = AppUtils.toEnglishDigits(_dateCtrl.text).split('/');
    if (parts.length == 3) {
      selYear = int.tryParse(parts[0]) ?? now.year;
      selMonth = int.tryParse(parts[1]) ?? now.month;
      selDay = int.tryParse(parts[2]) ?? now.day;
    }

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final maxDays = Jalali(selYear, selMonth, 1).monthLength;
            if (selDay > maxDays) selDay = maxDays;

            return AlertDialog(
              title: const Text('انتخاب تاریخ شمسی',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              content: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Day
                  DropdownButton<int>(
                    value: selDay,
                    items: List.generate(maxDays, (i) => i + 1)
                        .map((d) => DropdownMenuItem(
                              value: d,
                              child: Text(AppUtils.toPersianDigits('$d')),
                            ))
                        .toList(),
                    onChanged: (v) => setModalState(() => selDay = v!),
                  ),
                  // Month
                  DropdownButton<int>(
                    value: selMonth,
                    items: List.generate(12, (i) => i + 1)
                        .map((m) => DropdownMenuItem(
                              value: m,
                              child: Text(AppUtils.toPersianDigits('$m')),
                            ))
                        .toList(),
                    onChanged: (v) => setModalState(() => selMonth = v!),
                  ),
                  // Year
                  DropdownButton<int>(
                    value: selYear,
                    items: List.generate(15, (i) => 1400 + i)
                        .map((y) => DropdownMenuItem(
                              value: y,
                              child: Text(AppUtils.toPersianDigits('$y')),
                            ))
                        .toList(),
                    onChanged: (v) => setModalState(() => selYear = v!),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('انصراف'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final formatted =
                        '$selYear/${selMonth.toString().padLeft(2, '0')}/${selDay.toString().padLeft(2, '0')}';
                    setState(() {
                      _dateCtrl.text = formatted;
                      _invoice.shamsiDate = formatted;
                    });
                    Navigator.pop(ctx);
                  },
                  child: const Text('تایید'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _pickFromCatalog() async {
    final catalog = await DatabaseHelper.instance.getCatalogItems();
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'انتخاب سریع از کاتالوگ خدمات و تجهیزات MR.Config',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: catalog.length,
                  itemBuilder: (_, idx) {
                    final c = catalog[idx];
                    return ListTile(
                      title: Text(c.description,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text(
                          '${c.category} | واحد: ${c.unit} | قیمت پیش‌فرض: ${AppUtils.formatNumber(c.defaultPrice)} تومان'),
                      trailing: const Icon(Icons.add_circle,
                          color: Color(0xFF0284C7)),
                      onTap: () {
                        setState(() {
                          final price = _invoice.currency == 'ریال'
                              ? c.defaultPrice * 10
                              : c.defaultPrice;
                          _invoice.items.add(
                            InvoiceLineItem(
                              description: c.description,
                              category: c.category,
                              unit: c.unit,
                              quantity: 1,
                              unitPrice: price,
                            ),
                          );
                        });
                        Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveInvoice({bool showSnack = true}) async {
    setState(() => _isSaving = true);
    _syncModelFromControllers();
    final id = await DatabaseHelper.instance.saveInvoice(_invoice);
    _invoice.id = id;
    setState(() => _isSaving = false);
    if (showSnack && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('فاکتور با موفقیت در آرشیو ذخیره شد.')),
      );
    }
  }

  Future<void> _exportAndShare({required bool asPdf}) async {
    await _saveInvoice(showSnack: false);
    final seller = await DatabaseHelper.instance.getSellerProfile();
    final tempDir = await getTemporaryDirectory();

    if (asPdf) {
      final bytes = await PdfInvoiceGenerator.generatePdf(
        invoice: _invoice,
        seller: seller,
      );
      final file =
          File('${tempDir.path}/MRConfig_Invoice_${_invoice.invoiceNumber}.pdf');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text:
            '${_invoice.isOfficialInvoice ? "فاکتور" : "پیش‌فاکتور"} شماره ${_invoice.invoiceNumber} - ${seller.brandName}',
      );
    } else {
      final pngBytes = await PdfInvoiceGenerator.generateHighResPng(
        invoice: _invoice,
        seller: seller,
      );
      final file =
          File('${tempDir.path}/MRConfig_Invoice_${_invoice.invoiceNumber}.png');
      await file.writeAsBytes(pngBytes);
      await Share.shareXFiles(
        [XFile(file.path)],
        text:
            'تصویر ${_invoice.isOfficialInvoice ? "فاکتور" : "پیش‌فاکتور"} شماره ${_invoice.invoiceNumber} - ${seller.brandName}',
      );
    }
  }

  Future<void> _previewPdf() async {
    await _saveInvoice(showSnack: false);
    final seller = await DatabaseHelper.instance.getSellerProfile();
    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('پیش‌نمایش چاپی A4 / A5')),
          body: PdfPreview(
            canChangeOrientation: false,
            build: (format) => PdfInvoiceGenerator.generatePdf(
              invoice: _invoice,
              seller: seller,
              isA5: format == PdfPageFormat.a5,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_invoiceNumCtrl.text.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_invoice.isOfficialInvoice
            ? 'فاکتور رسمی فروش و خدمات'
            : 'پیش‌فاکتور (Quotation)'),
        actions: [
          IconButton(
            tooltip: 'پیش‌نمایش و چاپ',
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _previewPdf,
          ),
          IconButton(
            tooltip: 'ذخیره در آرشیو',
            icon: const Icon(Icons.save_outlined),
            onPressed: () => _saveInvoice(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDocumentMetadataCard(),
            const SizedBox(height: 10),
            _buildClientDetailsCard(),
            const SizedBox(height: 10),
            _buildLineItemsSection(),
            const SizedBox(height: 10),
            _buildFinancialCalculationsCard(),
            const SizedBox(height: 16),
            _buildExportActionsRow(),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentMetadataCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Document Type Switcher
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: true,
                        label: Text('فاکتور رسمی فروش و خدمات',
                            style: TextStyle(fontSize: 12)),
                        icon: Icon(Icons.verified_outlined, size: 18),
                      ),
                      ButtonSegment(
                        value: false,
                        label:
                            Text('پیش‌فاکتور', style: TextStyle(fontSize: 12)),
                        icon: Icon(Icons.description_outlined, size: 18),
                      ),
                    ],
                    selected: {_invoice.isOfficialInvoice},
                    onSelectionChanged: (s) =>
                        setState(() => _invoice.isOfficialInvoice = s.first),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _invoiceNumCtrl,
                    decoration: const InputDecoration(
                      labelText: 'شماره فاکتور',
                      prefixIcon: Icon(Icons.tag, size: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _dateCtrl,
                    readOnly: true,
                    onTap: _showJalaliDatePicker,
                    decoration: const InputDecoration(
                      labelText: 'تاریخ شمسی',
                      prefixIcon: Icon(Icons.calendar_month, size: 18),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Currency Toggle
                Row(
                  children: [
                    const Text('واحد پول: ',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    ChoiceChip(
                      label: const Text('تومان'),
                      selected: _invoice.currency == 'تومان',
                      onSelected: (_) => _toggleCurrency('تومان'),
                    ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: const Text('ریال'),
                      selected: _invoice.currency == 'ریال',
                      onSelected: (_) => _toggleCurrency('ریال'),
                    ),
                  ],
                ),
                // Payment Status
                DropdownButton<String>(
                  value: _invoice.paymentStatus,
                  items: _statuses
                      .map((s) => DropdownMenuItem(
                            value: s,
                            child:
                                Text(s, style: const TextStyle(fontSize: 13)),
                          ))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _invoice.paymentStatus = v!),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClientDetailsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('مشخصات خریدار / کارفرما',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 10),
            TextField(
              controller: _clientNameCtrl,
              decoration: const InputDecoration(
                labelText: 'نام شخص یا شرکت کارفرما',
                prefixIcon: Icon(Icons.business, size: 18),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _clientPhoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'شماره تماس',
                      prefixIcon: Icon(Icons.phone_android, size: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _clientNatIdCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'کد ملی / اقتصادی (اختیاری)',
                      prefixIcon: Icon(Icons.badge_outlined, size: 18),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _clientAddressCtrl,
              decoration: const InputDecoration(
                labelText: 'نشانی پروژه / محل نصب و اجرا',
                prefixIcon: Icon(Icons.location_on_outlined, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineItemsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('ردیف‌های کالا و خدمات شبکه',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Row(
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.bolt, size: 18),
                      label: const Text('کاتالوگ سریع',
                          style: TextStyle(fontSize: 12)),
                      onPressed: _pickFromCatalog,
                    ),
                    const SizedBox(width: 6),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A192F),
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('افزودن ردیف',
                          style: TextStyle(fontSize: 12)),
                      onPressed: () {
                        setState(() {
                          _invoice.items.add(InvoiceLineItem());
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
            const Divider(),
            ...List.generate(_invoice.items.length, (index) {
              return _buildSingleLineItemCard(index);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSingleLineItemCard(int index) {
    final item = _invoice.items[index];
    return Container(
      key: ObjectKey(item),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: const Color(0xFF0A192F),
                child: Text(
                  AppUtils.toPersianDigits('${index + 1}'),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: item.description,
                  decoration: const InputDecoration(
                    labelText: 'شرح کالا یا خدمات (روتر، کابل‌کشی، نصب...)',
                  ),
                  onChanged: (v) => item.description = v,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: _invoice.items.length > 1
                    ? () => setState(() => _invoice.items.removeAt(index))
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Category Tag
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<String>(
                  value: item.category,
                  decoration: const InputDecoration(labelText: 'دسته‌بندی'),
                  items: _categories
                      .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c, style: const TextStyle(fontSize: 12))))
                      .toList(),
                  onChanged: (v) => setState(() => item.category = v!),
                ),
              ),
              const SizedBox(width: 6),
              // Quantity
              Expanded(
                flex: 2,
                child: TextFormField(
                  initialValue: item.quantity == item.quantity.roundToDouble()
                      ? item.quantity.round().toString()
                      : item.quantity.toString(),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'تعداد/متراژ'),
                  onChanged: (v) {
                    setState(() {
                      item.quantity =
                          double.tryParse(AppUtils.toEnglishDigits(v)) ?? 0.0;
                    });
                  },
                ),
              ),
              const SizedBox(width: 6),
              // Unit Selector
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: item.unit,
                  decoration: const InputDecoration(labelText: 'واحد'),
                  items: _units
                      .map((u) => DropdownMenuItem(
                          value: u,
                          child: Text(u, style: const TextStyle(fontSize: 12))))
                      .toList(),
                  onChanged: (v) => setState(() => item.unit = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Unit Price
              Expanded(
                flex: 3,
                child: TextFormField(
                  initialValue: item.unitPrice > 0
                      ? AppUtils.toEnglishDigits(
                          AppUtils.formatNumber(item.unitPrice))
                      : '',
                  keyboardType: TextInputType.number,
                  inputFormatters: [ThousandsSeparatorInputFormatter()],
                  decoration: InputDecoration(
                    labelText: 'قیمت واحد (${_invoice.currency})',
                  ),
                  onChanged: (v) {
                    setState(() {
                      item.unitPrice = AppUtils.parseCurrency(v);
                    });
                  },
                ),
              ),
              const SizedBox(width: 6),
              // Row Discount
              Expanded(
                flex: 3,
                child: TextFormField(
                  initialValue: item.discountValue > 0
                      ? item.discountValue.round().toString()
                      : '',
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText:
                        item.isDiscountPercent ? 'تخفیف (٪)' : 'تخفیف مبلغی',
                    suffixIcon: InkWell(
                      onTap: () {
                        setState(() {
                          item.isDiscountPercent = !item.isDiscountPercent;
                          item.discountValue = 0;
                        });
                      },
                      child: Container(
                        alignment: Alignment.center,
                        width: 36,
                        child: Text(
                          item.isDiscountPercent ? '٪' : _invoice.currency,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0284C7),
                              fontSize: 11),
                        ),
                      ),
                    ),
                  ),
                  onChanged: (v) {
                    setState(() {
                      item.discountValue = AppUtils.parseCurrency(v);
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('قیمت کل ردیف:',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                Text(
                  '${AppUtils.formatNumber(item.netTotal)} ${_invoice.currency}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF0A192F)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialCalculationsCard() {
    _syncModelFromControllers();
    final words =
        '${AppUtils.numberToPersianWords(_invoice.grandTotal.round())} ${_invoice.currency}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('محاسبات مالی و شرایط پایانی',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _overallDiscountCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: _invoice.isOverallDiscountPercent
                        ? []
                        : [ThousandsSeparatorInputFormatter()],
                    decoration: InputDecoration(
                      labelText: _invoice.isOverallDiscountPercent
                          ? 'تخفیف کلی (درصد)'
                          : 'تخفیف کلی (${_invoice.currency})',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 8),
                ToggleButtons(
                  isSelected: [
                    !_invoice.isOverallDiscountPercent,
                    _invoice.isOverallDiscountPercent
                  ],
                  onPressed: (idx) {
                    setState(() {
                      _invoice.isOverallDiscountPercent = (idx == 1);
                      _overallDiscountCtrl.clear();
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  children: [
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(_invoice.currency)),
                    const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text('درصد ٪')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            // VAT / Tax Toggle
            Row(
              children: [
                Switch(
                  value: _invoice.enableTax,
                  onChanged: (v) => setState(() => _invoice.enableTax = v),
                ),
                const Text('محاسبه مالیات و ارزش افزوده (VAT)'),
                const Spacer(),
                if (_invoice.enableTax)
                  SizedBox(
                    width: 90,
                    child: TextField(
                      controller: _taxPercentCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'درصد ٪'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _depositCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandsSeparatorInputFormatter()],
              decoration: InputDecoration(
                labelText: 'مبلغ پیش‌پرداخت / بیعانه (${_invoice.currency})',
                prefixIcon: const Icon(Icons.payments_outlined, size: 18),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            // Summary Display Box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0A192F),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _summaryLine('جمع کل ردیف‌ها:',
                      '${AppUtils.formatNumber(_invoice.subtotal)} ${_invoice.currency}'),
                  if (_invoice.overallDiscountAmount > 0)
                    _summaryLine('کسر تخفیف کلی:',
                        '${AppUtils.formatNumber(_invoice.overallDiscountAmount)} ${_invoice.currency}'),
                  if (_invoice.enableTax)
                    _summaryLine('مالیات و ارزش افزوده:',
                        '${AppUtils.formatNumber(_invoice.taxAmount)} ${_invoice.currency}'),
                  const Divider(color: Colors.white24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('مبلغ قابل پرداخت نهایی:',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14)),
                      Text(
                        '${AppUtils.formatNumber(_invoice.grandTotal)} ${_invoice.currency}',
                        style: const TextStyle(
                            color: Color(0xFF38BDF8),
                            fontWeight: FontWeight.bold,
                            fontSize: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'به حروف: $words',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  if (_invoice.depositPaid > 0) ...[
                    const Divider(color: Colors.white24),
                    _summaryLine('پیش‌پرداخت دریافتی:',
                        '${AppUtils.formatNumber(_invoice.depositPaid)} ${_invoice.currency}'),
                    _summaryLine('مانده حساب قابل تسویه:',
                        '${AppUtils.formatNumber(_invoice.remainingBalance)} ${_invoice.currency}'),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'شرایط پرداخت، گارانتی، مهلت اعتبار پیش‌فاکتور و توضیحات',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryLine(String title, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          Text(val,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildExportActionsRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0284C7),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text('تولید و ارسال مستقیم فایل PDF رسمی',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          onPressed: _isSaving ? null : () => _exportAndShare(asPdf: true),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 13),
            side: const BorderSide(color: Color(0xFF0A192F), width: 1.4),
          ),
          icon: const Icon(Icons.image_outlined),
          label: const Text('تولید و اشتراک‌گذاری تصویر باکیفیت (PNG)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          onPressed: _isSaving ? null : () => _exportAndShare(asPdf: false),
        ),
      ],
    );
  }
}
