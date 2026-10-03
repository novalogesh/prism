import 'package:flutter/material.dart';

import '../../core/constants/app_spacing.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/prism_section_heading.dart';
import 'models/weather_forecast.dart';

class WeatherPage extends StatelessWidget {
  const WeatherPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Temporary demonstration data.
    // Later this comes from the weather API/cache.
    final forecast = WeatherForecast(
      location: 'Your current area',
      temperature: 29,
      rainProbability: 70,
      rainfallMm: 18,
      windKmh: 16,
      humidity: 78,
      updatedAt: DateTime(2026, 8, 27, 10, 30),
      status: WeatherDataStatus.cached,
    );

    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PRISM',
              style: AppTextStyles.pageTitle,
            ),
            Text(
              'Weather',
              style: AppTextStyles.caption,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {},
            icon: const Icon(Icons.refresh),
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
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  const PrismSectionHeading(
                    title: 'CURRENT WEATHER',
                  ),

                  const SizedBox(height: AppSpacing.md),

                  _CurrentWeatherCard(
                    forecast: forecast,
                  ),

                  const SizedBox(height: AppSpacing.section),

                  const PrismSectionHeading(
                    title: 'FORECAST',
                    trailing: '7 DAYS',
                  ),

                  const SizedBox(height: AppSpacing.md),

                  const _ForecastPreview(),

                  const SizedBox(height: AppSpacing.section),

                  const PrismSectionHeading(
                    title: 'WEATHER MAP',
                    trailing: 'ONLINE ONLY',
                  ),

                  const SizedBox(height: AppSpacing.md),

                  const _WeatherMapCard(),

                  const SizedBox(height: AppSpacing.section),

                  const _OfflineWeatherNotice(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


// ------------------------------------------------------------
// CURRENT WEATHER
// ------------------------------------------------------------

class _CurrentWeatherCard extends StatelessWidget {
  final WeatherForecast forecast;

  const _CurrentWeatherCard({
    required this.forecast,
  });

  @override
  Widget build(BuildContext context) {
    final isOffline =
        forecast.status == WeatherDataStatus.cached;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        border: Border.all(
          color: AppColors.borderDark,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                size: 18,
              ),

              const SizedBox(width: AppSpacing.sm),

              Expanded(
                child: Text(
                  forecast.location,
                  style: AppTextStyles.body,
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isOffline
                        ? AppColors.warning
                        : AppColors.safe,
                  ),
                ),
                child: Text(
                  isOffline ? 'OFFLINE' : 'LIVE',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .8,
                    color: isOffline
                        ? AppColors.warning
                        : AppColors.safe,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xxl),

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [

              const Icon(
                Icons.cloud_outlined,
                size: 48,
              ),

              const SizedBox(width: AppSpacing.lg),

              Text(
                '${forecast.temperature.round()}°C',
                style: const TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w300,
                ),
              ),

              const SizedBox(width: AppSpacing.md),

              const Expanded(
                child: Text(
                  'Rain possible',
                  style: AppTextStyles.bodySecondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),

          const Divider(),

          const SizedBox(height: AppSpacing.md),

          Row(
            children: [
              _WeatherValue(
                icon: Icons.water_drop_outlined,
                label: 'RAIN',
                value: '${forecast.rainProbability}%',
              ),

              _WeatherValue(
                icon: Icons.umbrella_outlined,
                label: 'RAINFALL',
                value: '${forecast.rainfallMm} mm',
              ),

              _WeatherValue(
                icon: Icons.air,
                label: 'WIND',
                value: '${forecast.windKmh} km/h',
              ),

              _WeatherValue(
                icon: Icons.water_outlined,
                label: 'HUMIDITY',
                value: '${forecast.humidity}%',
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),

          Text(
            isOffline
                ? 'LAST UPDATED • ${_formatTime(forecast.updatedAt)}'
                : 'LIVE WEATHER DATA',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour > 12 ? time.hour - 12 : time.hour;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }
}


// ------------------------------------------------------------
// WEATHER VALUE
// ------------------------------------------------------------

class _WeatherValue extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _WeatherValue({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(
            icon,
            size: 18,
            color: AppColors.textSecondary,
          ),

          const SizedBox(height: 5),

          Text(
            label,
            style: AppTextStyles.caption,
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 3),

          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}


// ------------------------------------------------------------
// FORECAST
// ------------------------------------------------------------

class _ForecastPreview extends StatelessWidget {
  const _ForecastPreview();

  @override
  Widget build(BuildContext context) {
    final days = [
      ('TODAY', '29°', '70%', Icons.cloud_outlined),
      ('FRI', '30°', '55%', Icons.cloud_outlined),
      ('SAT', '28°', '80%', Icons.grain),
      ('SUN', '27°', '75%', Icons.grain),
      ('MON', '29°', '45%', Icons.wb_cloudy_outlined),
    ];

    return SizedBox(
      height: 125,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, _) =>
            const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final day = days[index];

          return Container(
            width: 105,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.border,
              ),
            ),
            child: Column(
              children: [
                Text(
                  day.$1,
                  style: AppTextStyles.caption,
                ),

                const SizedBox(height: 10),

                Icon(
                  day.$4,
                  size: 23,
                ),

                const SizedBox(height: 8),

                Text(
                  day.$2,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  'Rain ${day.$3}',
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}


// ------------------------------------------------------------
// WEATHER MAP
// ------------------------------------------------------------

class _WeatherMapCard extends StatelessWidget {
  const _WeatherMapCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 210,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(
          color: AppColors.borderDark,
        ),
      ),
      child: Stack(
        children: [

          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.layers_outlined,
                  size: 42,
                  color: AppColors.textMuted,
                ),

                SizedBox(height: 8),

                Text(
                  'INTERACTIVE WEATHER MAP',
                  style: AppTextStyles.sectionTitle,
                ),

                SizedBox(height: 5),

                Text(
                  'Available when connected to the internet',
                  style: AppTextStyles.bodySecondary,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          Positioned(
            left: 12,
            bottom: 12,
            child: Row(
              children: const [
                _MapLayerButton(
                  icon: Icons.water_drop_outlined,
                  label: 'RAIN',
                ),
                SizedBox(width: 6),
                _MapLayerButton(
                  icon: Icons.air,
                  label: 'WIND',
                ),
                SizedBox(width: 6),
                _MapLayerButton(
                  icon: Icons.thermostat_outlined,
                  label: 'TEMP',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _MapLayerButton extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MapLayerButton({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 13,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}


// ------------------------------------------------------------
// OFFLINE NOTICE
// ------------------------------------------------------------

class _OfflineWeatherNotice extends StatelessWidget {
  const _OfflineWeatherNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 21,
          ),

          SizedBox(width: AppSpacing.sm),

          Expanded(
            child: Text(
              'Forecast information is stored locally so it '
              'can remain available without internet. '
              'Offline forecasts may be outdated.',
              style: AppTextStyles.bodySecondary,
            ),
          ),
        ],
      ),
    );
  }
}


// ------------------------------------------------------------

