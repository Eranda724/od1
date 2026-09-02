import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_settings.dart';
import '../services/notification_service.dart';
import '../services/iap_service.dart';
import '../services/ad_service.dart';
import 'premium_upgrade_screen.dart';
import '../services/account_deletion_service.dart';
import 'onboarding_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = AppSettings();

  static const Color _yellow = Color(0xFFFFC72C);
  static const Color _yellowDark = Color(0xFFE3A900);

  bool _isLoadingDelete = false;
  final _deletePasswordController = TextEditingController();
  bool _obscureDeletePassword = true;
  bool _isDangerZoneExpanded = false;
  bool _isSuperAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkSuperAdmin();
  }

  @override
  void dispose() {
    _deletePasswordController.dispose();
    super.dispose();
  }

  Future<void> _checkSuperAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted || !doc.exists) return;

      setState(() {
        _isSuperAdmin = doc.data()?['adminRole'] == 'super';
      });
    } catch (_) {}
  }

  // BUILD

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,

      // APP BAR
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        backgroundColor: theme.scaffoldBackgroundColor,

        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
          onPressed: () => Navigator.pop(context),
        ),

        title: Text(
          'settings'.tr(),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
          ),
        ),
      ),

      // BODY
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            // APPEARANCE
            _sectionTitle('appearance'.tr(), Icons.palette_outlined),

            const SizedBox(height: 12),

            _settingsCard(
              child: Column(
                children: [
                  // EXERCISE GRID
                  _settingRow(
                    icon: Icons.grid_view_rounded,
                    iconBackground: _yellow.withValues(alpha: 0.14),
                    iconColor: _yellowDark,
                    title: 'exercise_grid_view'.tr(),
                    subtitle: 'exercise_grid_subtitle'.tr(),
                    trailing: Switch(
                      value: _settings.isGridView,
                      activeColor: _yellow,
                      onChanged: (value) async {
                        await _settings.setGridView(value);

                        if (mounted) {
                          setState(() {});
                        }
                      },
                    ),
                  ),

                  _divider(),

                  // THEME
                  Padding(
                    padding: const EdgeInsets.fromLTRB(13, 10, 13, 11),
                    child: Row(
                      children: [
                        _iconBox(
                          icon: Icons.brightness_6_rounded,
                          color: Colors.blueGrey,
                        ),

                        const SizedBox(width: 11),

                        Expanded(
                          child: Text(
                            'theme'.tr(),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(13, 0, 13, 12),
                    child: _themeSelector(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // NOTIFICATIONS
            _sectionTitle(
              'notifications'.tr(),
              Icons.notifications_none_rounded,
            ),

            const SizedBox(height: 7),

            _settingsCard(
              child: _settingRow(
                icon: Icons.notifications_active_outlined,
                iconBackground: _yellow.withValues(alpha: 0.14),
                iconColor: _yellowDark,
                title: 'daily_reminders'.tr(),
                subtitle: 'daily_reminders_sub'.tr(),
                trailing: Switch(
                  value: _settings.notificationsEnabled,
                  activeColor: _yellow,
                  onChanged: (value) async {
                    await _settings.setNotificationsEnabled(value);

                    if (value) {
                      await NotificationService.instance.refreshSchedule();
                    } else {
                      await NotificationService.instance.cancelAll();
                    }

                    if (mounted) {
                      setState(() {});
                    }
                  },
                ),
              ),
            ),

            const SizedBox(height: 12),

            // LANGUAGE
            _sectionTitle('language_section'.tr(), Icons.language_rounded),

            const SizedBox(height: 7),

            _settingsCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    _iconBox(
                      icon: Icons.translate_rounded,
                      color: Colors.indigo,
                    ),

                    const SizedBox(width: 11),

                    Expanded(
                      child: Text(
                        'language_section'.tr(),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : const Color(0xFFF4F2EC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _currentLanguageKey(),
                          isDense: true,
                          borderRadius: BorderRadius.circular(14),
                          icon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 19,
                          ),
                          items: AppSettings.supportedLanguages.entries
                              .map(
                                (entry) => DropdownMenuItem<String>(
                                  value: entry.key,
                                  child: Text(
                                    entry.value,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (value) async {
                            if (value == null) return;

                            await context.setLocale(Locale(value));

                            if (mounted) {
                              setState(() {});
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // PREMIUM
            _sectionTitle('premium_section'.tr(), Icons.star_outline_rounded),

            const SizedBox(height: 7),

            _buildPremiumSection(),

            const SizedBox(height: 12),

            // PRIVACY
            _sectionTitle('privacy_and_data'.tr(), Icons.security_rounded),

            const SizedBox(height: 7),

            _settingsCard(
              child: Column(
                children: [
                  _actionRow(
                    icon: Icons.privacy_tip_outlined,
                    iconColor: Colors.blue,
                    title: 'privacy_policy'.tr(),
                    trailing: Icons.open_in_new_rounded,
                    onTap: _openPrivacyPolicy,
                  ),

                  if (AdService.instance.isPrivacyOptionsRequired) ...[
                    _divider(),

                    _actionRow(
                      icon: Icons.cookie_outlined,
                      iconColor: Colors.orange,
                      title: 'manage_privacy_options'.tr(),
                      trailing: Icons.arrow_forward_ios_rounded,
                      onTap: () {
                        AdService.instance.showPrivacyOptionsForm();
                      },
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 12),

            if (!_isSuperAdmin) ...[
              _buildDeleteAccountSection(isDark: isDark),
              const SizedBox(height: 4),
            ],
          ],
        ),
      ),
    );
  }

  // SECTION TITLE

  Widget _sectionTitle(String title, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Row(
      children: [
        Icon(icon, size: 16, color: isDark ? _yellowDark : Colors.black),

        const SizedBox(width: 6),

        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  // CARD

  Widget _settingsCard({required Widget child}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: isDark
          ? Colors.white.withValues(alpha: 0.035)
          : Colors.white.withValues(alpha: 0.72),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.055),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  // SETTING ROW

  Widget _settingRow({
    required IconData icon,
    required Color iconBackground,
    required Color iconColor,
    required String title,
    String? subtitle,
    required Widget trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 15),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 22, color: iconColor),
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.43),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 6),

          trailing,
        ],
      ),
    );
  }

  // ICON BOX

  Widget _iconBox({required IconData icon, required Color color}) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 22, color: color),
    );
  }

  // DIVIDER

  Widget _divider() {
    return Divider(
      height: 1,
      thickness: 0.7,
      indent: 59,
      endIndent: 13,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.06),
    );
  }

  // ACTION ROW

  Widget _actionRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required IconData trailing,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 15),
        child: Row(
          children: [
            _iconBox(icon: icon, color: iconColor),

            const SizedBox(width: 11),

            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),

            Icon(trailing, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // THEME SELECTOR

  Widget _themeSelector() {
    final currentTheme = _settings.themeMode;

    return Container(
      height: 43,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Expanded(
            child: _themeButton(
              icon: Icons.light_mode_rounded,
              title: 'light_mode'.tr(),
              selected: currentTheme == ThemeMode.light,
              onTap: () async {
                await _settings.setThemeMode(ThemeMode.light);

                if (mounted) {
                  setState(() {});
                }
              },
            ),
          ),

          Expanded(
            child: _themeButton(
              icon: Icons.dark_mode_rounded,
              title: 'dark_mode'.tr(),
              selected: currentTheme == ThemeMode.dark,
              onTap: () async {
                await _settings.setThemeMode(ThemeMode.dark);

                if (mounted) {
                  setState(() {});
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  // THEME BUTTON

  Widget _themeButton({
    required IconData icon,
    required String title,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: double.infinity,
        decoration: BoxDecoration(
          color: selected ? _yellow : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: selected ? Colors.black : Colors.grey),

            const SizedBox(width: 6),

            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                color: selected ? Colors.black : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // LANGUAGE KEY

  String _currentLanguageKey() {
    final currentCode = context.locale.languageCode;

    if (AppSettings.supportedLanguages.containsKey(currentCode)) {
      return currentCode;
    }

    return AppSettings.supportedLanguages.keys.first;
  }

  // PREMIUM SECTION

  Widget _buildPremiumSection() {
    return ListenableBuilder(
      listenable: IapService.instance,
      builder: (context, _) {
        final user = FirebaseAuth.instance.currentUser;

        if (user == null) {
          return _premiumUpgradeCard();
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .snapshots(),
          builder: (context, snapshot) {
            final data = snapshot.data?.data();

            final isPremium = data?['isPremium'] == true;

            if (isPremium) {
              return _premiumMemberCard();
            }

            return _premiumUpgradeCard();
          },
        );
      },
    );
  }

  // PREMIUM MEMBER

  Widget _premiumMemberCard() {
    return _settingsCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 39,
              height: 39,
              decoration: BoxDecoration(
                color: _yellow.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.star_rounded,
                color: _yellowDark,
                size: 21,
              ),
            ),

            const SizedBox(width: 11),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'premium_member'.tr(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),

                  const SizedBox(height: 2),

                  Text(
                    'ads_removed_sub'.tr(),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.48),
                    ),
                  ),
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _yellow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'PRO',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // PREMIUM UPGRADE

  Widget _premiumUpgradeCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFD84A), Color(0xFFFFC72C)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _yellow.withValues(alpha: 0.20),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PremiumUpgradeScreen()),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Colors.black,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.star_rounded, color: _yellow, size: 22),
              ),

              const SizedBox(width: 11),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'remove_ads_upgrade'.tr(),
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: 2),

                    Text(
                      'go_premium_sub'.tr(),
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.58),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: Colors.black,
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  // PRIVACY POLICY

  Future<void> _openPrivacyPolicy() async {
    final uri = Uri.parse(
      'https://sites.google.com/view/potato60secondroutine/privacy-policy?authuser=0',
    );

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('privacy_error'.tr())),
      );
    }
  }

  // DELETE ACCOUNT
  
  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          icon: const Icon(
            Icons.warning_amber_rounded,
            color: Colors.red,
            size: 40,
          ),
          title: Text(
            'delete_account_title'.tr(),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Text('delete_account_confirm_msg'.tr()),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx, false);
              },
              child: Text('cancel'.tr()),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx, true);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text('yes_delete_my_account'.tr()),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    String? password;

    if (AccountDeletionService.isEmailPasswordUser) {
      _deletePasswordController.clear();

      password = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setDialogState) {
              return AlertDialog(
                title: Text('confirm_your_password'.tr()),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'enter_password_confirm_delete'.tr(),
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _deletePasswordController,
                      obscureText: _obscureDeletePassword,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'password_label'.tr(),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscureDeletePassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setDialogState(() {
                              _obscureDeletePassword = !_obscureDeletePassword;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx, null);
                    },
                    child: Text('cancel'.tr()),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx, _deletePasswordController.text);
                    },
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: Text('delete_forever'.tr()),
                  ),
                ],
              );
            },
          );
        },
      );

      if (password == null || password.isEmpty || !mounted) {
        return;
      }
    }

    setState(() {
      _isLoadingDelete = true;
    });

    try {
      await AccountDeletionService.deleteAccount(password: password);

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'invalid-credential':
        case 'wrong-password':
          message = 'err_wrong_password'.tr();
          break;

        case 'requires-recent-login':
          message = 'err_requires_recent_login'.tr();
          break;

        case 'network-request-failed':
          message = 'err_network'.tr();
          break;

        default:
          message = 'failed_delete_account'.tr();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('error_msg'.tr(args: [e.toString()])),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingDelete = false;
        });
      }
    }
  }

  Widget _buildDeleteAccountSection({required bool isDark}) {
    return _settingsCard(
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          splashColor: Colors.red.withValues(alpha: 0.05),
          highlightColor: Colors.red.withValues(alpha: 0.03),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 3),
          childrenPadding: const EdgeInsets.fromLTRB(13, 0, 13, 13),

          // Closed initially.
          initiallyExpanded: false,
          onExpansionChanged: (expanded) {
            setState(() {
              _isDangerZoneExpanded = expanded;
            });
          },

          leading: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _isDangerZoneExpanded
                  ? Colors.red.withValues(alpha: 0.10)
                  : Colors.grey.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.delete_outline_rounded,
              color: _isDangerZoneExpanded ? Colors.red : Colors.grey,
              size: 22,
            ),
          ),

          title: Text(
            _isDangerZoneExpanded ? 'danger_zone'.tr() : 'delete_account_title'.tr(),
            style: TextStyle(
              color: _isDangerZoneExpanded
                  ? Colors.red
                  : (isDark ? Colors.white : Colors.black),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),

          children: [
            Text(
              'delete_account_confirm_msg'.tr(),
              style: TextStyle(
                fontSize: 11,
                height: 1.35,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.55),
              ),
            ),

            const SizedBox(height: 9),

            SizedBox(
              height: 42,
              width: double.infinity,
              child: _isLoadingDelete
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Colors.red,
                        strokeWidth: 2.5,
                      ),
                    )
                  : OutlinedButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text('delete_account_dialog_title'.tr()),
                            content: Text('delete_account_dialog_desc'.tr()),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: Text('no'.tr()),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _deleteAccount();
                                },
                                child: Text('yes'.tr(),
                                    style: const TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.delete_forever_rounded,
                        size: 19,
                      ),
                      label: Text(
                        'delete_account_btn'.tr().toUpperCase(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: BorderSide(
                          color: Colors.red.withValues(alpha: 0.55),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
