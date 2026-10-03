import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/models/hazard_report.dart';

class ReportDetailsPage extends StatelessWidget {
  final HazardReport report;

  const ReportDetailsPage({
    super.key,
    required this.report,
  });

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

  @override
  Widget build(BuildContext context) {
    final hasLocation =
        report.latitude != null &&
        report.longitude != null;

    final hasPhoto =
        report.photoPath != null &&
        report.photoPath!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'REPORT DETAILS',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          _section(
            context,
            'HAZARD',
            [
              _row(
                context,
                'TYPE',
                report.hazardType,
              ),
              _row(
                context,
                'SELECTED SEVERITY',
                report.severity ?? 'Not specified',
              ),
              if (report.description.isNotEmpty)
                _row(
                  context,
                  'DESCRIPTION',
                  report.description,
                ),
            ],
          ),

          const SizedBox(height: 16),

          _section(
            context,
            'TIME',
            [
              _row(
                context,
                'DATE',
                _date(report.capturedAt),
              ),
              _row(
                context,
                'TIME',
                _time(report.capturedAt),
              ),
            ],
          ),

          const SizedBox(height: 16),

          _section(
            context,
            'LOCATION',
            [
              if (report.locationName != null &&
                  report.locationName!.trim().isNotEmpty)
                _row(
                  context,
                  'GPS LOCATION',
                  report.locationName!,
                ),

              if (report.reporterAddress != null &&
                  report.reporterAddress!.trim().isNotEmpty)
                _row(
                  context,
                  'REPORTER PROVIDED ADDRESS',
                  report.reporterAddress!,
                ),

              if (hasLocation) ...[
                _row(
                  context,
                  'LATITUDE',
                  report.latitude!.toStringAsFixed(6),
                ),
                _row(
                  context,
                  'LONGITUDE',
                  report.longitude!.toStringAsFixed(6),
                ),
              ] else
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Location coordinates are not available.',
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          _section(
            context,
            'STATUS',
            [
              _row(
                context,
                'SYNC STATE',
                report.syncState.displayLabel,
              ),
              _row(
                context,
                'LIFECYCLE',
                report.lifecycleStatus.displayLabel,
              ),
              _row(
                context,
                'NEARBY SHARING',
                report.sharedNearby
                    ? 'SHARED'
                    : 'NOT SHARED',
              ),
            ],
          ),

          if (hasPhoto) ...[
            const SizedBox(height: 16),
            _section(
              context,
              'PHOTO EVIDENCE',
              [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(report.photoPath!),
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) {
                      return const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'Photo file is unavailable.',
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),

          _section(
            context,
            'IDENTIFICATION',
            [
              _row(
                context,
                'REPORT ID',
                report.id,
              ),
              _row(
                context,
                'CREATED',
                '${_date(report.createdAt)} ${_time(report.createdAt)}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _section(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outline
              .withValues(alpha: 0.5),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}




