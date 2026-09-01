import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../utils/app_colors.dart';

/// The app's beet logo rendered as an SVG, tinted with the app accent.
///
/// The source is a silhouette, so it is recolored to [AppColors.accent]. A
/// small inset keeps the logo from touching the edges of its frame.
class BeetLogo extends StatelessWidget {

  const BeetLogo({super.key, this.size = 28, this.color = AppColors.accent});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final inset = size * 0.25;
    return SizedBox(
      width: size,
      height: size,
      child: Padding(
        padding: EdgeInsets.all(inset),
        child: SizedBox(
          width: size - inset * 2,
          height: size - inset * 2,
          child: SvgPicture.asset(
            'assets/icons/beet.svg',
            fit: BoxFit.contain,
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
            placeholderBuilder: (context) => Icon(
              Icons.music_note_rounded,
              size: (size - inset * 2) * 0.7,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
