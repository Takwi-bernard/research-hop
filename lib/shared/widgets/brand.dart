import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_palette.dart';

enum BrandMarkVariant {
  /// Normal pages. In dark mode the logo sits on a white tile so the navy
  /// letters stay readable.
  normal,

  /// On top of the accent colour: always on a white tile.
  onAccent,
}

/// Width divided by height of assets/brand/logo_mark.png.
const double _markAspect = 420 / 250;

/// The Research Hop logo mark (cap, R and H). [size] is its height.
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.size = 40,
    this.variant = BrandMarkVariant.normal,
  });

  final double size;
  final BrandMarkVariant variant;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tiled = dark || variant == BrandMarkVariant.onAccent;
    final image = Image.asset(
      'assets/brand/logo_mark.png',
      height: size,
      width: size * _markAspect,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'Research Hop logo',
    );
    if (!tiled) return image;
    final pad = size * 0.14;
    return Container(
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.22),
      ),
      child: image,
    );
  }
}

/// The mark followed by the name, "Research" in regular and "Hop" in italic.
class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key, this.size = 36, this.onAccent = false});

  final double size;
  final bool onAccent;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final base = GoogleFonts.fraunces(
      fontSize: size * 0.56,
      fontWeight: FontWeight.w700,
      color: onAccent ? p.accentInk : p.ink,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        BrandMark(
          size: size,
          variant: onAccent ? BrandMarkVariant.onAccent : BrandMarkVariant.normal,
        ),
        SizedBox(width: size * 0.28),
        Flexible(
          child: Text.rich(
            TextSpan(
              text: 'Research ',
              style: base,
              children: [
                TextSpan(
                  text: 'Hop',
                  style: base.copyWith(
                    color: onAccent ? p.accentInk : p.accent,
                  ),
                ),
              ],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

const String _googleGSvg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">'
    '<path fill="#4285F4" d="M45.12 24.5c0-1.56-.14-3.06-.4-4.5H24v8.51h11.84c-.51 2.75-2.06 5.08-4.39 6.64v5.52h7.11c4.16-3.83 6.56-9.47 6.56-16.17z"/>'
    '<path fill="#34A853" d="M24 46c5.94 0 10.92-1.97 14.56-5.33l-7.11-5.52c-1.97 1.32-4.49 2.1-7.45 2.1-5.73 0-10.58-3.87-12.31-9.07H4.34v5.7C7.96 41.07 15.4 46 24 46z"/>'
    '<path fill="#FBBC05" d="M11.69 28.18C11.25 26.86 11 25.45 11 24s.25-2.86.69-4.18v-5.7H4.34C2.85 17.09 2 20.45 2 24c0 3.55.85 6.91 2.34 9.88l7.35-5.7z"/>'
    '<path fill="#EA4335" d="M24 10.75c3.23 0 6.13 1.11 8.41 3.29l6.31-6.31C34.91 4.18 29.93 2 24 2 15.4 2 7.96 6.93 4.34 14.12l7.35 5.7c1.73-5.2 6.58-9.07 12.31-9.07z"/>'
    '</svg>';

class GoogleLogo extends StatelessWidget {
  const GoogleLogo({super.key, this.size = 20});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      _googleGSvg,
      width: size,
      height: size,
      semanticsLabel: 'Google',
    );
  }
}
