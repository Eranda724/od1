import 'package:flutter/material.dart';
import '../app_settings.dart';
import '../services/notification_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = AppSettings();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── APPEARANCE SECTION ──
          _sectionHeader('Appearance'),
          const SizedBox(height: 8),
          _card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.grid_view_rounded),
                  title: const Text('Exercise Grid View'),
                  value: _settings.isGridView,
                  activeColor: const Color(0xFF4CAF7D), // PCColors.green
                  onChanged: (v) async {
                    await _settings.setGridView(v);
                    setState(() {});
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.light_mode_rounded),
                  title: const Text('Light Mode'),
                  trailing: Radio<ThemeMode>(
                    value: ThemeMode.light,
                    groupValue: _settings.themeMode,
                    onChanged: (v) async {
                      await _settings.setThemeMode(v!);
                      setState(() {});
                    },
                  ),
                  onTap: () async {
                    await _settings.setThemeMode(ThemeMode.light);
                    setState(() {});
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.dark_mode_rounded),
                  title: const Text('Dark Mode'),
                  trailing: Radio<ThemeMode>(
                    value: ThemeMode.dark,
                    groupValue: _settings.themeMode,
                    onChanged: (v) async {
                      await _settings.setThemeMode(v!);
                      setState(() {});
                    },
                  ),
                  onTap: () async {
                    await _settings.setThemeMode(ThemeMode.dark);
                    setState(() {});
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── NOTIFICATIONS SECTION ──
          _sectionHeader('Notifications'),
          const SizedBox(height: 8),
          _card(
            child: SwitchListTile(
              secondary: const Icon(Icons.notifications_rounded),
              title: const Text('Daily Reminders'),
              subtitle: const Text('Morning & evening workout nudges'),
              value: _settings.notificationsEnabled,
              activeColor: const Color(0xFFFFC72C),
              onChanged: (v) async {
                await _settings.setNotificationsEnabled(v);
                if (v) {
                  await NotificationService.instance.refreshSchedule();
                } else {
                  await NotificationService.instance.cancelAll();
                }
                setState(() {});
              },
            ),
          ),

          const SizedBox(height: 24),

          // ── LANGUAGE SECTION ──
          _sectionHeader('Language'),
          const SizedBox(height: 8),
          _card(
            child: Column(
              children: AppSettings.supportedLanguages.entries.map((entry) {
                final isSelected = _settings.languageCode == entry.key;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: Text(
                        entry.value,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.normal,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_rounded,
                              color: Color(0xFFFFC72C))
                          : null,
                      onTap: () async {
                        await _settings.setLanguage(entry.key);
                        setState(() {});
                      },
                    ),
                    if (entry.key !=
                        AppSettings.supportedLanguages.keys.last)
                      const Divider(height: 1),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: Colors.grey,
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Card(
      margin: EdgeInsets.zero,
      child: child,
    );
  }
}
