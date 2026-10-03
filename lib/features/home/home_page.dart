import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/prism_action_button.dart';
import '../../core/widgets/prism_section_heading.dart';

class HomePage extends StatelessWidget {
  final void Function(int)? onNavigate;

  const HomePage({
    super.key,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        titleSpacing: AppSpacing.xl,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PRISM',
              style: AppTextStyles.pageTitle,
            ),
            Text(
              'Flood Hazard Awareness',
              style: AppTextStyles.caption,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () {},
            icon: const Icon(Icons.notifications_none),
          ),
          IconButton(
            tooltip: 'Profile',
            onPressed: () {},
            icon: const Icon(Icons.person_outline),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            32,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 900,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PrismSectionHeading(
                    title: 'YOUR AREA',
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  const _LocationRow(),

                  const SizedBox(height: AppSpacing.xxl),

                  const PrismSectionHeading(
                    title: 'CURRENT CONDITIONS',
                  ),

                  const SizedBox(height: AppSpacing.md),

                  const _CurrentStatus(),

                  const SizedBox(height: AppSpacing.section),

                  const PrismSectionHeading(
                    title: 'ACTIVE HAZARDS',
                    trailing: '0 REPORTS',
                  ),

                  const SizedBox(height: AppSpacing.md),

                  const _ActiveHazards(),

                  const SizedBox(height: AppSpacing.section),

                  const PrismSectionHeading(
                    title: 'WHAT WOULD YOU LIKE TO DO?',
                  ),

                  const SizedBox(height: AppSpacing.md),

                  PrismActionButton(
                    icon: Icons.map_outlined,
                    title: 'VIEW FLOOD MAP',
                    subtitle:
                        'See hazards and risk information around you',
                    onTap: () => onNavigate?.call(1),
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  PrismActionButton(
                    icon: Icons.add_location_alt_outlined,
                    title: 'REPORT A HAZARD',
                    subtitle:
                        'Report an open manhole, flood, wire or other hazard',
                    onTap: () => onNavigate?.call(2),
                  ),

                  const SizedBox(height: AppSpacing.sm),

                  PrismActionButton(
                    icon: Icons.menu_book_outlined,
                    title: 'SAFETY INFORMATION',
                    subtitle:
                        'Learn what to do before and during flooding',
                    onTap: () {},
                  ),

                  const SizedBox(height: AppSpacing.section),

                  const _OfflineInformation(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.location_on_outlined,
          size: 20,
          color: AppColors.textPrimary,
        ),
        const SizedBox(width: AppSpacing.sm),
        const Expanded(
          child: Text(
            'Location not available yet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 9,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            border: Border.all(
              color: Color(0xFF888888),
            ),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            'GPS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ),
      ],
    );
  }
}

class _CurrentStatus extends StatelessWidget {
  const _CurrentStatus();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        border: Border.all(
          color: AppColors.borderDark,
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FLOOD RISK',
            style: AppTextStyles.caption,
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            'NO CURRENT WARNING',
            style: AppTextStyles.heading,
          ),
          SizedBox(height: AppSpacing.md),
          Text(
            'No verified active flood warning is currently '
            'available for your area.',
            style: AppTextStyles.bodySecondary,
          ),
          SizedBox(height: AppSpacing.md),
          Divider(),
          SizedBox(height: AppSpacing.sm),
          Text(
            'LAST UPDATED  •  NOT AVAILABLE',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}

class _ActiveHazards extends StatelessWidget {
  const _ActiveHazards();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 25,
            color: AppColors.safe,
          ),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NO ACTIVE HAZARDS',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Verified hazard information will appear here.',
                  style: AppTextStyles.bodySecondary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OfflineInformation extends StatelessWidget {
  const _OfflineInformation();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.cloud_outlined,
            size: 20,
          ),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'PRISM can continue working with locally stored '
              'information when internet connectivity is unavailable.',
              style: AppTextStyles.bodySecondary,
            ),
          ),
        ],
      ),
    );
  }
}
