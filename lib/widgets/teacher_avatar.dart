import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/teacher.dart';

/// An animated, hand-drawn avatar of a teacher.
///
/// Everything is painted in code, so it scales to any size and needs no image
/// assets. It reacts to the live audio:
///
/// * **Lip sync** — [level] is the loudness of the teacher's voice (0..1) and
///   drives how far the mouth opens.
/// * **Blinking** — random natural blinks, occasionally a double blink.
/// * **Hair / idle motion** — the head bobs and tilts gently and the hair
///   sways, so the teacher never looks frozen.
class TeacherAvatar extends StatefulWidget {
  final Teacher teacher;

  /// Live loudness of the teacher's voice, 0..1.
  final ValueListenable<double> level;

  final bool speaking;
  final bool listening;
  final double size;

  const TeacherAvatar({
    super.key,
    required this.teacher,
    required this.level,
    this.speaking = false,
    this.listening = false,
    this.size = 240,
  });

  @override
  State<TeacherAvatar> createState() => _TeacherAvatarState();
}

class _TeacherAvatarState extends State<TeacherAvatar>
    with TickerProviderStateMixin {
  late final AnimationController _idle;
  late final AnimationController _blink;
  late final Ticker _mouthTicker;

  Timer? _blinkTimer;
  double _mouthTarget = 0;
  final ValueNotifier<double> _mouth = ValueNotifier<double>(0);

  @override
  void initState() {
    super.initState();
    _idle = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();

    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 95),
    );

    widget.level.addListener(_onLevel);
    _mouthTicker = createTicker(_onMouthTick)..start();
    _scheduleBlink();
  }

  @override
  void didUpdateWidget(covariant TeacherAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.level != widget.level) {
      oldWidget.level.removeListener(_onLevel);
      widget.level.addListener(_onLevel);
    }
  }

  @override
  void dispose() {
    widget.level.removeListener(_onLevel);
    _mouthTicker.dispose();
    _blinkTimer?.cancel();
    _idle.dispose();
    _blink.dispose();
    _mouth.dispose();
    super.dispose();
  }

  void _onLevel() => _mouthTarget = widget.level.value;

  /// Smooths the mouth: opens towards the target, and relaxes when silent.
  void _onMouthTick(Duration _) {
    final current = _mouth.value;
    var next = current + (_mouthTarget - current) * 0.5;
    if (!widget.speaking) next *= 0.86;
    next = next.clamp(0.0, 1.0);
    if ((next - current).abs() > 0.0015) _mouth.value = next;
  }

  void _scheduleBlink() {
    final wait = 1800 + (DateTime.now().millisecondsSinceEpoch % 2600);
    _blinkTimer = Timer(Duration(milliseconds: wait), () async {
      if (!mounted) return;
      await _blink.forward();
      await _blink.reverse();
      // Every so often, a natural double blink.
      if (mounted && DateTime.now().millisecondsSinceEpoch % 3 == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 130));
        if (!mounted) return;
        await _blink.forward();
        await _blink.reverse();
      }
      if (mounted) _scheduleBlink();
    });
  }

  @override
  Widget build(BuildContext context) {
    final repaint = Listenable.merge([_idle, _blink, _mouth]);
    return SizedBox(
      width: widget.size,
      height: widget.size * 1.18,
      child: CustomPaint(
        painter: _AvatarPainter(
          teacher: widget.teacher,
          idle: _idle,
          blink: _blink,
          mouth: _mouth,
          speaking: widget.speaking,
          listening: widget.listening,
          repaint: repaint,
        ),
      ),
    );
  }
}

class _AvatarPainter extends CustomPainter {
  final Teacher teacher;
  final Animation<double> idle;
  final Animation<double> blink;
  final ValueNotifier<double> mouth;
  final bool speaking;
  final bool listening;

