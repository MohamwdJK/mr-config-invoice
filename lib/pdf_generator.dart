import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'models.dart';
import 'utils.dart';

class PdfInvoiceGenerator {
  static const PdfColor navyColor = PdfColor.fromInt(0xFF0A192F);
  static const PdfColor slateColor = PdfColor.fromInt(0xFF334155);
  static const PdfColor accentBlue = PdfColor.fromInt(0xFF0284C7);
  static const PdfColor lightBg = PdfColor.fromInt(0xFFF8FAFC);
  static const PdfColor borderColor = PdfColor.fromInt(0xFFCBD5E1);

  static Future<Uint8List> generatePdf({
    required InvoiceDocument invoice,
    required SellerProfile seller,
    bool isA5 = false,
  }) async {
    final fontRegularData =
        await rootBundle.load('assets/fonts/Vazirmatn-Regular.ttf');
    final fontBoldData =
        await rootBundle.load('assets/fonts/Vazirmatn-Bold.ttf');

    final ttfRegular = pw.Font.ttf(fontRegularData);
    final ttfBold = pw.Font.ttf(fontBoldData);

    pw.MemoryImage? logoImage;
    if (seller.logoPath != null && File(seller.logoPath!).existsSync()) {
      logoImage = pw.MemoryImage(File(seller.logoPath!).readAsBytesSync());
    }

    pw.MemoryImage? stampImage;
    if (seller.stampPath != null && File(seller.stampPath!).existsSync()) {
      stampImage = pw.MemoryImage(File(seller.stampPath!).readAsBytesSync());
    }

    final pdf = pw.Document();
    final pageFormat = isA5 ? PdfPageFormat.a5 : PdfPageFormat.a4;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(24),
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(
          base: ttfRegular,
          bold: ttfBold,
        ),
        build: (context) => [
          _buildHeader(invoice, seller, logoImage),
          pw.SizedBox(height: 10),
          _buildClientSection(invoice),
          pw.SizedBox(height: 12),
          _buildItemsTable(invoice),
          pw.SizedBox(height: 12),
          _buildFinancialSummary(invoice),
          pw.SizedBox(height: 12),
          _buildFooterAndSignature(invoice, seller, stampImage),
        ],
      ),
    );

    return pdf.save();
  }

  /// Rasterizes the generated PDF into a High-Resolution (300 DPI) PNG image
  static Future<Uint8List> generateHighResPng({
    required InvoiceDocument invoice,
    required SellerProfile seller,
  }) async {
    final pdfBytes = await generatePdf(invoice: invoice, seller: seller);
    await for (final page in Printing.raster(pdfBytes, pages: [0], dpi: 300)) {
      return await page.toPng();
    }
    throw Exception('خطا در تولید تصویر فاکتور');
  }

  static pw.Widget _buildHeader(
    InvoiceDocument invoice,
    SellerProfile seller,
    pw.MemoryImage? logo,
  ) {
    final docTitle = invoice.isOfficialInvoice
        ? 'فاکتور رسمی فروش و خدمات'
        : 'پیش‌فاکتور فروش و خدمات';

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: navyColor,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Right side: Brand Logo & Title
          pw.Row(
            children: [
              if (logo != null) ...[
                pw.Container(
                  width: 52,
                  height: 52,
                  padding: const pw.EdgeInsets.all(4),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Image(logo, fit: pw.BoxFit.contain),
                ),
                pw.SizedBox(width: 10),
              ],
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    seller.brandName,
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    seller.subtitle,
                    style: const pw.TextStyle(
                      color: PdfColor.fromInt(0xFF94A3B8),
                      fontSize: 8.5,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: pw.BoxDecoration(
                      color: accentBlue,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Text(
                      docTitle,
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontSize: 9.5,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          // Left side: Metadata (Invoice Number, Date, Currency)
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              color: slateColor,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'شماره سند: ${AppUtils.toPersianDigits(invoice.invoiceNumber)}',
                  style: pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  'تاریخ صدور: ${AppUtils.toPersianDigits(invoice.shamsiDate)}',
                  style: const pw.TextStyle(
                    color: PdfColors.white,
                    fontSize: 9,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  'واحد مالی: ${invoice.currency}',
                  style: const pw.TextStyle(
                    color: PdfColor.fromInt(0xFF38BDF8),
                    fontSize: 8.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildClientSection(InvoiceDocument invoice) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: lightBg,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: borderColor, width: 0.8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Expanded(
                flex: 2,
                child: pw.Text(
                  'خریدار / کارفرما: ${invoice.clientName.isEmpty ? "-" : invoice.clientName}',
                  style: pw.TextStyle(
                      fontSize: 9.5,
                      fontWeight: pw.FontWeight.bold,
                      color: navyColor),
                ),
              ),
              pw.Expanded(
                flex: 1,
                child: pw.Text(
                  'شماره تماس: ${invoice.clientPhone.isEmpty ? "-" : AppUtils.toPersianDigits(invoice.clientPhone)}',
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),
              if (invoice.clientNationalId.isNotEmpty)
                pw.Expanded(
                  flex: 1,
                  child: pw.Text(
                    'کد ملی/اقتصادی: ${AppUtils.toPersianDigits(invoice.clientNationalId)}',
                    style: const pw.TextStyle(fontSize: 8.5),
                  ),
                ),
            ],
          ),
          if (invoice.clientAddress.isNotEmpty) ...[
            pw.SizedBox(height: 5),
            pw.Text(
              'نشانی پروژه / محل اجرا: ${invoice.clientAddress}',
              style: const pw.TextStyle(fontSize: 8.5, color: slateColor),
            ),
          ],
        ],
      ),
    );
  }

  static pw.Widget _buildItemsTable(InvoiceDocument invoice) {
    final headers = [
      'ردیف',
      'شرح کالا یا خدمات مهندسی شبکه',
      'دسته',
      'تعداد/متراژ',
      'واحد',
      'قیمت واحد',
      'تخفیف',
      'مبلغ کل (${invoice.currency})',
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: borderColor, width: 0.7),
      columnWidths: {
        0: const pw.FixedColumnWidth(26), // ردیف
        1: const pw.FlexColumnWidth(3.2), // شرح
        2: const pw.FixedColumnWidth(52), // دسته
        3: const pw.FixedColumnWidth(42), // تعداد
        4: const pw.FixedColumnWidth(35), // واحد
        5: const pw.FixedColumnWidth(68), // قیمت واحد
        6: const pw.FixedColumnWidth(54), // تخفیف
        7: const pw.FixedColumnWidth(78), // مبلغ کل
      },
      children: [
        // Table Header Row
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: navyColor),
          children: headers
              .map(
                (h) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                      vertical: 6, horizontal: 4),
                  child: pw.Text(
                    h,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        // Data Rows
        ...List.generate(invoice.items.length, (index) {
          final item = invoice.items[index];
          final isEven = index % 2 == 0;
          return pw.TableRow(
            decoration: pw.BoxDecoration(
              color: isEven ? PdfColors.white : lightBg,
            ),
            children: [
              _cell(AppUtils.toPersianDigits('${index + 1}')),
              _cell(item.description, align: pw.TextAlign.right, bold: true),
              _cell(item.category, fontSize: 7.5),
              _cell(AppUtils.formatDecimal(item.quantity)),
              _cell(item.unit),
              _cell(AppUtils.formatNumber(item.unitPrice)),
              _cell(item.discountAmount > 0
                  ? AppUtils.formatNumber(item.discountAmount)
                  : '۰'),
              _cell(AppUtils.formatNumber(item.netTotal), bold: true),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _cell(
    String text, {
    pw.TextAlign align = pw.TextAlign.center,
    bool bold = false,
    double fontSize = 8.5,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          fontSize: fontSize,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: navyColor,
        ),
      ),
    );
  }

  static pw.Widget _buildFinancialSummary(InvoiceDocument invoice) {
    final words =
        '${AppUtils.numberToPersianWords(invoice.grandTotal.round())} ${invoice.currency}';

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: lightBg,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: borderColor, width: 0.8),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Right side: Amount in words & Notes
          pw.Expanded(
            flex: 3,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.all(6),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(4),
                    border: pw.Border.all(color: borderColor, width: 0.5),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Text(
                        'مبلغ قابل پرداخت به حروف: ',
                        style: pw.TextStyle(
                            fontSize: 8.5,
                            fontWeight: pw.FontWeight.bold,
                            color: accentBlue),
                      ),
                      pw.Expanded(
                        child: pw.Text(
                          words,
                          style: pw.TextStyle(
                              fontSize: 8.5,
                              fontWeight: pw.FontWeight.bold,
                              color: navyColor),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'شرایط پرداخت، گارانتی و توضیحات:',
                  style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: slateColor),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  invoice.notesAndTerms,
                  style: const pw.TextStyle(fontSize: 8, color: slateColor),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 12),
          // Left side: Calculation Table
          pw.Expanded(
            flex: 2,
            child: pw.Column(
              children: [
                _summaryRow('جمع کل ردیف‌ها:',
                    '${AppUtils.formatNumber(invoice.subtotal)} ${invoice.currency}'),
                if (invoice.overallDiscountAmount > 0)
                  _summaryRow('تخفیف کلی:',
                      '${AppUtils.formatNumber(invoice.overallDiscountAmount)} -'),
                if (invoice.enableTax)
                  _summaryRow(
                      'مالیات و ارزش افزوده (${AppUtils.formatDecimal(invoice.taxPercent)}٪):',
                      '${AppUtils.formatNumber(invoice.taxAmount)} +'),
                pw.Divider(color: borderColor, height: 8),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      vertical: 5, horizontal: 6),
                  decoration: pw.BoxDecoration(
                    color: navyColor,
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'مبلغ قابل پرداخت:',
                        style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        '${AppUtils.formatNumber(invoice.grandTotal)} ${invoice.currency}',
                        style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 9.5,
                            fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                if (invoice.depositPaid > 0) ...[
                  pw.SizedBox(height: 4),
                  _summaryRow('پیش‌پرداخت / بیعانه:',
                      '${AppUtils.formatNumber(invoice.depositPaid)} ${invoice.currency}'),
                  _summaryRow(
                    'مانده حساب نهایی:',
                    '${AppUtils.formatNumber(invoice.remainingBalance)} ${invoice.currency}',
                    isBold: true,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _summaryRow(String label, String value,
      {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: slateColor,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 8.5,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: navyColor,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooterAndSignature(
    InvoiceDocument invoice,
    SellerProfile seller,
    pw.MemoryImage? stampImage,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: borderColor, width: 0.8),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          // Payment & Seller Details
          pw.Expanded(
            flex: 3,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'اطلاعات پرداخت بانکی (${seller.brandName}):',
                  style: pw.TextStyle(
                      fontSize: 8.5,
                      fontWeight: pw.FontWeight.bold,
                      color: navyColor),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  'شماره کارت: ${AppUtils.toPersianDigits(seller.cardNumber)}  |  به نام: ${seller.accountHolder}',
                  style: pw.TextStyle(
                      fontSize: 8.5, fontWeight: pw.FontWeight.bold),
                ),
                if (seller.shebaNumber.isNotEmpty)
                  pw.Text(
                    'شماره شبا: ${seller.shebaNumber}',
                    style: const pw.TextStyle(fontSize: 8, color: slateColor),
                  ),
                pw.Divider(color: borderColor, height: 10),
                pw.Text(
                  'تلفن پشتیبانی: ${AppUtils.toPersianDigits(seller.phone)}   |   وب‌سایت: ${seller.website}',
                  style: const pw.TextStyle(fontSize: 8, color: slateColor),
                ),
                pw.Text(
                  'نشانی: ${seller.address}',
                  style: const pw.TextStyle(fontSize: 8, color: slateColor),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 10),
          // Stamp & Signatures
          pw.Expanded(
            flex: 2,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
              children: [
                pw.Column(
                  children: [
                    pw.Text(
                      'مهر و امضای فروشنده',
                      style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: slateColor),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Container(
                      width: 85,
                      height: 65,
                      alignment: pw.Alignment.center,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(
                            color: borderColor,
                            width: 0.5,
                            style: pw.BorderStyle.dashed),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: stampImage != null
                          ? pw.Image(stampImage, fit: pw.BoxFit.contain)
                          : pw.Text('محل مهر و امضا',
                              style: const pw.TextStyle(
                                  fontSize: 7, color: borderColor)),
                    ),
                  ],
                ),
                pw.Column(
                  children: [
                    pw.Text(
                      'مهر و امضای خریدار',
                      style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: slateColor),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Container(
                      width: 85,
                      height: 65,
                      alignment: pw.Alignment.center,
                      decoration: pw.BoxDecoration(
                        border: pw.Border.all(
                            color: borderColor,
                            width: 0.5,
                            style: pw.BorderStyle.dashed),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Text('محل امضا',
                          style: const pw.TextStyle(
                              fontSize: 7, color: borderColor)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
