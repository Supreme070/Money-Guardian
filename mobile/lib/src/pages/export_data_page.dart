import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/di/injection.dart';
import '../../data/repositories/auth_repository.dart';
import '../theme/light_color.dart';

class ExportDataPage extends StatefulWidget {
  const ExportDataPage({Key? key}) : super(key: key);

  @override
  State<ExportDataPage> createState() => _ExportDataPageState();
}

class _ExportDataPageState extends State<ExportDataPage> {
  bool _isLoading = false;
  bool _isExported = false;
  String? _errorMessage;
  Map<String, dynamic>? _exportedData;

  Future<void> _handleExport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await getIt<AuthRepository>().exportUserData();
      setState(() {
        _exportedData = data;
        _isExported = true;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to export data. Please try again.';
        _isLoading = false;
      });
    }
  }

  void _copyToClipboard() {
    if (_exportedData == null) return;

    final jsonString = const JsonEncoder.withIndent('  ').convert(_exportedData);
    Clipboard.setData(ClipboardData(text: jsonString));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Data copied to clipboard',
          style: GoogleFonts.mulish(fontWeight: FontWeight.w600),
        ),
        backgroundColor: LightColor.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LightColor.background,
      appBar: AppBar(
        backgroundColor: LightColor.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: LightColor.titleTextColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Export My Data',
          style: GoogleFonts.mulish(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: LightColor.titleTextColor,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: LightColor.accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: LightColor.accent.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: LightColor.accent, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Under GDPR Article 20, you have the right to receive a copy of your personal data in a portable format.',
                      style: GoogleFonts.mulish(
                        fontSize: 13,
                        color: LightColor.titleTextColor,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'What\'s included',
              style: GoogleFonts.mulish(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: LightColor.titleTextColor,
              ),
            ),
            const SizedBox(height: 12),

            _buildIncludedItem(Icons.person_outline, 'Profile information'),
            _buildIncludedItem(Icons.subscriptions_outlined, 'All subscriptions'),
            _buildIncludedItem(Icons.notifications_outlined, 'Alert history'),
            _buildIncludedItem(Icons.account_balance_outlined, 'Bank connection metadata'),
            _buildIncludedItem(Icons.email_outlined, 'Email connection metadata'),

            const SizedBox(height: 8),
            Text(
              'Sensitive tokens (bank access, OAuth) are never included.',
              style: GoogleFonts.mulish(
                fontSize: 12,
                color: LightColor.subTitleTextColor,
                fontStyle: FontStyle.italic,
              ),
            ),

            const SizedBox(height: 32),

            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: LightColor.freeze.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: LightColor.freeze, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: GoogleFonts.mulish(color: LightColor.freeze, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (_isExported && _exportedData != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: LightColor.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: LightColor.success.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle_outline, color: LightColor.success, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'Data exported successfully',
                      style: GoogleFonts.mulish(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: LightColor.success,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Exported at: ${_exportedData!['exported_at'] as String? ?? 'now'}',
                      style: GoogleFonts.mulish(
                        fontSize: 12,
                        color: LightColor.subTitleTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _copyToClipboard,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: Text(
                    'Copy to Clipboard',
                    style: GoogleFonts.mulish(fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: LightColor.accent,
                    side: const BorderSide(color: LightColor.accent),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleExport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: LightColor.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          'Export My Data',
                          style: GoogleFonts.mulish(fontSize: 15, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIncludedItem(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: LightColor.accent, size: 20),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.mulish(
              fontSize: 14,
              color: LightColor.titleTextColor,
            ),
          ),
        ],
      ),
    );
  }
}
