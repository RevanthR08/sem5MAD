import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/providers/app_state.dart';
import '../../core/theme/app_theme.dart';

class CustomHeader extends StatelessWidget implements PreferredSizeWidget {
  const CustomHeader({super.key});

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: const BoxDecoration(
        color: AppTheme.bgPrimary,
        border: Border(
          bottom: BorderSide(color: AppTheme.borderSubtle, width: 1),
        ),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Brand Logo & Title
            InkWell(
              onTap: () => appState.setActiveTab(0),
              borderRadius: BorderRadius.circular(4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.location_city, color: Colors.black, size: 20),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Civic Connect',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Role Badge with Dropdown / Switcher
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    appState.isCitizen ? Icons.person : appState.isOfficer ? Icons.shield : Icons.construction,
                    size: 14,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: appState.currentRole,
                      dropdownColor: AppTheme.bgCard,
                      isDense: true,
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 16),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'CITIZEN',
                          child: Text('Citizen'),
                        ),
                        DropdownMenuItem(
                          value: 'OFFICER',
                          child: Text('Officer'),
                        ),
                        DropdownMenuItem(
                          value: 'FIELD_WORKER',
                          child: Text('Field Staff'),
                        ),
                        DropdownMenuItem(
                          value: 'ADMIN',
                          child: Text('Admin'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) appState.setRole(val);
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Logout / Switch User Button
            IconButton(
              icon: const Icon(Icons.logout, size: 16, color: AppTheme.textSecondary),
              tooltip: 'Sign Out / Change User',
              style: IconButton.styleFrom(
                padding: const EdgeInsets.all(6),
                minimumSize: const Size(32, 32),
                backgroundColor: AppTheme.bgCard,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              ),
              onPressed: () => appState.logout(),
            ),
          ],
        ),
      ),
    );
  }
}
