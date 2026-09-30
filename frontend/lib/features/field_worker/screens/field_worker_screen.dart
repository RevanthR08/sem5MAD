import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/models/models.dart';
import '../../../core/services/api_service.dart';
import '../../../core/providers/app_state.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/status_badge.dart';

class FieldWorkerScreen extends StatefulWidget {
  const FieldWorkerScreen({super.key});

  @override
  State<FieldWorkerScreen> createState() => _FieldWorkerScreenState();
}

class _FieldWorkerScreenState extends State<FieldWorkerScreen> {
  final ApiService _api = ApiService();
  final ImagePicker _picker = ImagePicker();
  List<CivicReport> _assignedTasks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    setState(() => _loading = true);
    try {
      final reps = await _api.getReports();
      setState(() {
        _assignedTasks = reps.where((r) => r.status == 'ASSIGNED' || r.status == 'IN_PROGRESS' || r.status == 'RESOLUTION_SUBMITTED').toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _startWork(CivicReport task) async {
    final appState = Provider.of<AppState>(context, listen: false);
    try {
      await _api.updateReportStatus(task.id, {
        'status': 'IN_PROGRESS',
        'actor_name': appState.userName,
        'actor_role': 'FIELD_WORKER',
        'notes': 'Field maintenance team arrived on site and started repair work.',
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Status: IN PROGRESS. Work started on site!'), backgroundColor: AppTheme.success),
      );
      _loadTasks();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to start work: $e'), backgroundColor: AppTheme.danger),
      );
    }
  }

  void _showResolutionDialog(CivicReport task) {
    final notesCtrl = TextEditingController(text: 'Work completed on site. Inspected and repaired per municipal standards.');
    String beforeUrl = task.thumbnailUrl ?? 'https://images.unsplash.com/photo-1515162816999-a0c47dc192f7?w=800';
    String afterUrl = 'https://images.unsplash.com/photo-1541888946425-d0fbb186156f?w=800';
    bool submitting = false;
    bool uploading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppTheme.bgCard,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)), // Almost square
              title: Row(
                children: [
                  const Icon(Icons.task_alt, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text('Submit Resolution Proof', style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 16)),
                ],
              ),
              content: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ticket: ${task.publicId} • ${task.title}', style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),

                    // Before & After Proof Photo View
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('BEFORE REPAIR', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.warning)),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: CachedNetworkImage(imageUrl: beforeUrl, height: 80, width: double.infinity, fit: BoxFit.cover),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('AFTER PROOF PHOTO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.success)),
                              const SizedBox(height: 4),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(2),
                                child: uploading
                                    ? Container(height: 80, color: AppTheme.bgSecondary, child: const Center(child: CircularProgressIndicator(color: Colors.white)))
                                    : CachedNetworkImage(imageUrl: afterUrl, height: 80, width: double.infinity, fit: BoxFit.cover),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // CAMERA BUTTON FOR FIELD WORKER
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: uploading
                                ? null
                                : () async {
                                    try {
                                      final XFile? file = await _picker.pickImage(source: ImageSource.camera, maxWidth: 1200);
                                      if (file == null) return;
                                      setDialogState(() => uploading = true);
                                      final bytes = await file.readAsBytes();
                                      final b64 = base64Encode(bytes);
                                      final url = await _api.uploadImage(b64, filename: 'after_${file.name}');
                                      setDialogState(() {
                                        afterUrl = url;
                                        uploading = false;
                                      });
                                    } catch (e) {
                                      setDialogState(() => uploading = false);
                                    }
                                  },
                            icon: const Icon(Icons.camera_alt_outlined, size: 14),
                            label: const Text('Capture Camera Proof', style: TextStyle(fontSize: 11)),
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6)),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    TextField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Resolution Summary Notes',
                        hintText: 'Describe actions taken to fix problem...',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                ),
                ElevatedButton.icon(
                  onPressed: submitting
                      ? null
                      : () async {
                          setDialogState(() => submitting = true);
                          try {
                            final appState = Provider.of<AppState>(context, listen: false);
                            await _api.resolveReport(
                              reportId: task.id,
                              resolutionNotes: notesCtrl.text.trim(),
                              beforePhoto: beforeUrl,
                              afterPhoto: afterUrl,
                              workerName: appState.userName,
                            );
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Resolution submitted! Awaiting Citizen Verification.'),
                                backgroundColor: AppTheme.success,
                              ),
                            );
                            _loadTasks();
                          } catch (e) {
                            setDialogState(() => submitting = false);
                          }
                        },
                  icon: submitting
                      ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Icon(Icons.check, size: 14),
                  label: const Text('Submit Proof'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = Provider.of<AppState>(context, listen: false);

    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppTheme.borderSubtle),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Icon(Icons.construction, color: Colors.black, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${appState.userName} — Operations',
                        style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
                      ),
                      const Text(
                        'Road Maintenance Rapid Team 4 • GCC',
                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.bgSecondary,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: Text(
                    '${_assignedTasks.length} Assigned',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Text(
            'Assigned Work Orders Queue',
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          const Text(
            'Tasks sorted by priority. Capture before & after proof upon completion.',
            style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 14),

          if (_assignedTasks.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(28),
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Column(
                children: [
                  Icon(Icons.task_alt, size: 40, color: AppTheme.success),
                  SizedBox(height: 8),
                  Text('All clear! No pending work orders.', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
            ),
          ] else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _assignedTasks.length,
              separatorBuilder: (c, i) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final task = _assignedTasks[index];

                return Container(
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
                          Text(task.publicId, style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 12)),
                          StatusBadge(status: task.status),
                        ],
                      ),
                      const SizedBox(height: 6),

                      Text(
                        task.title,
                        style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        task.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 8),

                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 12, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              task.address ?? '${task.latitude}, ${task.longitude}',
                              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Actions
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Starting GPS navigation to ${task.address}...')),
                              );
                            },
                            icon: const Icon(Icons.navigation_outlined, size: 12),
                            label: const Text('Navigate', style: TextStyle(fontSize: 11)),
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                          ),

                          if (task.status == 'ASSIGNED')
                            ElevatedButton.icon(
                              onPressed: () => _startWork(task),
                              icon: const Icon(Icons.play_arrow_rounded, size: 14),
                              label: const Text('Start Work', style: TextStyle(fontSize: 11)),
                              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                            ),

                          if (task.status == 'IN_PROGRESS')
                            ElevatedButton.icon(
                              onPressed: () => _showResolutionDialog(task),
                              icon: const Icon(Icons.task_alt, size: 14),
                              label: const Text('Submit Resolution Proof', style: TextStyle(fontSize: 11)),
                              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                            ),

                          OutlinedButton(
                            onPressed: () => appState.openReportDetail(task.publicId),
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6)),
                            child: const Text('Details', style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
