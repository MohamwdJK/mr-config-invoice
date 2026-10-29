import 'package:flutter/material.dart';
import '../db_helper.dart';
import '../models.dart';
import '../utils.dart';

class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  List<CatalogItem> _items = [];

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    final list = await DatabaseHelper.instance.getCatalogItems();
    setState(() => _items = list);
  }

  Future<void> _showAddDialog() async {
    final descCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    String category = 'تجهیزات';
    String unit = 'عدد';

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('افزودن آیتم به کاتالوگ MR.Config',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: descCtrl,
                      decoration: const InputDecoration(
                          labelText: 'شرح کالا یا خدمات مهندسی'),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: category,
                      decoration: const InputDecoration(labelText: 'دسته‌بندی'),
                      items: ['تجهیزات', 'خدمات و اجرت']
                          .map((c) =>
                              DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) => setModalState(() => category = v!),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: unit,
                      decoration: const InputDecoration(labelText: 'واحد'),
                      items: ['عدد', 'متر', 'شاخه', 'ساعت', 'پروژه']
                          .map((u) =>
                              DropdownMenuItem(value: u, child: Text(u)))
                          .toList(),
                      onChanged: (v) => setModalState(() => unit = v!),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: priceCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [ThousandsSeparatorInputFormatter()],
                      decoration: const InputDecoration(
                          labelText: 'قیمت پیش‌فرض (تومان)'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('انصراف'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (descCtrl.text.trim().isEmpty) return;
                    await DatabaseHelper.instance.insertCatalogItem(
                      CatalogItem(
                        description: descCtrl.text.trim(),
                        category: category,
                        unit: unit,
                        defaultPrice: AppUtils.parseCurrency(priceCtrl.text),
                      ),
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    _loadCatalog();
                  },
                  child: const Text('ذخیره'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('کاتالوگ خدمات و تجهیزات شبکه')),
      body: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _items.length,
        itemBuilder: (_, idx) {
          final item = _items[idx];
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(item.description,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                  '${item.category}  |  واحد: ${item.unit}  |  قیمت: ${AppUtils.formatNumber(item.defaultPrice)} تومان'),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () async {
                  await DatabaseHelper.instance.deleteCatalogItem(item.id!);
                  _loadCatalog();
                },
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        icon: const Icon(Icons.add),
        label: const Text('کالا / خدمت جدید'),
      ),
    );
  }
}
