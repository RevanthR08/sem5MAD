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
      decoration: BoxDecoration(
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
              onTap: appState.goHome,
              borderRadius: BorderRadius.circular(4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppTheme.ink,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(Icons.location_city, color: AppTheme.inkInverse, size: 20),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Civic Connect',
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.ink,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Role badge (fixed for the session; sign out to change role)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    appState.isCitizen
                        ? Icons.person
                        : appState.isOfficer
                            ? Icons.shield
                            : appState.isAdmin
                                ? Icons.admin_panel_settings
                                : Icons.construction,
                    size: 14,
                    color: AppTheme.ink,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    appState.roleLabel,
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.ink),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Logout / Switch User Button
            IconButton(
              icon: Icon(Icons.logout, size: 16, color: AppTheme.textSecondary),
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
