import 'package:flutter/material.dart';
import '../brand.dart';

/// The "qontract" wordmark, recreated as scalable slab-serif text
/// (app#23) instead of the legacy PNG logos.
///
/// Two background-aware variants, matching the legacy brand:
///  * light backgrounds: blue "q" + ink "ontract"
///  * dark backgrounds: sky-blue "q" + white "ontract"
///
/// The variant is chosen from [Theme.of].brightness by default; pass
/// [backgroundIsDark] to override (e.g. on a fixed-color surface).
class QontractWordmark extends StatelessWidget {
  const QontractWordmark({
    super.key,
    this.size,
    this.backgroundIsDark,
    this.textAlign = TextAlign.start,
  });

  /// Font size of the wordmark. Defaults to `headlineLarge`.
  final double? size;

  /// Force a specific variant instead of using the theme brightness.
  final bool? backgroundIsDark;

  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final dark =
        backgroundIsDark ?? Theme.of(context).brightness == Brightness.dark;
    final qColor = dark ? QontractBrand.sky : QontractBrand.blue;
    final restColor = dark ? Colors.white : QontractBrand.ink;
    final fontSize =
        size ?? Theme.of(context).textTheme.headlineLarge?.fontSize ?? 30;

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'q',
            style: TextStyle(color: qColor),
          ),
          TextSpan(
            text: 'ontract',
            style: TextStyle(color: restColor),
          ),
        ],
      ),
      textAlign: textAlign,
      style: TextStyle(
        fontFamily: 'RobotoSlab',
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
