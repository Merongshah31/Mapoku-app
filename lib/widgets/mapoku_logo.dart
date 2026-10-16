import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// mapOKU wordmark: logo image + product name, matching the web header.
class MapokuLogo extends StatelessWidget {
  const MapokuLogo({super.key, this.height = 32, this.showWordmark = true});

  final double height;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/mapoku2.png',
          height: height,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
        if (showWordmark) ...[
          const SizedBox(width: 10),
          Text(
            'mapOKU',
            style: TextStyle(
              fontSize: height * 0.72,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ],
    );
  }
}