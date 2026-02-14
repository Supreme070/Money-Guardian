import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/di/injection.dart';
import '../../core/services/analytics_service.dart';
import '../theme/app_theme_provider.dart';
import '../theme/light_color.dart';

class AppearanceSettingsPage extends StatefulWidget {
  const AppearanceSettingsPage({Key? key}) : super(key: key);

  @override
  State<AppearanceSettingsPage> createState() => _AppearanceSettingsPageState();
}

class _AppearanceSettingsPageState extends State<AppearanceSettingsPage> {
  late final AppThemeProvider _themeProvider;

  @override
  void initState() {
    super.initState();
    _themeProvider = getIt<AppThemeProvider>();
    getIt<AnalyticsService>().logScreenView(screenName: 'AppearanceSettings');
  }

  String get _selectedTheme => _themeProvider.themeModeLabel;

  void _onThemeSelected(String value) {
    switch (value) {
      case 'light':
        _themeProvider.setLight();
        break;
      case 'dark':
        _themeProvider.setDark();
        break;
      default:
        _themeProvider.setSystem();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F1419) : LightColor.background;
    final textColor = isDark ? const Color(0xFFF0F2F5) : LightColor.titleTextColor;
    final subtitleColor = isDark ? const Color(0xFFAEB5BD) : LightColor.subTitleTextColor;
    final surfaceColor = isDark ? const Color(0xFF1C2530) : LightColor.lightGrey;
    final greyColor = isDark ? const Color(0xFF7B8FA6) : LightColor.grey;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Appearance',
          style: GoogleFonts.mulish(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        centerTitle: true,
      ),
      body: ListenableBuilder(
        listenable: _themeProvider,
        builder: (context, _) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Theme',
                style: GoogleFonts.mulish(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),
              _buildThemeOption(
                title: 'Light',
                subtitle: 'Clean white theme',
                icon: Icons.light_mode_rounded,
                value: 'light',
                previewColors: [const Color(0xFFFFFFFF), const Color(0xFFF1F1F3)],
                textColor: textColor,
                subtitleColor: subtitleColor,
                surfaceColor: surfaceColor,
                greyColor: greyColor,
              ),
              const SizedBox(height: 12),
              _buildThemeOption(
                title: 'Dark',
                subtitle: 'Guardian Charcoal theme',
                icon: Icons.dark_mode_rounded,
                value: 'dark',
                previewColors: [const Color(0xFF0F1419), const Color(0xFF1C2530)],
                textColor: textColor,
                subtitleColor: subtitleColor,
                surfaceColor: surfaceColor,
                greyColor: greyColor,
              ),
              const SizedBox(height: 12),
              _buildThemeOption(
                title: 'System',
                subtitle: 'Follow device settings',
                icon: Icons.brightness_auto_rounded,
                value: 'system',
                previewColors: [const Color(0xFF0F1419), const Color(0xFFFFFFFF)],
                textColor: textColor,
                subtitleColor: subtitleColor,
                surfaceColor: surfaceColor,
                greyColor: greyColor,
              ),
              const SizedBox(height: 28),
              Text(
                'Display',
                style: GoogleFonts.mulish(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 16),
              _buildDisplayOption(
                icon: Icons.format_size_rounded,
                title: 'Text Size',
                value: 'Default',
                textColor: textColor,
                subtitleColor: subtitleColor,
                surfaceColor: surfaceColor,
                greyColor: greyColor,
              ),
              const SizedBox(height: 12),
              _buildDisplayOption(
                icon: Icons.monetization_on_rounded,
                title: 'Amount Format',
                value: '\$1,234.56',
                textColor: textColor,
                subtitleColor: subtitleColor,
                surfaceColor: surfaceColor,
                greyColor: greyColor,
              ),
              const SizedBox(height: 12),
              _buildDisplayOption(
                icon: Icons.calendar_today_rounded,
                title: 'Date Format',
                value: 'Jan 28, 2026',
                textColor: textColor,
                subtitleColor: subtitleColor,
                surfaceColor: surfaceColor,
                greyColor: greyColor,
              ),
            ],
          ),
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
    required Color textColor,
    required Color subtitleColor,
    required Color surfaceColor,
    required Color greyColor,
  }) {
    final isSelected = _selectedTheme == value;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onThemeSelected(value),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: isSelected
                ? Border.all(color: LightColor.accent, width: 2)
                : null,
          ),
          child: Row(
            children: [
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
                    color: greyColor.withValues(alpha: 0.3),
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
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.mulish(
                        fontSize: 12,
                        color: subtitleColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle_rounded, color: LightColor.accent, size: 24)
              else
                Icon(Icons.circle_outlined, color: greyColor.withValues(alpha: 0.5), size: 24),
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
    required Color textColor,
    required Color subtitleColor,
    required Color surfaceColor,
    required Color greyColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: LightColor.accent.withValues(alpha: 0.1),
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
                color: textColor,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.mulish(
              fontSize: 13,
              color: subtitleColor,
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded, color: greyColor),
        ],
      ),
    );
  }
}
