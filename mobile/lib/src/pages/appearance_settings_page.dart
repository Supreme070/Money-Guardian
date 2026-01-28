import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/light_color.dart';

class AppearanceSettingsPage extends StatefulWidget {
  const AppearanceSettingsPage({Key? key}) : super(key: key);

  @override
  State<AppearanceSettingsPage> createState() => _AppearanceSettingsPageState();
}

class _AppearanceSettingsPageState extends State<AppearanceSettingsPage> {
  String _selectedTheme = 'dark'; // Current app theme

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
          'Appearance',
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
            Text(
              'Theme',
              style: GoogleFonts.mulish(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: LightColor.titleTextColor,
              ),
            ),
            const SizedBox(height: 16),
            _buildThemeOption(
              title: 'Dark',
              subtitle: 'Guardian Charcoal theme',
              icon: Icons.dark_mode_rounded,
              value: 'dark',
              previewColors: [const Color(0xFF121212), const Color(0xFF333232)],
            ),
            const SizedBox(height: 12),
            _buildThemeOption(
              title: 'Light',
              subtitle: 'Clean white theme',
              icon: Icons.light_mode_rounded,
              value: 'light',
              previewColors: [const Color(0xFFFFFFFF), const Color(0xFFF1F1F3)],
            ),
            const SizedBox(height: 12),
            _buildThemeOption(
              title: 'System',
              subtitle: 'Follow device settings',
              icon: Icons.brightness_auto_rounded,
              value: 'system',
              previewColors: [const Color(0xFF121212), const Color(0xFFFFFFFF)],
            ),
            const SizedBox(height: 28),
            Text(
              'Display',
              style: GoogleFonts.mulish(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: LightColor.titleTextColor,
              ),
            ),
            const SizedBox(height: 16),
            _buildDisplayOption(
              icon: Icons.format_size_rounded,
              title: 'Text Size',
              value: 'Default',
            ),
            const SizedBox(height: 12),
            _buildDisplayOption(
              icon: Icons.monetization_on_rounded,
              title: 'Amount Format',
              value: '\$1,234.56',
            ),
            const SizedBox(height: 12),
            _buildDisplayOption(
              icon: Icons.calendar_today_rounded,
              title: 'Date Format',
              value: 'Jan 28, 2026',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required String value,
    required List<Color> previewColors,
  }) {
    final isSelected = _selectedTheme == value;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() => _selectedTheme = value);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: LightColor.lightGrey,
            borderRadius: BorderRadius.circular(16),
            border: isSelected
                ? Border.all(color: LightColor.accent, width: 2)
                : null,
          ),
          child: Row(
            children: [
              // Theme preview
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: previewColors,
                  ),
                  border: Border.all(
                    color: LightColor.grey.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Icon(icon, color: LightColor.accent, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.mulish(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: LightColor.titleTextColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.mulish(
                        fontSize: 12,
                        color: LightColor.subTitleTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle_rounded, color: LightColor.accent, size: 24)
              else
                Icon(Icons.circle_outlined, color: LightColor.grey.withOpacity(0.5), size: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDisplayOption({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: LightColor.lightGrey,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: LightColor.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: LightColor.accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.mulish(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: LightColor.titleTextColor,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.mulish(
              fontSize: 13,
              color: LightColor.subTitleTextColor,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, color: LightColor.grey),
        ],
      ),
    );
  }
}
