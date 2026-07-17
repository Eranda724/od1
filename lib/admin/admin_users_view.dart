import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../app_settings.dart';
import 'admin_service.dart';
import 'package:easy_localization/easy_localization.dart';

class AdminUsersView extends StatefulWidget {
  const AdminUsersView({super.key});

  @override
  State<AdminUsersView> createState() => _AdminUsersViewState();
}

class _AdminUsersViewState extends State<AdminUsersView> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSuperAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkRole();
  }

  Future<void> _checkRole() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final role = await getAdminRole(uid);
      if (mounted) setState(() => _isSuperAdmin = role == 'super');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'search_by_email_username'.tr(),
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Theme.of(context).inputDecorationTheme.fillColor,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
          ),
        ),
        
        // Users list
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('error_loading'.tr(args: [snapshot.error.toString()])));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final allUsers = snapshot.data!.docs;
              
              // Filter users locally
              final filteredUsers = allUsers.where((doc) {
                if (_searchQuery.isEmpty) return true;
                final data = doc.data() as Map<String, dynamic>;
                final displayName = (data['displayName'] ?? data['username'] ?? '').toString().toLowerCase();
                final email = (data['email'] ?? '').toString().toLowerCase();
                return displayName.contains(_searchQuery) || email.contains(_searchQuery);
              }).toList();

              if (filteredUsers.isEmpty) {
                return Center(child: Text('no_users_found'.tr()));
              }

              return ListView.builder(
                itemCount: filteredUsers.length,
                itemBuilder: (context, index) {
                  final doc = filteredUsers[index];
                  final data = doc.data() as Map<String, dynamic>;
                  
                  final displayName = data['displayName'] ?? data['username'] ?? 'no_name'.tr();
                  final email = data['email'] ?? 'no_email'.tr();
                  final overallStreak = data['overallStreak'] ?? 0;
                  final freezes = data['freezesAvailable'] ?? 0;
                  
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    elevation: 1,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    child: ExpansionTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.amber.shade200,
                        child: Text(
                          displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: data['isPremium'] == true ? const Color(0xFFFFC72C) : Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              data['isPremium'] == true ? 'premium_badge'.tr() : 'free_badge'.tr(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: data['isPremium'] == true ? Colors.black : Colors.black54,
                              ),
                            ),
                          ),
                          if (data['isAdmin'] == true) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue, width: 1),
                              ),
                              child: Text(
                                'admin_badge'.tr(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      subtitle: Text(email),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _StatItem(icon: Icons.local_fire_department_rounded, label: 'overall_streak'.tr(), value: '$overallStreak'),
                              _StatItem(icon: Icons.ac_unit_rounded, label: 'freezes_label'.tr(), value: '$freezes'),
                              _StatItem(icon: Icons.calendar_today_rounded, label: 'last_date_label'.tr(), value: data['overallLastDate'] ?? 'never_label'.tr()),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        if (_isSuperAdmin)
                          SwitchListTile(
                            title: Text('premium_status'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('grants_ad_free'.tr()),
                            value: data['isPremium'] == true,
                            activeThumbColor: const Color(0xFFFFC72C),
                            activeTrackColor: const Color(0xFFFFC72C).withValues(alpha: 0.4),
                            onChanged: (bool value) async {
                              await doc.reference.update({'isPremium': value});
                            },
                          ),
                        if (_isSuperAdmin && data['adminRole'] != 'super')
                          SwitchListTile(
                            title: Text('admin_access'.tr(), style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('grants_sub_admin'.tr()),
                            value: data['isAdmin'] == true,
                            activeThumbColor: const Color(0xFFFFC72C),
                            activeTrackColor: const Color(0xFFFFC72C).withValues(alpha: 0.4),
                            onChanged: (bool value) async {
                              if (value) {
                                await doc.reference.update({'isAdmin': true, 'adminRole': 'sub'});
                              } else {
                                await doc.reference.update({'isAdmin': false, 'adminRole': FieldValue.delete()});
                              }
                            },
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: PCColors.yellow, size: 28),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
