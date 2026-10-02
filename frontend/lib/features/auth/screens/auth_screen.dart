import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/models/models.dart';
import '../../../core/providers/app_state.dart';
import '../../../core/services/api_service.dart';
import '../../../core/theme/app_theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

/// Roles a person can register as. Admin accounts are created by the
/// corporation, not through public sign-up.
const _registerRoles = [
  (code: 'CITIZEN', label: 'Citizen', hint: 'Report & track civic issues', icon: Icons.person_outline),
  (code: 'OFFICER', label: 'Department Officer', hint: 'Triage & assign reports', icon: Icons.shield_outlined),
  (code: 'FIELD_WORKER', label: 'Field Worker', hint: 'Repair & submit photo proof', icon: Icons.construction_outlined),
];

/// Seeded demo accounts (backend/db/seed_data.py), all using the demo password.
const _demoPassword = 'CivicPass2026!';
const _demoAccounts = [
  (label: 'Citizen Demo', email: 'citizen@civicconnect.org'),
  (label: 'Officer Demo', email: 'officer.roads@gcc.gov.in'),
  (label: 'Field Staff Demo', email: 'worker.roads@gcc.gov.in'),
  (label: 'Admin Demo', email: 'admin.gcc@chennaicorporation.gov.in'),
];

class _AuthScreenState extends State<AuthScreen> {
  final ApiService _api = ApiService();
  bool _isRegister = false;
  bool _busy = false;
  bool _obscurePassword = true;

  // Sign in
  final _loginEmail = TextEditingController();
  final _loginPassword = TextEditingController();

  // Register
  String _role = 'CITIZEN';
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _departmentId;
  List<Department>? _departments;
  bool _departmentsFailed = false;

  bool get _needsDepartment => _role != 'CITIZEN';

  @override
  void dispose() {
    for (final c in [_loginEmail, _loginPassword, _name, _email, _phone, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppTheme.danger));
  }

