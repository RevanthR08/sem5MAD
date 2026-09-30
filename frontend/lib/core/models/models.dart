class Category {
  final String id;
  final String code;
  final String name;
  final String icon;
  final String description;
  final int defaultSlaHours;
  final int duplicateRadiusMeters;
  final List<Subcategory> subcategories;

  Category({
    required this.id,
    required this.code,
    required this.name,
    required this.icon,
    required this.description,
    required this.defaultSlaHours,
    required this.duplicateRadiusMeters,
    required this.subcategories,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    var subs = (json['subcategories'] as List<dynamic>?)
            ?.map((s) => Subcategory.fromJson(s))
            .toList() ??
        [];
    return Category(
      id: json['id'] ?? '',
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      icon: json['icon'] ?? 'Hammer',
      description: json['description'] ?? '',
      defaultSlaHours: json['default_sla_hours'] ?? 48,
      duplicateRadiusMeters: json['duplicate_radius_meters'] ?? 50,
      subcategories: subs,
    );
  }
}

class Subcategory {
  final String id;
  final String code;
  final String name;
  final int slaHours;
  final String priorityLevel;

  Subcategory({
    required this.id,
    required this.code,
    required this.name,
    required this.slaHours,
    required this.priorityLevel,
  });

  factory Subcategory.fromJson(Map<String, dynamic> json) {
    return Subcategory(
      id: json['id'] ?? '',
      code: json['code'] ?? '',
      name: json['name'] ?? '',
      slaHours: json['sla_hours'] ?? 48,
      priorityLevel: json['priority_level'] ?? 'MEDIUM',
    );
  }
}

class SLAInfo {
  final String status;
  final String badgeColor;
  final String label;
  final double hoursRemaining;
  final bool isBreached;

  SLAInfo({
    required this.status,
    required this.badgeColor,
    required this.label,
    required this.hoursRemaining,
    required this.isBreached,
  });

  factory SLAInfo.fromJson(Map<String, dynamic> json) {
    return SLAInfo(
      status: json['status'] ?? 'WITHIN_SLA',
      badgeColor: json['badge_color'] ?? 'green',
      label: json['label'] ?? 'Within SLA',
      hoursRemaining: (json['hours_remaining'] as num?)?.toDouble() ?? 0.0,
      isBreached: json['is_breached'] ?? false,
    );
  }
}

class CivicReport {
  final String id;
  final String publicId;
  final String title;
  final String description;
  final String status;
  final String priority;
  final String severity;
  final double latitude;
  final double longitude;
  final String? address;
  final String? landmark;
  final String? categoryId;
  final String? categoryName;
  final String? categoryIcon;
  final String? subcategoryName;
  final String? departmentName;
  final String? wardName;
  final String? wardNumber;
  final String? assignedTeam;
  final String? assignedOfficerName;
  final int slaHours;
  final SLAInfo? slaInfo;
  final int upvotes;
  final String? thumbnailUrl;
  final String? resolutionBeforePhoto;
  final String? resolutionAfterPhoto;
  final String? resolutionNotes;
  final bool? citizenVerified;
  final String? citizenFeedback;
  final String? createdAt;
  final List<TimelineEvent> timeline;
  final List<ReportMedia> media;

  CivicReport({
    required this.id,
    required this.publicId,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    required this.severity,
    required this.latitude,
    required this.longitude,
    this.address,
    this.landmark,
    this.categoryId,
    this.categoryName,
    this.categoryIcon,
    this.subcategoryName,
    this.departmentName,
    this.wardName,
    this.wardNumber,
    this.assignedTeam,
    this.assignedOfficerName,
    this.slaHours = 48,
    this.slaInfo,
    this.upvotes = 1,
    this.thumbnailUrl,
    this.resolutionBeforePhoto,
    this.resolutionAfterPhoto,
    this.resolutionNotes,
    this.citizenVerified,
    this.citizenFeedback,
    this.createdAt,
    this.timeline = const [],
    this.media = const [],
  });

  factory CivicReport.fromJson(Map<String, dynamic> json) {
    var tList = (json['timeline'] as List<dynamic>?)
            ?.map((t) => TimelineEvent.fromJson(t))
            .toList() ??
        [];
    var mList = (json['media'] as List<dynamic>?)
            ?.map((m) => ReportMedia.fromJson(m))
            .toList() ??
        [];
    var sla = json['sla_info'] != null ? SLAInfo.fromJson(json['sla_info']) : null;

    return CivicReport(
      id: json['id'] ?? '',
      publicId: json['public_id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      status: json['status'] ?? 'SUBMITTED',
      priority: json['priority'] ?? 'MEDIUM',
      severity: json['severity'] ?? 'MEDIUM',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 13.04,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 80.25,
      address: json['address'],
      landmark: json['landmark'],
      categoryId: json['category_id'],
      categoryName: json['category_name'],
      categoryIcon: json['category_icon'],
      subcategoryName: json['subcategory_name'],
      departmentName: json['department_name'],
      wardName: json['ward_name'],
      wardNumber: json['ward_number'],
      assignedTeam: json['assigned_team'],
      assignedOfficerName: json['assigned_officer_name'],
      slaHours: json['sla_hours'] ?? 48,
      slaInfo: sla,
      upvotes: json['upvotes'] ?? 1,
      thumbnailUrl: json['thumbnail_url'],
      resolutionBeforePhoto: json['resolution_before_photo'],
      resolutionAfterPhoto: json['resolution_after_photo'] ?? json['after_photo_url'],
      resolutionNotes: json['resolution_notes'],
      citizenVerified: json['citizen_verified'],
      citizenFeedback: json['citizen_feedback'],
      createdAt: json['created_at'],
      timeline: tList,
      media: mList,
    );
  }
}

class TimelineEvent {
  final String eventType;
  final String? oldStatus;
  final String? newStatus;
  final String? actorName;
  final String? actorRole;
  final String? notes;
  final String? mediaUrl;
  final String? createdAt;

  TimelineEvent({
    required this.eventType,
    this.oldStatus,
    this.newStatus,
    this.actorName,
    this.actorRole,
    this.notes,
    this.mediaUrl,
    this.createdAt,
  });

  factory TimelineEvent.fromJson(Map<String, dynamic> json) {
    return TimelineEvent(
      eventType: json['event_type'] ?? '',
      oldStatus: json['old_status'],
      newStatus: json['new_status'],
      actorName: json['actor_name'],
      actorRole: json['actor_role'],
      notes: json['notes'],
      mediaUrl: json['media_url'],
      createdAt: json['created_at'],
    );
  }
}

class ReportMedia {
  final String id;
  final String url;
  final String? caption;
  final String stage;

  ReportMedia({
    required this.id,
    required this.url,
    this.caption,
    required this.stage,
  });

  factory ReportMedia.fromJson(Map<String, dynamic> json) {
    return ReportMedia(
      id: json['id'] ?? '',
      url: json['url'] ?? '',
      caption: json['caption'],
      stage: json['stage'] ?? 'SUBMISSION',
    );
  }
}

class DuplicateReportItem {
  final String id;
  final String publicId;
  final String title;
  final String? address;
  final double distanceMeters;
  final String? thumbnailUrl;
  final String status;
  final int upvotes;

  DuplicateReportItem({
    required this.id,
    required this.publicId,
    required this.title,
    this.address,
    required this.distanceMeters,
    this.thumbnailUrl,
    required this.status,
    required this.upvotes,
  });

  factory DuplicateReportItem.fromJson(Map<String, dynamic> json) {
    return DuplicateReportItem(
      id: json['id'] ?? '',
      publicId: json['public_id'] ?? '',
      title: json['title'] ?? '',
      address: json['address'],
      distanceMeters: (json['distance_meters'] as num?)?.toDouble() ?? 0.0,
      thumbnailUrl: json['thumbnail_url'],
      status: json['status'] ?? 'SUBMITTED',
      upvotes: json['upvotes'] ?? 1,
    );
  }
}

class AnalyticsOverview {
  final int totalReports;
  final int openReports;
  final int inProgress;
  final int awaitingVerification;
  final int resolvedReports;
  final int reopenedReports;
  final int criticalActive;
  final int overdueReports;
  final double slaCompliancePct;
  final List<dynamic> categoryDistribution;
  final List<dynamic> wardPerformance;

  AnalyticsOverview({
    required this.totalReports,
    required this.openReports,
    required this.inProgress,
    required this.awaitingVerification,
    required this.resolvedReports,
    required this.reopenedReports,
    required this.criticalActive,
    required this.overdueReports,
    required this.slaCompliancePct,
    required this.categoryDistribution,
    required this.wardPerformance,
  });

  factory AnalyticsOverview.fromJson(Map<String, dynamic> json) {
    return AnalyticsOverview(
      totalReports: json['total_reports'] ?? 0,
      openReports: json['open_reports'] ?? 0,
      inProgress: json['in_progress'] ?? 0,
      awaitingVerification: json['awaiting_verification'] ?? 0,
      resolvedReports: json['resolved_reports'] ?? 0,
      reopenedReports: json['reopened_reports'] ?? 0,
      criticalActive: json['critical_active'] ?? 0,
      overdueReports: json['overdue_reports'] ?? 0,
      slaCompliancePct: (json['sla_compliance_pct'] as num?)?.toDouble() ?? 100.0,
      categoryDistribution: json['category_distribution'] ?? [],
      wardPerformance: json['ward_performance'] ?? [],
    );
  }
}
