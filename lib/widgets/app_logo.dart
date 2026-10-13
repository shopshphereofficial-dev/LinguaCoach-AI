import 'package:flutter/material.dart';

/// The LinguaCoach AI logo mark, drawn in code so it stays crisp at any size.
///
/// A green rounded square with a white speech bubble holding a graduation cap —
/// the same mark used for the Android launcher icon.
class AppLogo extends StatelessWidget {
  final double size;
  final bool showShadow;

  const AppLogo({super.key, this.size = 96, this.showShadow = false});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LogoPainter(showShadow: showShadow),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  final bool showShadow;

  _LogoPainter({required this.showShadow});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final rect = Offset.zero & size;
    final radius = Radius.circular(s * 0.22);

    if (showShadow) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.shift(Offset(0, s * 0.04)), radius),
        Paint()
          ..color = const Color(0xFF3A8A02).withOpacity(0.35)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.05),
      );
    }

    // background gradient
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, radius),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF7ED957), Color(0xFF58CC02)],
        ).createShader(rect),
    );

    // speech bubble
    final bubble = RRect.fromRectAndRadius(
      Rect.fromLTWH(s * 0.19, s * 0.22, s * 0.62, s * 0.48),
      Radius.circular(s * 0.15),
    );
    final white = Paint()..color = Colors.white;
    canvas.drawRRect(bubble, white);

    // bubble tail
    canvas.drawPath(
      Path()
        ..moveTo(s * 0.34, s * 0.66)
        ..lineTo(s * 0.46, s * 0.66)
        ..lineTo(s * 0.31, s * 0.86)
        ..close(),
      white,
    );

    // graduation cap: base then top diamond
    final capLeft = s * 0.31;
    final capRight = s * 0.69;
    final capMid = (capLeft + capRight) / 2;
    final capTop = s * 0.34;
    final capBottom = s * 0.50;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(
          capLeft + (capRight - capLeft) * 0.20,
          s * 0.42,
          capRight - (capRight - capLeft) * 0.20,
          capBottom + s * 0.03,
        ),
        Radius.circular(s * 0.025),
      ),
      Paint()..color = const Color(0xFF2E8C0A),
    );

    canvas.drawPath(
      Path()
        ..moveTo(capMid, capTop)
        ..lineTo(capRight, capTop + s * 0.075)
        ..lineTo(capMid, capTop + s * 0.15)
        ..lineTo(capLeft, capTop + s * 0.075)
        ..close(),
      Paint()..color = const Color(0xFF3FA806),
    );

    // tassel
    canvas.drawLine(
      Offset(capRight - s * 0.03, capTop + s * 0.075),
      Offset(capRight - s * 0.05, capTop + s * 0.16),
      Paint()
        ..color = const Color(0xFFFFC800)
        ..strokeWidth = s * 0.022
        ..strokeCap = StrokeCap.round,
    );

    // sparkle
    final sparkleCenter = Offset(s * 0.76, s * 0.26);
    final sparkle = Paint()..color = const Color(0xFFFFE45C);
    canvas.drawPath(
      Path()
        ..moveTo(sparkleCenter.dx, sparkleCenter.dy - s * 0.07)
        ..quadraticBezierTo(sparkleCenter.dx, sparkleCenter.dy,
            sparkleCenter.dx + s * 0.07, sparkleCenter.dy)
        ..quadraticBezierTo(sparkleCenter.dx, sparkleCenter.dy,
            sparkleCenter.dx, sparkleCenter.dy + s * 0.07)
        ..quadraticBezierTo(sparkleCenter.dx, sparkleCenter.dy,
            sparkleCenter.dx - s * 0.07, sparkleCenter.dy)
        ..quadraticBezierTo(sparkleCenter.dx, sparkleCenter.dy,
            sparkleCenter.dx, sparkleCenter.dy - s * 0.07)
        ..close(),
      sparkle,
    );
  }

  @override
  bool shouldRepaint(covariant _LogoPainter old) =>
      old.showShadow != showShadow;
}
