import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';
import '../../../core/providers/app_state.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/status_badge.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _api = ApiService();
  List<CivicReport> _reports = [];
  AnalyticsOverview? _analytics;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final reports = await _api.getReports();
      final analytics = await _api.getAnalyticsOverview();
      setState(() {
        _reports = reports;
        _analytics = analytics;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _handleUpvote(String reportId) async {
    try {
      final newCount = await _api.upvoteReport(reportId);
      setState(() {
        _reports = _reports.map((r) {
          if (r.id == reportId) {
            return CivicReport(
              id: r.id,
              publicId: r.publicId,
              title: r.title,
              description: r.description,
              status: r.status,
              priority: r.priority,
              severity: r.severity,
              latitude: r.latitude,
              longitude: r.longitude,
              address: r.address,
              landmark: r.landmark,
              categoryId: r.categoryId,
              categoryName: r.categoryName,
              categoryIcon: r.categoryIcon,
              subcategoryName: r.subcategoryName,
              departmentName: r.departmentName,
              wardName: r.wardName,
              wardNumber: r.wardNumber,
              assignedTeam: r.assignedTeam,
              assignedOfficerName: r.assignedOfficerName,
              slaHours: r.slaHours,
              slaInfo: r.slaInfo,
              upvotes: newCount,
              thumbnailUrl: r.thumbnailUrl,
              resolutionBeforePhoto: r.resolutionBeforePhoto,
              resolutionAfterPhoto: r.resolutionAfterPhoto,
              resolutionNotes: r.resolutionNotes,
              citizenVerified: r.citizenVerified,
              citizenFeedback: r.citizenFeedback,
              createdAt: r.createdAt,
            );
          }
          return r;
        }).toList();
      });
    } catch (e) {
      // Ignore
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);

    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: Colors.white,
      backgroundColor: AppTheme.bgCard,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Action Banner (Square corners, High-contrast black & white)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.rectangle),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'WARD 123 • MYLAPORE & ANNA SALAI, GCC',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textSecondary,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Spotted an issue on your street?',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Report civic problems directly to GCC municipal engineers and verify repairs with photo proof.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    onPressed: () => appState.startReportWithCategory(null),
                    icon: const Icon(Icons.camera_alt_outlined, size: 16),
                    label: const Text('Report an Issue'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Quick Category Section
            Text(
              'QUICK CATEGORIES',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.textMuted, letterSpacing: 0.8),
            ),
            const SizedBox(height: 8),

            // Responsive Quick Category Grid (Adaptive layout, no overflow!)
            LayoutBuilder(
              builder: (context, constraints) {
                int cols = constraints.maxWidth < 600 ? 3 : 6;
                return GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: cols,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: constraints.maxWidth < 600 ? 1.6 : 2.0,
                  children: [
                    _buildQuickCat(
                      icon: Icons.construction,
                      label: 'Roads',
                      onTap: () => appState.startReportWithCategory('e0000000-0000-0000-0000-000000000001'),
                    ),
                    _buildQuickCat(
                      icon: Icons.delete_outline,
                      label: 'Waste',
                      onTap: () => appState.startReportWithCategory('e0000000-0000-0000-0000-000000000002'),
                    ),
                    _buildQuickCat(
                      icon: Icons.lightbulb_outline,
                      label: 'Lighting',
                      onTap: () => appState.startReportWithCategory('e0000000-0000-0000-0000-000000000003'),
                    ),
                    _buildQuickCat(
                      icon: Icons.water_drop_outlined,
                      label: 'Drainage',
                      onTap: () => appState.startReportWithCategory('e0000000-0000-0000-0000-000000000004'),
                    ),
                    _buildQuickCat(
                      icon: Icons.waves,
                      label: 'Water',
                      onTap: () => appState.startReportWithCategory('e0000000-0000-0000-0000-000000000005'),
                    ),
                    _buildQuickCat(
                      icon: Icons.warning_amber_rounded,
                      label: 'Hazards',
                      onTap: () => appState.startReportWithCategory('e0000000-0000-0000-0000-000000000006'),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 20),

            // Ward Statistics Banner
            if (_analytics != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatCol('ACTIVE', '${_analytics!.openReports + _analytics!.inProgress}'),
                    _buildStatCol('RESOLVED', '${_analytics!.resolvedReports}'),
                    _buildStatCol('SLA RATE', '${_analytics!.slaCompliancePct.toInt()}%'),
                    _buildStatCol('VERIFIED', '100%'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Nearby Civic Issues Feed
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'NEARBY CIVIC REPORTS',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.textMuted, letterSpacing: 0.8),
                ),
                Text(
                  '${_reports.length} ACTIVE',
                  style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Reports List
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _reports.length,
              separatorBuilder: (c, i) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final report = _reports[index];
                return _buildReportCard(context, report, appState);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickCat({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppTheme.borderSubtle),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCol(String title, String val) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: AppTheme.textMuted, letterSpacing: 0.5),
        ),
        const SizedBox(height: 2),
        Text(
          val,
          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
        ),
      ],
    );
  }

  Widget _buildReportCard(BuildContext context, CivicReport report, AppState appState) {
    return InkWell(
      onTap: () => appState.openReportDetail(report.publicId),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppTheme.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  report.publicId,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                StatusBadge(status: report.status),
              ],
            ),
            const SizedBox(height: 6),

            Text(
              report.title,
              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            const SizedBox(height: 2),
            Text(
              report.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 8),

            // Photo Preview if available
            if (report.thumbnailUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: CachedNetworkImage(
                  imageUrl: report.thumbnailUrl!,
                  height: 120,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (c, u) => Container(color: AppTheme.bgSecondary, height: 120),
                  errorWidget: (c, u, e) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Address
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 12, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    report.address ?? '${report.latitude.toStringAsFixed(4)}, ${report.longitude.toStringAsFixed(4)}',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // SLA & Upvote Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  report.slaInfo?.label ?? '${report.slaHours}h SLA',
                  style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                ),
                InkWell(
                  onTap: () => _handleUpvote(report.id),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.bgSecondary,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: AppTheme.borderSubtle),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.thumb_up_outlined, size: 11, color: Colors.white),
                        const SizedBox(width: 4),
                        Text(
                          '${report.upvotes}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
