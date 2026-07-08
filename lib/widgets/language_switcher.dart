import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../app_settings.dart';

class LanguageSwitcher extends StatelessWidget {
  const LanguageSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<Locale>(
      icon: const Icon(Icons.language),
      tooltip: 'change_language'.tr(),
      onSelected: (Locale newLocale) {
        context.setLocale(newLocale);
      },
      itemBuilder: (BuildContext context) {
        return AppSettings.supportedLanguages.entries.map((entry) {
          final isSelected = context.locale.languageCode == entry.key;
          return PopupMenuItem<Locale>(
            value: Locale(entry.key),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(entry.value, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                if (isSelected) const Icon(Icons.check, size: 18),
              ],
            ),
          );
        }).toList();
      },
    );
  }
}
