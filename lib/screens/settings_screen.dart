import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../app_settings.dart';
import '../services/notification_service.dart';
import '../services/iap_service.dart';
import '../services/ad_service.dart';
import 'premium_upgrade_screen.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';

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
        title: Text('settings'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── APPEARANCE SECTION ──
          _sectionHeader('appearance'.tr()),
          const SizedBox(height: 8),
          _card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.grid_view_rounded),
                  title: Text('exercise_grid_view'.tr()),
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
                  title: Text('light_mode'.tr()),
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
                  title: Text('dark_mode'.tr()),
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
          _sectionHeader('notifications'.tr()),
          const SizedBox(height: 8),
          _card(
            child: SwitchListTile(
              secondary: const Icon(Icons.notifications_rounded),
              title: Text('daily_reminders'.tr()),
              subtitle: Text('daily_reminders_sub'.tr()),
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
          _sectionHeader('language_section'.tr()),
          const SizedBox(height: 8),
          _card(
            child: Column(
              children: AppSettings.supportedLanguages.entries.map((entry) {
                final isSelected = context.locale.languageCode == entry.key;
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
                        await context.setLocale(Locale(entry.key));
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

          const SizedBox(height: 24),

          // ── PREMIUM SECTION ──
          _sectionHeader('premium_section'.tr()),
          const SizedBox(height: 8),
          _buildPremiumSection(),

          const SizedBox(height: 24),
          _card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.privacy_tip_rounded, color: Colors.blue),
                  title: Text('privacy_policy'.tr()),
                  trailing: const Icon(Icons.open_in_new_rounded, size: 16, color: Colors.grey),
                  onTap: () async {
                    final Uri url = Uri.parse('https://sites.google.com/view/potato60secondroutine/privacy-policy?authuser=0'); // TODO: Replace with the actual URL
                    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Could not launch privacy policy URL.')),
                        );
                      }
                    }
                  },
                ),
                if (AdService.instance.isPrivacyOptionsRequired) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.cookie_rounded, color: Colors.orange),
                    title: const Text('Manage Privacy Options'),
                    trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
                    onTap: () {
                      AdService.instance.showPrivacyOptionsForm();
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPremiumSection() {
    return ListenableBuilder(
      listenable: IapService.instance,
      builder: (context, _) {
        final iap = IapService.instance;

        // Check firestore for premium status
        return StreamBuilder(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(FirebaseAuth.instance.currentUser?.uid)
              .snapshots(),
          builder: (context, snapshot) {
            final isPremium = snapshot.data?.data()?['isPremium'] == true;

            if (isPremium) {
              return _card(
                child: ListTile(
                  leading: const Icon(Icons.star_rounded, color: Color(0xFFFFC72C)),
                  title: Text('premium_member'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('ads_removed_sub'.tr()),
                ),
              );
            }

            return _card(
              child: ListTile(
                leading: const Icon(Icons.block_rounded, color: Colors.red),
                title: Text('remove_ads_upgrade'.tr()),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PremiumUpgradeScreen()),
                  );
                },
              ),
            );
          },
        );
      },
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
