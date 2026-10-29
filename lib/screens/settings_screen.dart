import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../db_helper.dart';
import '../models.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  SellerProfile _profile = SellerProfile();
  final _brandCtrl = TextEditingController();
  final _subtitleCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  final _cardCtrl = TextEditingController();
  final _shebaCtrl = TextEditingController();
  final _holderCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final p = await DatabaseHelper.instance.getSellerProfile();
    setState(() {
      _profile = p;
      _brandCtrl.text = p.brandName;
      _subtitleCtrl.text = p.subtitle;
      _phoneCtrl.text = p.phone;
      _addressCtrl.text = p.address;
      _websiteCtrl.text = p.website;
      _cardCtrl.text = p.cardNumber;
      _shebaCtrl.text = p.shebaNumber;
      _holderCtrl.text = p.accountHolder;
    });
  }

  Future<void> _pickImage({required bool isLogo}) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final appDir = await getApplicationDocumentsDirectory();
    final fileName = isLogo ? 'mr_config_logo.png' : 'mr_config_stamp.png';
    final savedFile =
        await File(picked.path).copy('${appDir.path}/$fileName');

    setState(() {
      if (isLogo) {
        _profile.logoPath = savedFile.path;
      } else {
        _profile.stampPath = savedFile.path;
      }
    });
  }

  Future<void> _saveSettings() async {
    _profile.brandName = _brandCtrl.text.trim();
    _profile.subtitle = _subtitleCtrl.text.trim();
    _profile.phone = _phoneCtrl.text.trim();
    _profile.address = _addressCtrl.text.trim();
    _profile.website = _websiteCtrl.text.trim();
    _profile.cardNumber = _cardCtrl.text.trim();
    _profile.shebaNumber = _shebaCtrl.text.trim();
    _profile.accountHolder = _holderCtrl.text.trim();

    await DatabaseHelper.instance.saveSellerProfile(_profile);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('تنظیمات برند و اطلاعات پرداخت ذخیره شد.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تنظیمات برند MR.Config')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('لوگوی برند و تصویر مهر / امضای دیجیتال',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        // Brand Logo Picker
                        Column(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade400),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: (_profile.logoPath != null &&
                                      File(_profile.logoPath!).existsSync())
                                  ? Image.file(File(_profile.logoPath!),
                                      fit: BoxFit.contain)
                                  : const Icon(Icons.add_photo_alternate,
                                      size: 40, color: Colors.grey),
                            ),
                            const SizedBox(height: 6),
                            OutlinedButton(
                              onPressed: () => _pickImage(isLogo: true),
                              child: const Text('انتخاب لوگو'),
                            ),
                          ],
                        ),
                        // Digital Stamp / Signature Picker
                        Column(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade400),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: (_profile.stampPath != null &&
                                      File(_profile.stampPath!).existsSync())
                                  ? Image.file(File(_profile.stampPath!),
                                      fit: BoxFit.contain)
                                  : const Icon(Icons.approval,
                                      size: 40, color: Colors.grey),
                            ),
                            const SizedBox(height: 6),
                            OutlinedButton(
                              onPressed: () => _pickImage(isLogo: false),
                              child: const Text('انتخاب مهر و امضا'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('مشخصات سازمانی و اطلاعات تماس',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _brandCtrl,
                      decoration: const InputDecoration(
                          labelText: 'نام تجاری (MR.Config)'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _subtitleCtrl,
                      decoration:
                          const InputDecoration(labelText: 'عنوان تخصصی زیرین'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _phoneCtrl,
                      decoration:
                          const InputDecoration(labelText: 'شماره تماس پشتیبانی'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _websiteCtrl,
                      decoration: const InputDecoration(
                          labelText: 'وب‌سایت / شبکه اجتماعی'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _addressCtrl,
                      decoration:
                          const InputDecoration(labelText: 'نشانی دفتر / فروشگاه'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('اطلاعات بانکی (درج خودکار در فوتر فاکتور)',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _holderCtrl,
                      decoration:
                          const InputDecoration(labelText: 'نام صاحب حساب'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _cardCtrl,
                      decoration:
                          const InputDecoration(labelText: 'شماره کارت بانکی'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _shebaCtrl,
                      decoration:
                          const InputDecoration(labelText: 'شماره شبا (IBAN)'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A192F),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.save),
              label: const Text('ذخیره تنظیمات دائمی',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: _saveSettings,
            ),
          ],
        ),
      ),
    );
  }
}