  void _startSession(Map<String, dynamic> user) {
    Provider.of<AppState>(context, listen: false).login(
      userId: user['id'],
      name: user['full_name'],
      role: user['role'],
      departmentName: user['department_name'],
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      _toast(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signIn(String email, String password) async {
    if (email.trim().isEmpty || password.isEmpty) {
      _toast('Enter your email and password');
      return;
    }
    await _run(() async => _startSession(await _api.login(email.trim(), password)));
  }

  Future<void> _register() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    if (name.length < 2) return _toast('Enter your full name');
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) return _toast('Enter a valid email address');
    if (_password.text.length < 6) return _toast('Password must be at least 6 characters');
    if (_password.text != _confirm.text) return _toast('Passwords do not match');
    if (_needsDepartment && _departmentId == null) return _toast('Choose your department');

    await _run(() async => _startSession(await _api.register(
          fullName: name,
          email: email,
          password: _password.text,
          role: _role,
          phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
          departmentId: _needsDepartment ? _departmentId : null,
        )));
  }

  Future<void> _loadDepartments() async {
    if (_departments != null) return;
    setState(() => _departmentsFailed = false);
    try {
      final depts = await _api.getDepartments();
      if (mounted) setState(() => _departments = depts);
    } catch (_) {
      if (mounted) setState(() => _departmentsFailed = true);
    }
  }

  void _selectRole(String role) {
    setState(() {
      _role = role;
      if (role == 'CITIZEN') _departmentId = null;
    });
    if (role != 'CITIZEN') _loadDepartments();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 440),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppTheme.borderSubtle, width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: AppTheme.ink, borderRadius: BorderRadius.circular(4)),
                    child: Icon(Icons.location_city, color: AppTheme.inkInverse, size: 26),
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: Text(
                    'Civic Connect',
                    style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w800, color: AppTheme.ink, letterSpacing: -0.5),
                  ),
                ),
                Center(
                  child: Text(
                    _isRegister ? 'CREATE YOUR ACCOUNT' : 'SIGN IN TO CONTINUE',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textMuted, letterSpacing: 1.2),
                  ),
                ),
                const SizedBox(height: 22),
                _modeToggle(),
                const SizedBox(height: 22),
                ...(_isRegister ? _registerForm() : _signInForm()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeToggle() {
    Widget tab(String label, bool register) {
      final sel = _isRegister == register;
      return Expanded(
        child: InkWell(
          onTap: _busy ? null : () => setState(() => _isRegister = register),
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: sel ? AppTheme.ink : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.center,
            child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: sel ? AppTheme.inkInverse : AppTheme.textSecondary)),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppTheme.bgSecondary,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Row(children: [tab('Sign In', false), tab('Register', true)]),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textSecondary, letterSpacing: 0.5)),
      );

  Widget _field(TextEditingController c, String hint, IconData icon, {TextInputType? type, bool password = false}) {
    return TextField(
      controller: c,
      keyboardType: type,
      obscureText: password && _obscurePassword,
      enabled: !_busy,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, size: 18, color: AppTheme.textSecondary),
        suffixIcon: password
            ? IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: AppTheme.textSecondary),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              )
            : null,
      ),
    );
  }

  Widget _submitButton(String label, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: _busy ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.ink,
        foregroundColor: AppTheme.inkInverse,
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
      child: _busy
          ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.inkInverse))
          : Text(label),
    );
  }

  List<Widget> _signInForm() {
    return [
      _label('EMAIL'),
      _field(_loginEmail, 'you@example.com', Icons.alternate_email, type: TextInputType.emailAddress),
      const SizedBox(height: 16),
      _label('PASSWORD'),
      _field(_loginPassword, 'Your password', Icons.lock_outline, password: true),
      const SizedBox(height: 24),
      _submitButton('Sign In', () => _signIn(_loginEmail.text, _loginPassword.text)),
      const SizedBox(height: 12),
      Center(
        child: TextButton(
          onPressed: _busy ? null : () => setState(() => _isRegister = true),
          child: const Text('New here? Create an account', style: TextStyle(fontSize: 12)),
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(child: Divider(color: AppTheme.borderSubtle)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Text('QUICK DEMO PROFILES', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.textMuted, letterSpacing: 0.8)),
          ),
          Expanded(child: Divider(color: AppTheme.borderSubtle)),
        ],
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.center,
        children: _demoAccounts
            .map((d) => OutlinedButton(
                  onPressed: _busy ? null : () => _signIn(d.email, _demoPassword),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                  child: Text(d.label, style: const TextStyle(fontSize: 11)),
                ))
            .toList(),
      ),
    ];
  }

  List<Widget> _registerForm() {
    return [
      _label('I AM REGISTERING AS'),
      ..._registerRoles.map((r) {
        final sel = _role == r.code;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: _busy ? null : () => _selectRole(r.code),
            borderRadius: BorderRadius.circular(4),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: sel ? AppTheme.ink.withValues(alpha: 0.08) : AppTheme.bgCard,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: sel ? AppTheme.ink : AppTheme.borderSubtle, width: sel ? 1.5 : 1),
              ),
              child: Row(
                children: [
                  Icon(r.icon, size: 20, color: sel ? AppTheme.ink : AppTheme.textSecondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: sel ? AppTheme.ink : AppTheme.textSecondary)),
                        Text(r.hint, style: TextStyle(fontSize: 10, color: AppTheme.textMuted)),
                      ],
                    ),
                  ),
                  Icon(sel ? Icons.radio_button_checked : Icons.radio_button_off, size: 18, color: sel ? AppTheme.ink : AppTheme.textMuted),
                ],
              ),
            ),
          ),
        );
      }),
      const SizedBox(height: 12),
      _label('FULL NAME'),
      _field(_name, 'Your full name', Icons.person_outline),
      const SizedBox(height: 14),
      _label('EMAIL'),
      _field(_email, 'you@example.com', Icons.alternate_email, type: TextInputType.emailAddress),
      const SizedBox(height: 14),
      _label('PHONE (OPTIONAL)'),
      _field(_phone, '+91 98765 43210', Icons.phone_outlined, type: TextInputType.phone),
      if (_needsDepartment) ...[
        const SizedBox(height: 14),
        _label('DEPARTMENT'),
        _departmentPicker(),
      ],
      const SizedBox(height: 14),
      _label('PASSWORD'),
      _field(_password, 'At least 6 characters', Icons.lock_outline, password: true),
      const SizedBox(height: 14),
      _label('CONFIRM PASSWORD'),
      _field(_confirm, 'Re-enter password', Icons.lock_outline, password: true),
      const SizedBox(height: 24),
      _submitButton('Create Account', _register),
      const SizedBox(height: 12),
      Text(
        'Admin accounts are issued by the corporation and cannot be self-registered.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
      ),
      Center(
        child: TextButton(
          onPressed: _busy ? null : () => setState(() => _isRegister = false),
          child: const Text('Already have an account? Sign in', style: TextStyle(fontSize: 12)),
        ),
      ),
    ];
  }

  Widget _departmentPicker() {
    if (_departmentsFailed) {
      return OutlinedButton.icon(
        onPressed: () {
          _departments = null;
          _loadDepartments();
        },
        icon: const Icon(Icons.refresh, size: 14),
        label: const Text('Could not load departments — retry', style: TextStyle(fontSize: 11)),
      );
    }
    if (_departments == null) {
      return LinearProgressIndicator(color: AppTheme.ink, backgroundColor: AppTheme.bgSecondary);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _departmentId,
          hint: Text('Select your department', style: TextStyle(fontSize: 13, color: AppTheme.textMuted)),
          dropdownColor: AppTheme.bgCard,
          isExpanded: true,
          style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.ink),
          items: _departments!
              .map((d) => DropdownMenuItem(value: d.id, child: Text(d.name, overflow: TextOverflow.ellipsis)))
              .toList(),
          onChanged: _busy ? null : (v) => setState(() => _departmentId = v),
        ),
      ),
    );
  }
}
