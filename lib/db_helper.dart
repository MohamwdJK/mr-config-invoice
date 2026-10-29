import 'dart:convert';
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'models.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('mr_config_invoices.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        isOfficialInvoice INTEGER NOT NULL,
        invoiceNumber TEXT NOT NULL,
        shamsiDate TEXT NOT NULL,
        clientName TEXT NOT NULL,
        clientPhone TEXT NOT NULL,
        clientNationalId TEXT NOT NULL,
        clientAddress TEXT NOT NULL,
        currency TEXT NOT NULL,
        itemsJson TEXT NOT NULL,
        overallDiscountValue REAL NOT NULL,
        isOverallDiscountPercent INTEGER NOT NULL,
        enableTax INTEGER NOT NULL,
        taxPercent REAL NOT NULL,
        depositPaid REAL NOT NULL,
        paymentStatus TEXT NOT NULL,
        notesAndTerms TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE catalog (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        description TEXT NOT NULL,
        category TEXT NOT NULL,
        unit TEXT NOT NULL,
        defaultPrice REAL NOT NULL
      )
    ''');

    // Pre-populate MR.Config Default Network & Surveillance Catalog
    final defaultItems = [
      CatalogItem(
        description: 'کانفیگ تخصصی روتر و سوئیچ (MikroTik / Cisco)',
        category: 'خدمات و اجرت',
        unit: 'عدد',
        defaultPrice: 3500000,
      ),
      CatalogItem(
        description: 'کابل‌کشی ساخت‌یافته شبکه (Passive) و داکت‌کشی',
        category: 'خدمات و اجرت',
        unit: 'متر',
        defaultPrice: 85000,
      ),
      CatalogItem(
        description: 'نصب، فوکوس و راه‌اندازی دوربین مداربسته IP',
        category: 'خدمات و اجرت',
        unit: 'عدد',
        defaultPrice: 750000,
      ),
      CatalogItem(
        description: 'آرایش رک، نصب پچ‌پنل و لیبل‌گذاری کامل نودها',
        category: 'خدمات و اجرت',
        unit: 'پروژه',
        defaultPrice: 4200000,
      ),
      CatalogItem(
        description: 'پچ‌کورد شبکه Cat6 لگراند ۱ متری',
        category: 'تجهیزات',
        unit: 'عدد',
        defaultPrice: 145000,
      ),
      CatalogItem(
        description: 'سوئیچ شبکه مدیریتی ۲۴ پورت گیگابیت PoE',
        category: 'تجهیزات',
        unit: 'عدد',
        defaultPrice: 18500000,
      ),
      CatalogItem(
        description: 'کابل شبکه تمام مس Cat6 نگزنس (Nexans)',
        category: 'تجهیزات',
        unit: 'متر',
        defaultPrice: 32000,
      ),
    ];

    for (final item in defaultItems) {
      await db.insert('catalog', item.toMap());
    }
  }

  // Seller Profile Persistence
  Future<SellerProfile> getSellerProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString('seller_profile');
    if (str == null) return SellerProfile();
    return SellerProfile.fromJson(jsonDecode(str));
  }

  Future<void> saveSellerProfile(SellerProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('seller_profile', jsonEncode(profile.toJson()));
  }

  // Next Auto-Incrementing Invoice Number
  Future<String> getNextInvoiceNumber() async {
    final prefs = await SharedPreferences.getInstance();
    int lastNum = prefs.getInt('last_invoice_seq') ?? 1403000;
    return (lastNum + 1).toString();
  }

  Future<void> updateInvoiceSequence(String usedNumber) async {
    final parsed = int.tryParse(usedNumber);
    if (parsed != null) {
      final prefs = await SharedPreferences.getInstance();
      int current = prefs.getInt('last_invoice_seq') ?? 1403000;
      if (parsed > current) {
        await prefs.setInt('last_invoice_seq', parsed);
      }
    }
  }

  // Invoice CRUD
  Future<int> saveInvoice(InvoiceDocument invoice) async {
    final db = await instance.database;
    await updateInvoiceSequence(invoice.invoiceNumber);
    if (invoice.id == null) {
      return await db.insert('invoices', invoice.toMap());
    } else {
      await db.update(
        'invoices',
        invoice.toMap(),
        where: 'id = ?',
        whereArgs: [invoice.id],
      );
      return invoice.id!;
    }
  }

  Future<List<InvoiceDocument>> getAllInvoices() async {
    final db = await instance.database;
    final result = await db.query('invoices', orderBy: 'id DESC');
    return result.map((json) => InvoiceDocument.fromMap(json)).toList();
  }

  Future<int> deleteInvoice(int id) async {
    final db = await instance.database;
    return await db.delete('invoices', where: 'id = ?', whereArgs: [id]);
  }

  // Catalog CRUD
  Future<List<CatalogItem>> getCatalogItems() async {
    final db = await instance.database;
    final res = await db.query('catalog', orderBy: 'id DESC');
    return res.map((e) => CatalogItem.fromMap(e)).toList();
  }

  Future<int> insertCatalogItem(CatalogItem item) async {
    final db = await instance.database;
    return await db.insert('catalog', item.toMap());
  }

  Future<int> deleteCatalogItem(int id) async {
    final db = await instance.database;
    return await db.delete('catalog', where: 'id = ?', whereArgs: [id]);
  }
}
