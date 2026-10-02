import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_state.dart';
import '../../../core/providers/theme_controller.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';

/// Profile for every role: account details, role-specific activity,
/// edit name/phone, change password, theme and sign out.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _api = ApiService();
  Map<String, dynamic>? _user;
  Map<String, dynamic> _stats = {};
  String? _memberSince;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.getProfile();
      if (!mounted) return;
      setState(() {
        _user = data['user'];
        _stats = Map<String, dynamic>.from(data['stats'] ?? {});
        _memberSince = data['member_since'];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? AppTheme.danger : AppTheme.success),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    if (_loading) {
      return Center(child: CircularProgressIndicator(color: AppTheme.ink));
    }
    if (_error != null || _user == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 36, color: AppTheme.danger),
            const SizedBox(height: 8),
            Text(_error ?? 'Could not load profile', style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final user = _user!;
    final name = user['full_name'] as String? ?? appState.userName;
    final initials = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join();

    return RefreshIndicator(
      onRefresh: _load,
      color: AppTheme.ink,
      backgroundColor: AppTheme.bgCard,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Identity card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: _card,
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AppTheme.ink,
                    child: Text(initials, style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.inkInverse)),
                  ),
                  const SizedBox(height: 12),
                  Text(name, textAlign: TextAlign.center, style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.ink)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.bgSecondary,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: Text(_roleTitle(appState.currentRole), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.ink)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            _sectionTitle('ACCOUNT'),
            Container(
              decoration: _card,
              child: Column(
                children: [
                  _infoRow(Icons.alternate_email, 'Email', user['email'] ?? '—'),
                  _divider(),
                  _infoRow(Icons.phone_outlined, 'Phone', user['phone'] ?? 'Not added'),
                  if (user['department_name'] != null) ...[
                    _divider(),
                    _infoRow(Icons.apartment_outlined, 'Department', user['department_name']),
                  ],
                  if (_memberSince != null) ...[
                    _divider(),
                    _infoRow(Icons.calendar_today_outlined, 'Member since', _formatDate(_memberSince!)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            _sectionTitle('MY ACTIVITY'),
            _statsRow(appState),
            const SizedBox(height: 16),

            _sectionTitle('APPEARANCE'),
            _themePicker(),
            const SizedBox(height: 16),

            _sectionTitle('SETTINGS'),
            Container(
              decoration: _card,
              child: Column(
                children: [
                  _actionRow(Icons.edit_outlined, 'Edit profile', () => _editProfile(user)),
                  _divider(),
                  _actionRow(Icons.lock_outline, 'Change password', _changePassword),
                ],
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: appState.logout,
              icon: Icon(Icons.logout, size: 16, color: AppTheme.danger),
              label: Text('Sign Out', style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: AppTheme.danger.withValues(alpha: 0.6)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _roleTitle(String role) => const {
        'CITIZEN': 'Citizen',
        'OFFICER': 'Department Officer',
        'FIELD_WORKER': 'Field Worker',
        'ADMIN': 'Administrator',
      }[role]!;

  String _formatDate(String iso) {
    final d = DateTime.tryParse(iso);
    return d == null ? iso : DateFormat('d MMM yyyy').format(d.toLocal());
  }

  BoxDecoration get _card => BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.borderSubtle),
      );

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(t, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.textMuted, letterSpacing: 0.8)),
      );

  Widget _divider() => Divider(height: 1, color: AppTheme.borderSubtle);

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(value,
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.ink),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _actionRow(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppTheme.ink),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.ink))),
            Icon(Icons.chevron_right, size: 18, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  /// Numbers that matter for each role.
  Widget _statsRow(AppState appState) {
    int n(String k) => (_stats[k] as num?)?.toInt() ?? 0;
    final items = switch (appState.currentRole) {
      'CITIZEN' => [('Reports filed', n('reports_filed')), ('Resolved', n('reports_resolved'))],
      'FIELD_WORKER' => [('Active jobs', n('active_jobs')), ('Completed', n('completed_jobs'))],
      _ => [('Actions taken', n('timeline_actions'))],
    };
    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: _card,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(items[i].$1.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.textMuted)),
                  const SizedBox(height: 4),
                  Text('${items[i].$2}', style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.ink)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _themePicker() {
    final controller = Provider.of<ThemeController>(context);
    Widget option(ThemeMode mode, IconData icon, String label) {
      final sel = controller.mode == mode;
      return Expanded(
        child: InkWell(
          onTap: () => controller.setMode(mode),
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: sel ? AppTheme.ink : AppTheme.bgCard,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: sel ? AppTheme.ink : AppTheme.borderSubtle),
            ),
            child: Column(
              children: [
                Icon(icon, size: 18, color: sel ? AppTheme.inkInverse : AppTheme.textSecondary),
                const SizedBox(height: 4),
                Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: sel ? AppTheme.inkInverse : AppTheme.textSecondary)),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        option(ThemeMode.system, Icons.brightness_auto_outlined, 'System'),
        const SizedBox(width: 8),
        option(ThemeMode.light, Icons.light_mode_outlined, 'Light'),
        const SizedBox(width: 8),
        option(ThemeMode.dark, Icons.dark_mode_outlined, 'Dark'),
      ],
    );
  }

  Future<void> _editProfile(Map<String, dynamic> user) async {
    final nameCtrl = TextEditingController(text: user['full_name'] ?? '');
    final phoneCtrl = TextEditingController(text: user['phone'] ?? '');
    final saved = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => _FormDialog(
        title: 'Edit profile',
        fields: [
          TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Full name')),
          const SizedBox(height: 12),
          TextField(controller: phoneCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone (optional)')),
        ],
        onSubmit: () => _api.updateProfile(
          fullName: nameCtrl.text.trim(),
          phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
        ),
      ),
    );
    if (saved == null || !mounted) return;
    Provider.of<AppState>(context, listen: false).updateName(saved['full_name']);
    setState(() => _user = saved);
    _toast('Profile updated');
  }

  Future<void> _changePassword() async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final done = await showDialog<Object>(
      context: context,
      builder: (ctx) => _FormDialog(
        title: 'Change password',
        fields: [
          TextField(controller: currentCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Current password')),
          const SizedBox(height: 12),
          TextField(controller: newCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'New password (min 6)')),
          const SizedBox(height: 12),
          TextField(controller: confirmCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm new password')),
        ],
        onSubmit: () async {
          if (newCtrl.text != confirmCtrl.text) throw Exception('New passwords do not match');
          await _api.changePassword(currentCtrl.text, newCtrl.text);
          return true;
        },
      ),
    );
    if (done != null) _toast('Password changed');
  }
}

/// Dialog with form fields; shows the API error inline and closes with the result on success.
class _FormDialog<T> extends StatefulWidget {
  final String title;
  final List<Widget> fields;
  final Future<T> Function() onSubmit;

  const _FormDialog({required this.title, required this.fields, required this.onSubmit});

  @override
  State<_FormDialog<T>> createState() => _FormDialogState<T>();
}

class _FormDialogState<T> extends State<_FormDialog<T>> {
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.onSubmit();
      if (mounted) Navigator.pop(context, result);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      title: Text(widget.title, style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16)),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...widget.fields,
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(fontSize: 12, color: AppTheme.danger)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.inkInverse))
              : const Text('Save'),
        ),
      ],
    );
  }
}