  _AvatarPainter({
    required this.teacher,
    required this.idle,
    required this.blink,
    required this.mouth,
    required this.speaking,
    required this.listening,
    required Listenable repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final t = idle.value;
    final phase = t * 2 * math.pi;

    final bob = math.sin(phase) * h * 0.009;
    final tilt = math.sin(phase + 0.7) * 0.035;
    final sway = math.sin(phase * 1.5) * w * 0.012;

    // ---- soft glow behind the teacher when they speak ----
    if (speaking) {
      final glow = Paint()
        ..shader = RadialGradient(
          colors: [
            teacher.accent.withOpacity(0.28),
            teacher.accent.withOpacity(0.0),
          ],
        ).createShader(Rect.fromCircle(
          center: Offset(w * 0.5, h * 0.42),
          radius: w * 0.52,
        ));
      canvas.drawCircle(Offset(w * 0.5, h * 0.42), w * 0.52, glow);
    }

    _drawTorso(canvas, w, h, bob);

    canvas.save();
    canvas.translate(w * 0.5, h * 0.44 + bob);
    canvas.rotate(tilt);

    final r = w * 0.27;
    _drawHairBack(canvas, r, sway);
    _drawNeck(canvas, r);
    _drawHead(canvas, r);
    _drawHairFront(canvas, r, sway);
    _drawFace(canvas, r);

    canvas.restore();
  }

  // ------------------------------------------------------------------ torso

  void _drawTorso(Canvas canvas, double w, double h, double bob) {
    final top = h * 0.70 + bob;
    final path = Path()
      ..moveTo(w * 0.04, h)
      ..quadraticBezierTo(w * 0.09, top, w * 0.33, top - h * 0.015)
      ..lineTo(w * 0.67, top - h * 0.015)
      ..quadraticBezierTo(w * 0.91, top, w * 0.96, h)
      ..close();
    canvas.drawPath(path, Paint()..color = teacher.outfit);

    // collar
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.41, top - h * 0.02)
        ..lineTo(w * 0.50, top + h * 0.055)
        ..lineTo(w * 0.59, top - h * 0.02)
        ..close(),
      Paint()..color = _lighten(teacher.outfit, 0.3),
    );
  }

  // ------------------------------------------------------------------- head

  void _drawNeck(Canvas canvas, double r) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(0, r * 0.92),
          width: r * 0.60,
          height: r * 0.80,
        ),
        Radius.circular(r * 0.22),
      ),
      Paint()..color = _darken(teacher.skin, 0.14),
    );
  }

  void _drawHead(Canvas canvas, double r) {
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: r * 1.80, height: r * 2.06),
      Paint()..color = teacher.skin,
    );
    // ears
    final ear = Paint()..color = _darken(teacher.skin, 0.06);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-r * 0.90, r * 0.12),
        width: r * 0.26,
        height: r * 0.44),
      ear,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(r * 0.90, r * 0.12),
        width: r * 0.26,
        height: r * 0.44),
      ear,
    );
  }

  void _drawHairBack(Canvas canvas, double r, double sway) {
    final paint = Paint()..color = teacher.hair;
    canvas.save();
    canvas.translate(sway, 0);
    switch (teacher.hairStyle) {
      case HairStyle.long:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(0, r * 0.30),
              width: r * 2.34,
              height: r * 3.00),
            Radius.circular(r * 1.05),
          ),
          paint,
        );
        break;
      case HairStyle.bob:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: Offset(0, r * 0.02),
              width: r * 2.20,
              height: r * 2.30),
            Radius.circular(r * 0.98),
          ),
          paint,
        );
        break;
      case HairStyle.curly:
        for (var i = 0; i <= 10; i++) {
          final a = math.pi * (0.92 + 1.16 * (i / 10));
          canvas.drawCircle(
            Offset(math.cos(a) * r * 0.98, math.sin(a) * r * 0.98 - r * 0.06),
            r * 0.44,
            paint,
          );
        }
        canvas.drawCircle(Offset(-r * 1.05, r * 0.35), r * 0.40, paint);
        canvas.drawCircle(Offset(r * 1.05, r * 0.35), r * 0.40, paint);
        break;
      default:
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(0, -r * 0.08),
            width: r * 1.98,
            height: r * 2.02),
          paint,
        );
    }
    canvas.restore();
  }

  void _drawHairFront(Canvas canvas, double r, double sway) {
    final paint = Paint()..color = teacher.hair;
    canvas.save();
    canvas.translate(sway * 0.5, 0);
    switch (teacher.hairStyle) {
      case HairStyle.long:
      case HairStyle.bob:
        canvas.drawPath(
          Path()
            ..moveTo(-r * 0.94, -r * 0.28)
            ..quadraticBezierTo(-r * 0.78, -r * 1.14, 0, -r * 1.04)
            ..quadraticBezierTo(r * 0.78, -r * 1.14, r * 0.94, -r * 0.28)
            ..quadraticBezierTo(r * 0.58, -r * 0.70, r * 0.22, -r * 0.72)
            ..quadraticBezierTo(0, -r * 0.86, -r * 0.22, -r * 0.72)
            ..quadraticBezierTo(-r * 0.58, -r * 0.70, -r * 0.94, -r * 0.28)
            ..close(),
          paint,
        );
        break;
      case HairStyle.short:
        canvas.drawPath(
          Path()
            ..moveTo(-r * 0.96, -r * 0.22)
            ..quadraticBezierTo(-r * 0.72, -r * 1.18, 0, -r * 1.06)
            ..quadraticBezierTo(r * 0.72, -r * 1.18, r * 0.96, -r * 0.22)
            ..quadraticBezierTo(r * 0.62, -r * 0.52, r * 0.30, -r * 0.44)
            ..quadraticBezierTo(0, -r * 0.66, -r * 0.30, -r * 0.44)
            ..quadraticBezierTo(-r * 0.62, -r * 0.52, -r * 0.96, -r * 0.22)
            ..close(),
          paint,
        );
        break;
      case HairStyle.bun:
        canvas.drawCircle(Offset(0, -r * 1.16), r * 0.34, paint);
        canvas.drawPath(
          Path()
            ..moveTo(-r * 0.94, -r * 0.20)
            ..quadraticBezierTo(-r * 0.74, -r * 1.20, 0, -r * 1.08)
            ..quadraticBezierTo(r * 0.74, -r * 1.20, r * 0.94, -r * 0.20)
            ..quadraticBezierTo(r * 0.46, -r * 0.58, 0, -r * 0.64)
            ..quadraticBezierTo(-r * 0.46, -r * 0.58, -r * 0.94, -r * 0.20)
            ..close(),
          paint,
        );
        break;
      case HairStyle.curly:
        for (var i = 0; i <= 7; i++) {
          final x = -r * 0.88 + (i / 7) * r * 1.76;
          canvas.drawCircle(
            Offset(x, -r * 0.80 + math.sin(i * 1.7) * r * 0.07),
            r * 0.31,
            paint,
          );
        }
        break;
    }
    canvas.restore();
  }

  // ------------------------------------------------------------------- face

  void _drawFace(Canvas canvas, double r) {
    final eyeY = -r * 0.14;
    final eyeDx = r * 0.42;
    final eyeW = r * 0.34;
    final eyeH = r * 0.36;
    final closure = blink.value;

    // eyebrows
    final browLift = speaking ? -r * 0.06 : (listening ? r * 0.02 : 0.0);
    final browPaint = Paint()
      ..color = teacher.hair
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.085
      ..strokeCap = StrokeCap.round;
    for (final dx in [-eyeDx, eyeDx]) {
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(dx, eyeY - eyeH * 0.86 + browLift),
          width: eyeW * 1.20,
          height: eyeH * 0.55,
        ),
        math.pi * 1.12,
        math.pi * 0.76,
        false,
        browPaint,
      );
    }

    // eyes
    for (final dx in [-eyeDx, eyeDx]) {
      final center = Offset(dx, eyeY);
      final eyeRect =
          Rect.fromCenter(center: center, width: eyeW, height: eyeH);
      canvas.drawOval(eyeRect, Paint()..color = Colors.white);
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: eyeW * 0.66,
          height: eyeH * 0.66,
        ),
        Paint()..color = teacher.accent,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: eyeW * 0.30,
          height: eyeH * 0.30,
        ),
        Paint()..color = const Color(0xFF20140E),
      );
      canvas.drawCircle(
        center.translate(-eyeW * 0.15, -eyeH * 0.16),
        eyeW * 0.08,
        Paint()..color = Colors.white,
      );

      // eyelid for blinking, clipped to the eye so it looks natural
      if (closure > 0.01) {
        canvas.save();
        canvas.clipPath(Path()..addOval(eyeRect));
        canvas.drawRect(
          Rect.fromLTRB(
            eyeRect.left - 1,
            eyeRect.top - 1,
            eyeRect.right + 1,
            eyeRect.top + eyeRect.height * closure + 1,
          ),
          Paint()..color = teacher.skin,
        );
        canvas.restore();
      }
    }

    // nose
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(0, r * 0.24),
        width: r * 0.20,
        height: r * 0.20,
      ),
      math.pi * 0.15,
      math.pi * 0.7,
      false,
      Paint()
        ..color = _darken(teacher.skin, 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.055
        ..strokeCap = StrokeCap.round,
    );

    _drawMouth(canvas, r);

    // blush when talking
    if (speaking && mouth.value > 0.15) {
      final blush = Paint()
        ..color = const Color(0xFFFF8A8A)
            .withOpacity(0.20 + mouth.value * 0.20);
      for (final dx in [-r * 0.70, r * 0.70]) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(dx, r * 0.36),
            width: r * 0.42,
            height: r * 0.24),
          blush,
        );
      }
    }
  }

  void _drawMouth(Canvas canvas, double r) {
    final open = mouth.value.clamp(0.0, 1.0);
    final center = Offset(0, r * 0.62);

    if (open < 0.06) {
      // relaxed smile
      canvas.drawArc(
        Rect.fromCenter(center: center, width: r * 0.62, height: r * 0.40),
        math.pi * 0.12,
        math.pi * 0.76,
        false,
        Paint()
          ..color = const Color(0xFF8C3B3B)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.075
          ..strokeCap = StrokeCap.round,
      );
      return;
    }

    final mouthW = r * (0.66 - open * 0.10);
    final mouthH = r * (0.10 + open * 0.46);
    final rect = Rect.fromCenter(center: center, width: mouthW, height: mouthH);

    canvas.drawOval(rect, Paint()..color = const Color(0xFF7A2E33));
    canvas.drawOval(
      rect.deflate(r * 0.035),
      Paint()..color = const Color(0xFF43151B),
    );
    // upper teeth
    if (open > 0.20) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(0, rect.top + r * 0.055),
            width: rect.width * 0.78,
            height: r * 0.085,
          ),
          Radius.circular(r * 0.03),
        ),
        Paint()..color = Colors.white,
      );
    }
    // tongue hint for wide-open shapes
    if (open > 0.55) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, rect.bottom - r * 0.10),
          width: rect.width * 0.52,
          height: r * 0.12,
        ),
        Paint()..color = const Color(0xFFC96A72),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AvatarPainter old) =>
      old.teacher.id != teacher.id ||
      old.speaking != speaking ||
      old.listening != listening;

  Color _darken(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }

  Color _lighten(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }
}
