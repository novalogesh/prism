import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class PrismSectionHeading extends StatelessWidget {
  final String title;
  final String? trailing;

  const PrismSectionHeading({
    super.key,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 17,
          color: AppColors.textPrimary,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.sectionTitle,
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: AppTextStyles.caption,
          ),
      ],
    );
  }
}
