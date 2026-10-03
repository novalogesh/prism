import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/models/hazard_report.dart';
import '../../core/storage/report_storage.dart';
import 'report_details_page.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final ReportStorage _storage = ReportStorage();

  List<HazardReport> _reports = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    try {
      final reports = await _storage
          .getReports()
          .timeout(const Duration(seconds: 5));

      if (!mounted) return;

      setState(() {
        _reports = reports.reversed.toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _reports = [];
        _loading = false;
      });
    }
  }

  String _date(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/'
        '${value.year}';
  }

  String _time(DateTime value) {
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final period = value.hour >= 12 ? 'PM' : 'AM';

    return '${hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')} $period';
  }

  Future<void> _deleteReport(HazardReport report) async {
    await _storage.deleteReport(report.id);
    await _loadReports();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'MY REPORTS',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadReports,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _reports.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadReports,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _reports.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      return _ReportCard(
                        report: _reports[index],
                        date: _date(_reports[index].createdAt),
                        time: _time(_reports[index].createdAt),
                        onDelete: () =>
                            _deleteReport(_reports[index]),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ReportDetailsPage(
                                report: _reports[index],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.description_outlined,
              size: 54,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.45),
            ),
            const SizedBox(height: 18),
            const Text(
              'NO REPORTS YET',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Reports created offline will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final HazardReport report;
  final String date;
  final String time;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const _ReportCard({
    required this.report,
    required this.date,
    required this.time,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto =
        report.photoPath != null &&
        report.photoPath!.isNotEmpty;

    final hasLocation =
        report.latitude != null &&
        report.longitude != null;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      report.hazardType,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'delete') {
                        onDelete();
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete report'),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 6),

              Text(
                report.id,
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 0.5,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.55),
                ),
              ),

              const SizedBox(height: 14),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outline
                        .withValues(alpha: 0.6),
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sync: ${report.syncState.displayLabel}',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      'Lifecycle: ${report.lifecycleStatus.displayLabel}',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (report.sharedNearby)
                      const Text(
                        'Nearby sharing: SHARED',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                  ],
                ),
              ),

              if (report.description.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  report.description,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    height: 1.4,
                  ),
                ),
              ],
              if (report.locationName != null &&
                  report.locationName!.trim().isNotEmpty) ...[
                const SizedBox(height: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'GPS LOCATION',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      report.locationName!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],

              if (report.reporterAddress != null &&
                  report.reporterAddress!.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'REPORTER PROVIDED ADDRESS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      report.reporterAddress!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 14),

              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(date),
                  const SizedBox(width: 16),
                  const Icon(
                    Icons.access_time,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(time),
                ],
              ),

              const SizedBox(height: 14),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _StatusChip(
                    icon: Icons.cloud_off_outlined,
                    label: report.status,
                  ),

                  if (hasPhoto)
                    const _StatusChip(
                      icon: Icons.photo_outlined,
                      label: 'PHOTO',
                    ),

                  if (hasLocation)
                    const _StatusChip(
                      icon: Icons.location_on_outlined,
                      label: 'LOCATION',
                    ),

                  if (report.sharedNearby)
                    const _StatusChip(
                      icon: Icons.devices_outlined,
                      label: 'SHARED',
                    ),
                ],
              ),

              if (hasPhoto) ...[
                const SizedBox(height: 14),
                _PhotoPreview(
                  path: report.photoPath!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatusChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outline
              .withValues(alpha: 0.5),
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoPreview extends StatelessWidget {
  final String path;

  const _PhotoPreview({
    required this.path,
  });

  @override
  Widget build(BuildContext context) {
    final file = File(path);

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: FutureBuilder<bool>(
        future: file.exists(),
        builder: (context, snapshot) {
          if (snapshot.data != true) {
            return Container(
              height: 100,
              alignment: Alignment.center,
              child: const Text(
                'PHOTO FILE UNAVAILABLE',
              ),
            );
          }

          return Image.file(
            file,
            height: 180,
            width: double.infinity,
            fit: BoxFit.cover,
          );
        },
      ),
    );
  }
}









