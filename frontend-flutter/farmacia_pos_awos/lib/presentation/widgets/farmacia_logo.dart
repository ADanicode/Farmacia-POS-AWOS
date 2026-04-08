import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const String farmaciaLogoSvg = '''
<svg width="256" height="256" viewBox="0 0 256 256" fill="none" xmlns="http://www.w3.org/2000/svg">
  <rect x="40" y="18" width="176" height="220" rx="64" fill="#E8F2FB"/>
  <path d="M128 24L202 60V132C202 177 171 216 128 228C85 216 54 177 54 132V60L128 24Z" fill="#1976D2"/>
  <rect x="116" y="74" width="24" height="96" rx="6" fill="#FFFFFF"/>
  <rect x="92" y="98" width="72" height="24" rx="6" fill="#FFFFFF"/>
  <path d="M86 184C86 173 95 164 106 164H150C161 164 170 173 170 184C170 195 161 204 150 204H106C95 204 86 195 86 184Z" fill="#2E7D32"/>
  <circle cx="103" cy="184" r="7" fill="#FFFFFF" fill-opacity="0.85"/>
  <circle cx="127" cy="184" r="7" fill="#FFFFFF" fill-opacity="0.85"/>
  <circle cx="151" cy="184" r="7" fill="#FFFFFF" fill-opacity="0.85"/>
</svg>
''';

class FarmaciaLogo extends StatelessWidget {
  final double width;
  final double height;

  const FarmaciaLogo({super.key, this.width = 34, this.height = 34});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.string(
      farmaciaLogoSvg,
      width: width,
      height: height,
      fit: BoxFit.contain,
      semanticsLabel: 'Farmacia POS AWOS',
    );
  }
}
