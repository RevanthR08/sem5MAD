import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';
import '../../../core/providers/app_state.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/status_badge.dart';

class ExploreMapScreen extends StatefulWidget {
  const ExploreMapScreen({super.key});

  @override
  State<ExploreMapScreen> createState() => _ExploreMapScreenState();
}

class _ExploreMapScreenState extends State<ExploreMapScreen> {
  final ApiService _api = ApiService();
  List<CivicReport> _reports = [];
  CivicReport? _selectedReport;
  String _statusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    try {
      final reps = await _api.getReports(status: _statusFilter);
      if (!mounted) return;
      setState(() {
        _reports = reps;
        // Keep the preview card in sync with the filtered markers
        if (!reps.any((r) => r.id == _selectedReport?.id)) {
          _selectedReport = reps.isNotEmpty ? reps.first : null;
        }
      });
    } catch (e) {
      // Ignore
    }
  }

  Color _getMarkerColor(CivicReport r) {
    if (r.status == 'RESOLVED') return AppTheme.success;
    if (const {'ACKNOWLEDGED', 'ASSIGNED', 'IN_PROGRESS', 'RESOLUTION_SUBMITTED'}.contains(r.status)) return AppTheme.ink;
    if (r.priority == 'CRITICAL') return AppTheme.danger;
    if (r.priority == 'HIGH') return AppTheme.warning;
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);

    return Stack(
      children: [
        FlutterMap(
          options: const MapOptions(
            initialCenter: LatLng(13.0418, 80.2507),
            initialZoom: 13.5,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'org.civicconnect.app',
            ),
            MarkerLayer(
              markers: _reports.map((report) {
                final isSelected = _selectedReport?.id == report.id;
                final color = _getMarkerColor(report);

                return Marker(
                  point: LatLng(report.latitude, report.longitude),
                  width: isSelected ? 38 : 28,
                  height: isSelected ? 38 : 28,
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedReport = report),
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.rectangle,
                        borderRadius: BorderRadius.circular(2), // Almost square pin
                        border: Border.all(color: AppTheme.inkInverse, width: isSelected ? 2 : 1),
                      ),
                      child: Icon(
                        report.status == 'RESOLVED' ? Icons.check : Icons.warning_amber_rounded,
                        color: color == AppTheme.ink ? AppTheme.inkInverse : AppTheme.onAccent,
                        size: isSelected ? 20 : 14,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),

        // Filter Bar (Never overflows, horizontal scroll)
        Positioned(
          top: 12,
          left: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.bgPrimary.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text('FILTER:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppTheme.textMuted)),
                  const SizedBox(width: 8),
                  _buildFilterChip('ALL', 'All Issues'),
                  _buildFilterChip('SUBMITTED,ROUTED,REOPENED', 'Reported'),
                  _buildFilterChip('ACKNOWLEDGED,ASSIGNED,IN_PROGRESS,BLOCKED', 'In Progress'),
                  _buildFilterChip('RESOLUTION_SUBMITTED', 'To Verify'),
                  _buildFilterChip('RESOLVED', 'Resolved'),
                ],
              ),
            ),
          ),
        ),

        // Bottom Preview Card (Square & Compact)
        if (_selectedReport != null)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_selectedReport!.thumbnailUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: CachedNetworkImage(
                        imageUrl: _selectedReport!.thumbnailUrl!,
                        width: 70,
                        height: 70,
                        fit: BoxFit.cover,
                      ),
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(_selectedReport!.publicId, style: TextStyle(color: AppTheme.ink, fontWeight: FontWeight.w700, fontSize: 11)),
                            StatusBadge(status: _selectedReport!.status),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _selectedReport!.title,
                          style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.ink),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _selectedReport!.address ?? 'Chennai City',
                          style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _selectedReport!.slaInfo?.label ?? '${_selectedReport!.slaHours}h SLA',
                              style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                            ),
                            ElevatedButton(
                              onPressed: () => appState.openReportDetail(_selectedReport!.publicId),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                textStyle: const TextStyle(fontSize: 11),
                              ),
                              child: const Text('View Report'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFilterChip(String val, String label) {
    final isSel = _statusFilter == val;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: isSel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        backgroundColor: AppTheme.bgCard,
        selectedColor: AppTheme.ink,
        labelStyle: TextStyle(
          color: isSel ? AppTheme.inkInverse : AppTheme.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        onSelected: (selected) {
          if (selected) {
            setState(() => _statusFilter = val);
            _loadReports();
          }
        },
      ),
    );
  }
}
