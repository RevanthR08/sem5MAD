import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/app_state.dart';
import '../../../core/theme/app_theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _nameController = TextEditingController(text: 'Revanth Citizen');
  final TextEditingController _passwordController = TextEditingController(text: 'CivicPass2026!');
  String _selectedRole = 'CITIZEN';
  bool _obscurePassword = true;

  void _submitLogin() {
    final name = _nameController.text.trim();
    final pwd = _passwordController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name'), backgroundColor: AppTheme.danger),
      );
      return;
    }

    final appState = Provider.of<AppState>(context, listen: false);
    appState.login(name: name, role: _selectedRole, password: pwd);
  }

  void _fillPreset(String name, String role) {
    setState(() {
      _nameController.text = name;
      _selectedRole = role;
    });
    final appState = Provider.of<AppState>(context, listen: false);
    appState.login(name: name, role: role);
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
              borderRadius: BorderRadius.circular(4), // Almost square
              border: Border.all(color: AppTheme.borderSubtle, width: 1),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Brand Header
                Center(
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.location_city, color: Colors.black, size: 26),
                  ),
                ),
                const SizedBox(height: 14),
                Center(
                  child: Text(
                    'Civic Connect',
                    style: GoogleFonts.outfit(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    'SIGN IN & ROLE-BASED ACCESS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textMuted,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 28),

                // Name Input
                const Text('FULL NAME / USERNAME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textSecondary, letterSpacing: 0.5)),
                const SizedBox(height: 6),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    hintText: 'Enter your name',
                    prefixIcon: Icon(Icons.person_outline, size: 18, color: AppTheme.textSecondary),
                  ),
                ),
                const SizedBox(height: 16),

                // Password Input
                const Text('PASSWORD', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textSecondary, letterSpacing: 0.5)),
                const SizedBox(height: 6),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: 'Enter your password',
                    prefixIcon: const Icon(Icons.lock_outline, size: 18, color: AppTheme.textSecondary),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 18, color: AppTheme.textSecondary),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Role Dropdown
                const Text('ROLE / ACCESS LEVEL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textSecondary, letterSpacing: 0.5)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedRole,
                      dropdownColor: AppTheme.bgCard,
                      isExpanded: true,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'CITIZEN',
                          child: Text('Citizen (Public Reporting & Verification)'),
                        ),
                        DropdownMenuItem(
                          value: 'OFFICER',
                          child: Text('Department Officer (GCC Authority Console)'),
                        ),
                        DropdownMenuItem(
                          value: 'FIELD_WORKER',
                          child: Text('Field Worker (Repairs & Photo Proof)'),
                        ),
                        DropdownMenuItem(
                          value: 'ADMIN',
                          child: Text('Super Admin / City Commissioner'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedRole = val);
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Submit Button
                ElevatedButton(
                  onPressed: _submitLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Enter Platform'),
                ),

                const SizedBox(height: 24),

                // One-click demo roles
                Row(
                  children: [
                    const Expanded(child: Divider(color: AppTheme.borderSubtle)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text('QUICK DEMO PROFILES', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.textMuted, letterSpacing: 0.8)),
                    ),
                    const Expanded(child: Divider(color: AppTheme.borderSubtle)),
                  ],
                ),
                const SizedBox(height: 12),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: () => _fillPreset('Revanth Citizen', 'CITIZEN'),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                      child: const Text('Citizen Demo', style: TextStyle(fontSize: 11)),
                    ),
                    OutlinedButton(
                      onPressed: () => _fillPreset('Er. Rajesh V (Roads)', 'OFFICER'),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                      child: const Text('Officer Demo', style: TextStyle(fontSize: 11)),
                    ),
                    OutlinedButton(
                      onPressed: () => _fillPreset('Murugan S (Team 4)', 'FIELD_WORKER'),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
                      child: const Text('Field Staff Demo', style: TextStyle(fontSize: 11)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
