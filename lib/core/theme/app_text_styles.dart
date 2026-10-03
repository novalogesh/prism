import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  AppTextStyles._();

  static const pageTitle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.2,
    color: AppColors.textPrimary,
  );

  static const sectionTitle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.2,
    color: AppColors.textPrimary,
  );

  static const heading = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static const body = TextStyle(
    fontSize: 14,
    height: 1.5,
    color: AppColors.textPrimary,
  );

  static const bodySecondary = TextStyle(
    fontSize: 13,
    height: 1.5,
    color: AppColors.textSecondary,
  );

  static const caption = TextStyle(
    fontSize: 10,
    letterSpacing: 1,
    fontWeight: FontWeight.w600,
    color: AppColors.textMuted,
  );

  static const button = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w800,
    letterSpacing: .7,
    color: AppColors.textPrimary,
  );
}
