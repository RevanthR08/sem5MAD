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
  bool _onlyMine = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final userId = Provider.of<AppState>(context, listen: false).userId;
    setState(() => _loading = true);
    try {
      // Fetch both in parallel
      final (reports, analytics) = await (
        _api.getReports(userId: _onlyMine ? userId : null),
        _api.getAnalyticsOverview(),
      ).wait;
      if (!mounted) return;
      setState(() {
        _reports = reports;
        _analytics = analytics;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load reports: ${e.toString().replaceFirst('Exception: ', '')}'), backgroundColor: AppTheme.danger),
      );
    }
  }

  Future<void> _handleUpvote(String reportId) async {
    try {
      final result = await _api.upvoteReport(reportId);
      if (!mounted) return;
      setState(() {
        _reports = _reports.map((r) => r.id == reportId ? r.copyWith(upvotes: result.upvotes) : r).toList();
      });
      if (result.alreadyUpvoted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You already support this report.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upvote failed: ${e.toString().replaceFirst('Exception: ', '')}'), backgroundColor: AppTheme.danger),
      );
    }
  }

  Widget _feedToggle(String label, bool mine) {
    final sel = _onlyMine == mine;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: sel,
        visualDensity: VisualDensity.compact,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        backgroundColor: AppTheme.bgCard,
        selectedColor: AppTheme.ink,
        labelStyle: TextStyle(color: sel ? AppTheme.inkInverse : AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w700),
        onSelected: (v) {
          if (v && !sel) {
            setState(() => _onlyMine = mine);
            _loadData();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);

    if (_loading) {
      return Center(child: CircularProgressIndicator(color: AppTheme.ink));
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: AppTheme.ink,
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
                        decoration: BoxDecoration(color: AppTheme.ink, shape: BoxShape.rectangle),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'WARD 123 • MYLAPORE & ANNA SALAI, GCC',
                        style: TextStyle(
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
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
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
                    _buildStatCol('TO VERIFY', '${_analytics!.awaitingVerification}'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Nearby Civic Issues Feed
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _onlyMine ? 'MY REPORTS' : 'NEARBY CIVIC REPORTS',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.textMuted, letterSpacing: 0.8),
                  ),
                ),
                _feedToggle('All', false),
                _feedToggle('Mine', true),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${_reports.where((r) => r.isOpen).length} open of ${_reports.length}',
              style: TextStyle(fontSize: 10, color: AppTheme.ink, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            if (_reports.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(4)),
                child: Text(
                  _onlyMine ? "You haven't reported any issues yet." : 'No reports yet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
              ),

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
            Icon(icon, color: AppTheme.ink, size: 18),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
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
          style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: AppTheme.textMuted, letterSpacing: 0.5),
        ),
        const SizedBox(height: 2),
        Text(
          val,
          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.ink),
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
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.ink),
                ),
                StatusBadge(status: report.status),
              ],
            ),
            const SizedBox(height: 6),

            Text(
              report.title,
              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.ink),
            ),
            const SizedBox(height: 2),
            Text(
              report.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4),
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
                Icon(Icons.location_on_outlined, size: 12, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    report.address ?? '${report.latitude.toStringAsFixed(4)}, ${report.longitude.toStringAsFixed(4)}',
                    style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
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
                  style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
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
                        Icon(Icons.thumb_up_outlined, size: 11, color: AppTheme.ink),
                        const SizedBox(width: 4),
                        Text(
                          '${report.upvotes}',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.ink),
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
