import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/exercise_item.dart';
import '../models/exercise_icons.dart';
import '../admin/admin_exercise_screen.dart';
import '../admin/admin_users_view.dart';
import 'package:easy_localization/easy_localization.dart';
import '../admin/admin_assets_screen.dart';
import '../admin/admin_celebration_assets_screen.dart';
import '../admin/admin_ui.dart';

// Firestore path that stores admin-configurable notification times.
// Document shape: { morningHour: int, morningMinute: int, eveningHour: int, eveningMinute: int }
const _kNotifDoc = 'app_config/notifications';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AdminUI.buildAppBar(
          context,
          title: 'admin_panel'.tr(),
          bottom: TabBar(
            indicatorColor: Colors.blueGrey,
            labelColor: Theme.of(context).colorScheme.onSurface,
            unselectedLabelColor: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: 0.5),
            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
            tabs: [
              Tab(text: 'exercises_tab'.tr()),
              Tab(text: 'users_tab'.tr()),
              Tab(text: 'settings'.tr()),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildExercisesTab(context),
            const AdminUsersView(),
            const _AdminSettingsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildExercisesTab(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminExerciseScreen()),
        ),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('exercises').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'error_loading'.tr(args: [snapshot.error.toString()]),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final exercises = snapshot.data!.docs
              .map(
                (doc) => ExerciseItem.fromMap(
                  doc.id,
                  doc.data() as Map<String, dynamic>,
                ),
              )
              .toList();

          if (exercises.isEmpty) {
            return Center(child: Text('no_exercises_yet'.tr()));
          }

          return ListView.builder(
            itemCount: exercises.length,
            itemBuilder: (context, index) {
              final exercise = exercises[index];
              return AdminUI.buildCard(
                context,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: Container(
                    width: 48,
                    height: 48,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: buildExerciseVisual(
                        exercise,
                        size: 26,
                        width: 48,
                        height: 48,
                      ),
                    ),
                  ),
                  title: Text(
                    exercise.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      'Reps: ${exercise.defaultReps > 0 ? exercise.defaultReps : 'any_label'.tr()}\n'
                      'Timer: ${exercise.defaultTimer > 0 ? '${exercise.defaultTimer}s' : 'any_label'.tr()}\n'
                      'Days: ${exercise.defaultDays > 0 ? exercise.defaultDays : 'any_label'.tr()}',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                  ),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blueGrey),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                AdminExerciseScreen(existing: exercise),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (c) => AlertDialog(
                              title: Text('delete_exercise_title'.tr()),
                              content: Text(
                                'delete_exercise_desc'.tr(
                                  args: [exercise.name],
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(c, false),
                                  child: Text('cancel_btn'.tr()),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(c, true),
                                  child: Text(
                                    'delete_btn'.tr(),
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await FirebaseFirestore.instance
                                .collection('exercises')
                                .doc(exercise.id)
                                .delete();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// Admin Settings Tab — notification time configuration
class _AdminSettingsTab extends StatefulWidget {
  const _AdminSettingsTab();

  @override
  State<_AdminSettingsTab> createState() => _AdminSettingsTabState();
}

class _AdminSettingsTabState extends State<_AdminSettingsTab> {
  // Default times (matches notification_service.dart hardcoded fallbacks)
  static const int _defaultMorningHour = 6;
  static const int _defaultEveningHour = 17;

  bool _isSaving = false;

  final _db = FirebaseFirestore.instance;

  DocumentReference get _notifRef {
    final parts = _kNotifDoc.split('/');
    return _db.collection(parts[0]).doc(parts[1]);
  }

  Future<void> _pickTime(
    BuildContext context,
    String label,
    int currentHour,
    int currentMinute,
    String hourField,
    String minuteField,
  ) async {
    // Capture before first async gap
    final messenger = ScaffoldMessenger.of(context);
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: currentHour, minute: currentMinute),
      helpText: 'set_time_label'.tr(args: [label]),
    );
    if (picked == null || !mounted) return;

    setState(() => _isSaving = true);
    try {
      await _notifRef.set({
        hourField: picked.hour,
        minuteField: picked.minute,
      }, SetOptions(merge: true));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('save_failed'.tr(args: [e.toString()]))),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _fmt(int hour, int minute) {
    final tod = TimeOfDay(hour: hour, minute: minute);
    final h = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final m = minute.toString().padLeft(2, '0');
    final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _notifRef.snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() as Map<String, dynamic>? ?? {};
        final morningHour =
            (data['morningHour'] as int?) ?? _defaultMorningHour;
        final morningMinute = (data['morningMinute'] as int?) ?? 0;
        final eveningHour =
            (data['eveningHour'] as int?) ?? _defaultEveningHour;
        final eveningMinute = (data['eveningMinute'] as int?) ?? 0;

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'notification_times_title'.tr(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),

            // Morning reminder
            AdminUI.buildCard(
              context,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                leading: Image.asset(
                  'assets/images/sun.png',
                  width: 32,
                  height: 32,
                ),
                title: Text(
                  'morning_reminder_label'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  _fmt(morningHour, morningMinute),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                trailing: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : TextButton(
                        onPressed: () => _pickTime(
                          context,
                          'morning_reminder_label'.tr(),
                          morningHour,
                          morningMinute,
                          'morningHour',
                          'morningMinute',
                        ),
                        child: Text('change_btn'.tr()),
                      ),
              ),
            ),
            const SizedBox(height: 12),

            // Evening streak-saver
            AdminUI.buildCard(
              context,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                leading: Image.asset(
                  'assets/images/moon.png',
                  width: 32,
                  height: 32,
                ),
                title: Text(
                  'evening_streak_saver_label'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  _fmt(eveningHour, eveningMinute),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                trailing: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : TextButton(
                        onPressed: () => _pickTime(
                          context,
                          'evening_streak_saver_label'.tr(),
                          eveningHour,
                          eveningMinute,
                          'eveningHour',
                          'eveningMinute',
                        ),
                        child: Text('change_btn'.tr()),
                      ),
              ),
            ),

            const SizedBox(height: 32),

            Text(
              'admin_streak_rules'.tr(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),

            // Freeze Recharge Period
            const _AdminFreezeSetting(),

            const SizedBox(height: 32),

            Text(
              'admin_appearance'.tr(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),

            // Session Assets Bank
            AdminUI.buildCard(
              context,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                leading: Image.asset(
                  'assets/images/session.png',
                  width: 32,
                  height: 32,
                ),
                title: Text(
                  'admin_session_assets'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  'admin_manage_dynamic_session'.tr(),
                  style: const TextStyle(fontSize: 13),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminAssetsScreen()),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Celebration Image Bank
            AdminUI.buildCard(
              context,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                leading: Image.asset(
                  'assets/images/streak.png',
                  width: 32,
                  height: 32,
                ),
                title: Text(
                  'image_bank_title'.tr(),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  'admin_manage_celebration'.tr(),
                  style: const TextStyle(fontSize: 13),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminCelebrationAssetsScreen(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        );
      },
    );
  }
}

class _AdminFreezeSetting extends StatefulWidget {
  const _AdminFreezeSetting();

  @override
  State<_AdminFreezeSetting> createState() => _AdminFreezeSettingState();
}

class _AdminFreezeSettingState extends State<_AdminFreezeSetting> {
  final _db = FirebaseFirestore.instance;
  bool _isSaving = false;

  Future<void> _pickDays(BuildContext context, int currentDays) async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController(text: currentDays.toString());

    final result = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('admin_freeze_recharge_period_days'.tr()),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'admin_freeze_recharge_period_hint'.tr(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('cancel_btn'.tr()),
          ),
          TextButton(
            onPressed: () {
              final val = int.tryParse(controller.text);
              Navigator.pop(context, val);
            },
            child: Text('save_btn'.tr()),
          ),
        ],
      ),
    );

    if (result == null || !mounted) return;

    setState(() => _isSaving = true);
    try {
      await _db.collection('app_config').doc('settings').set({
        'freezeRechargePeriodDays': result,
      }, SetOptions(merge: true));
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('save_failed'.tr(args: [e.toString()]))),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('app_config').doc('settings').snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data() as Map<String, dynamic>? ?? {};
        final period = (data['freezeRechargePeriodDays'] as int?) ?? 15;

        return AdminUI.buildCard(
          context,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 8,
            ),
            leading: Image.asset(
              'assets/images/ice_cube_3d.png',
              width: 32,
              height: 32,
            ),
            title: Text(
              'admin_freeze_recharge_period'.tr(),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '$period days',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            trailing: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : TextButton(
                    onPressed: () => _pickDays(context, period),
                    child: Text('change_btn'.tr()),
                  ),
          ),
        );
      },
    );
  }
}
