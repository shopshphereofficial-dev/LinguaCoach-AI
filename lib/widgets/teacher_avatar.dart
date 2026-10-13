import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/teacher.dart';

/// An animated, hand-drawn avatar of a teacher — face, body, lip sync, blinking
/// and hair motion, all painted in code (no image assets).
///
/// * **Lip sync** — [level] is the loudness of the teacher's voice (0..1) and
///   drives how far the mouth opens.
/// * **Blinking** — random natural blinks, occasionally a double blink.
/// * **Idle motion** — the head bobs and tilts, the hair sways and the figure
///   breathes, so the teacher never looks frozen.
///
/// Set [animate] to false for a cheap, static pose — used in lists and pickers
/// so scrolling stays smooth.
class TeacherAvatar extends StatefulWidget {
  final Teacher teacher;

  /// Live loudness of the teacher's voice, 0..1. Only used when [animate].
  final ValueListenable<double>? level;

  final bool speaking;
  final bool listening;
  final bool animate;
  final double size;

  const TeacherAvatar({
    super.key,
    required this.teacher,
    this.level,
    this.speaking = false,
    this.listening = false,
    this.animate = true,
    this.size = 240,
  });

  @override
  State<TeacherAvatar> createState() => _TeacherAvatarState();
}

class _TeacherAvatarState extends State<TeacherAvatar>
    with TickerProviderStateMixin {
  AnimationController? _idle;
  AnimationController? _blink;
  Ticker? _mouthTicker;
  Timer? _blinkTimer;
  double _mouthTarget = 0;
  final ValueNotifier<double> _mouth = ValueNotifier<double>(0);

  static const Animation<double> _still = AlwaysStoppedAnimation<double>(0.35);

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _idle = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 5),
      )..repeat();
      _blink = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 95),
      );
      _mouthTicker = createTicker(_onMouthTick)..start();
      _scheduleBlink();
    }
    widget.level?.addListener(_onLevel);
  }

  @override
  void didUpdateWidget(covariant TeacherAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.level != widget.level) {
      oldWidget.level?.removeListener(_onLevel);
      widget.level?.addListener(_onLevel);
    }
  }

  @override
  void dispose() {
    widget.level?.removeListener(_onLevel);
    _mouthTicker?.dispose();
    _blinkTimer?.cancel();
    _idle?.dispose();
    _blink?.dispose();
    _mouth.dispose();
    super.dispose();
  }

  void _onLevel() => _mouthTarget = widget.level?.value ?? 0;

  /// Opens towards the target loudness and relaxes when silent.
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
      final blink = _blink;
      if (!mounted || blink == null) return;
      await blink.forward();
      await blink.reverse();
      if (mounted && DateTime.now().millisecondsSinceEpoch % 3 == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 130));
        if (!mounted) return;
        await blink.forward();
        await blink.reverse();
      }
      if (mounted) _scheduleBlink();
    });
  }

  @override
  Widget build(BuildContext context) {
    final idle = widget.animate ? _idle! : _still;
    final blink = widget.animate ? _blink! : const AlwaysStoppedAnimation(0.0);

    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size * 1.238,
        child: CustomPaint(
          painter: _AvatarPainter(
            teacher: widget.teacher,
            idle: idle,
            blink: blink,
            mouth: _mouth,
            speaking: widget.speaking,
            listening: widget.listening,
            animate: widget.animate,
            repaint: Listenable.merge([idle, blink, _mouth]),
          ),
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
  final bool animate;

  _AvatarPainter({
    required this.teacher,
    required this.idle,
    required this.blink,
    required this.mouth,
    required this.speaking,
    required this.listening,
    required this.animate,
    required Listenable repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = w * 0.26;
    final phase = idle.value * 2 * math.pi;

    final bob = animate ? math.sin(phase) * h * 0.008 : 0.0;
    final tilt = animate ? math.sin(phase + 0.7) * 0.035 : 0.0;
    final sway = animate ? math.sin(phase * 1.5) * w * 0.012 : 0.0;

    final cx = w * 0.5;
    final cy = h * 0.42 + bob;

    // ---- glow while speaking ----
    if (speaking) {
      canvas.drawCircle(
        Offset(cx, cy),
        w * 0.55,
        Paint()
          ..shader = RadialGradient(
            colors: [
              teacher.accent.withOpacity(0.26),
              teacher.accent.withOpacity(0.0),
            ],
          ).createShader(
              Rect.fromCircle(center: Offset(cx, cy), radius: w * 0.55)),
      );
    }

    _drawBody(canvas, w, h, r, cx, cy);

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(tilt);

    _drawHairBack(canvas, r, sway);
    _drawNeck(canvas, r);
    _drawHead(canvas, r);
    _drawHairFront(canvas, r, sway);
    _drawFace(canvas, r);

    canvas.restore();
  }

  // ------------------------------------------------------------------- body

  void _drawBody(Canvas canvas, double w, double h, double r, double cx, double cy) {
    final top = cy + r * 1.30;

    canvas.drawPath(
      Path()
        ..moveTo(w * 0.02, h)
        ..quadraticBezierTo(w * 0.06, top, w * 0.30, top - h * 0.008)
        ..lineTo(w * 0.70, top - h * 0.008)
        ..quadraticBezierTo(w * 0.94, top, w * 0.98, h)
        ..close(),
      Paint()..color = teacher.outfit,
    );

    // arms
    final armPaint = Paint()..color = _darken(teacher.outfit, 0.07);
    for (final sx in [0.06, 0.94]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            w * sx - w * 0.052,
            top + h * 0.05,
            w * 0.104,
            h * 0.26,
          ),
          Radius.circular(w * 0.052),
        ),
        armPaint,
      );
    }

    // collar
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.42, top + h * 0.004)
        ..lineTo(w * 0.50, top + h * 0.055)
        ..lineTo(w * 0.58, top + h * 0.004)
        ..close(),
      Paint()..color = _lighten(teacher.outfit, 0.30),
    );
  }

  // ------------------------------------------------------------------- head

  void _drawNeck(Canvas canvas, double r) {
    // Reaches below the head so it is actually visible above the shoulders.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-0.39 * r, 0.72 * r, 0.78 * r, 0.76 * r),
        Radius.circular(0.30 * r),
      ),
      Paint()..color = _darken(teacher.skin, 0.10),
    );
  }

  void _drawHead(Canvas canvas, double r) {
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: 1.70 * r, height: 2.00 * r),
      Paint()..color = teacher.skin,
    );
    final ear = Paint()..color = _darken(teacher.skin, 0.06);
    for (final sx in [-0.85, 0.85]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(sx * r, 0.14 * r),
          width: 0.24 * r,
          height: 0.40 * r,
        ),
        ear,
      );
    }
  }

  void _drawHairBack(Canvas canvas, double r, double sway) {
    final paint = Paint()..color = teacher.hair;
    canvas.save();
    canvas.translate(sway, 0);
    switch (teacher.hairStyle) {
      case HairStyle.long:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(-1.14 * r, -1.10 * r, 2.28 * r, 2.72 * r),
            Radius.circular(r),
          ),
          paint,
        );
        break;
      case HairStyle.bob:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(-1.08 * r, -1.04 * r, 2.16 * r, 2.06 * r),
            Radius.circular(r),
          ),
          paint,
        );
        break;
      case HairStyle.curly:
        for (var i = 0; i <= 10; i++) {
          final a = math.pi * (0.90 + 1.20 * (i / 10));
          canvas.drawCircle(
            Offset(math.cos(a) * 0.96 * r, math.sin(a) * 0.96 * r - 0.02 * r),
            0.42 * r,
            paint,
          );
        }
        break;
      default:
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(0, -0.06 * r),
            width: 1.94 * r,
            height: 1.98 * r,
          ),
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
            ..moveTo(-0.85 * r, -0.30 * r)
            ..quadraticBezierTo(-0.80 * r, -1.20 * r, 0, -1.10 * r)
            ..quadraticBezierTo(0.80 * r, -1.20 * r, 0.85 * r, -0.30 * r)
            ..quadraticBezierTo(0.62 * r, -0.86 * r, 0.24 * r, -0.80 * r)
            ..quadraticBezierTo(0, -0.90 * r, -0.24 * r, -0.80 * r)
            ..quadraticBezierTo(-0.62 * r, -0.86 * r, -0.85 * r, -0.30 * r)
            ..close(),
          paint,
        );
        break;
      case HairStyle.short:
        canvas.drawPath(
          Path()
            ..moveTo(-0.88 * r, -0.24 * r)
            ..quadraticBezierTo(-0.78 * r, -1.24 * r, 0, -1.12 * r)
            ..quadraticBezierTo(0.78 * r, -1.24 * r, 0.88 * r, -0.24 * r)
            ..quadraticBezierTo(0.66 * r, -0.70 * r, 0.30 * r, -0.66 * r)
            ..quadraticBezierTo(0, -0.78 * r, -0.30 * r, -0.66 * r)
            ..quadraticBezierTo(-0.66 * r, -0.70 * r, -0.88 * r, -0.24 * r)
            ..close(),
          paint,
        );
        break;
      case HairStyle.bun:
        canvas.drawCircle(Offset(0, -1.20 * r), 0.32 * r, paint);
        canvas.drawPath(
          Path()
            ..moveTo(-0.86 * r, -0.26 * r)
            ..quadraticBezierTo(-0.80 * r, -1.22 * r, 0, -1.12 * r)
            ..quadraticBezierTo(0.80 * r, -1.22 * r, 0.86 * r, -0.26 * r)
            ..quadraticBezierTo(0.50 * r, -0.78 * r, 0, -0.74 * r)
            ..quadraticBezierTo(-0.50 * r, -0.78 * r, -0.86 * r, -0.26 * r)
            ..close(),
          paint,
        );
        break;
      case HairStyle.curly:
        for (var i = 0; i <= 8; i++) {
          final x = -0.84 * r + (i / 8) * 1.68 * r;
          canvas.drawCircle(
            Offset(x, -0.80 * r + math.sin(i * 1.7) * 0.05 * r),
            0.28 * r,
            paint,
          );
        }
        break;
    }
    canvas.restore();
  }

  // ------------------------------------------------------------------- face

  void _drawFace(Canvas canvas, double r) {
    const eyeY = -0.20;
    const eyeDx = 0.40;
    const eyeW = 0.34;
    const eyeH = 0.36;
    final closure = blink.value;

    // eyebrows — thin and well above the eyes
    final browPaint = Paint()
      ..color = _lighten(teacher.hair, 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.05 * r
      ..strokeCap = StrokeCap.round;
    for (final dx in [-eyeDx, eyeDx]) {
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(dx * r, (eyeY - eyeH * 1.35) * r),
          width: 0.60 * eyeW * r * 2,
          height: 0.26 * eyeH * r * 2,
        ),
        math.pi * 1.10,
        math.pi * 0.80,
        false,
        browPaint,
      );
    }

    for (final dx in [-eyeDx, eyeDx]) {
      final center = Offset(dx * r, eyeY * r);
      final eyeRect = Rect.fromCenter(
        center: center,
        width: eyeW * r,
        height: eyeH * r,
      );
      canvas.drawOval(eyeRect, Paint()..color = Colors.white);
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: eyeW * 0.76 * r,
          height: eyeH * 0.76 * r,
        ),
        Paint()..color = teacher.accent,
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: center,
          width: eyeW * 0.42 * r,
          height: eyeH * 0.42 * r,
        ),
        Paint()..color = const Color(0xFF241812),
      );
      canvas.drawCircle(
        center.translate(-eyeW * 0.12 * r, -eyeH * 0.13 * r),
        eyeW * 0.11 * r,
        Paint()..color = Colors.white,
      );

      // soft upper lid
      canvas.drawArc(
        eyeRect,
        math.pi * 1.11,
        math.pi * 0.78,
        false,
        Paint()
          ..color = _lighten(teacher.hair, 0.20)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.035 * r
          ..strokeCap = StrokeCap.round,
      );

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
        canvas.drawArc(
          Rect.fromCenter(
            center: center.translate(0, eyeH * 0.5 * r - eyeH * closure * r),
            width: eyeW * r,
            height: eyeH * 0.32 * r,
          ),
          math.pi * 1.08,
          math.pi * 0.84,
          false,
          Paint()
            ..color = teacher.hair
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.045 * r
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    // nose
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(0, 0.16 * r),
        width: 0.20 * r,
        height: 0.20 * r,
      ),
      math.pi * 0.11,
      math.pi * 0.78,
      false,
      Paint()
        ..color = _darken(teacher.skin, 0.24)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.045 * r
        ..strokeCap = StrokeCap.round,
    );

    _drawMouth(canvas, r);

    if (speaking && mouth.value > 0.15) {
      final blush = Paint()
        ..color = const Color(0xFFFF8080)
            .withOpacity(0.16 + mouth.value * 0.18);
      for (final dx in [-0.70, 0.70]) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(dx * r, 0.30 * r),
            width: 0.36 * r,
            height: 0.20 * r,
          ),
          blush,
        );
      }
    }
  }

  void _drawMouth(Canvas canvas, double r) {
    final open = mouth.value.clamp(0.0, 1.0);
    final center = Offset(0, 0.48 * r);

    if (open < 0.06) {
      canvas.drawArc(
        Rect.fromCenter(
          center: center,
          width: 0.60 * r,
          height: 0.40 * r,
        ),
        math.pi * 0.11,
        math.pi * 0.78,
        false,
        Paint()
          ..color = const Color(0xFFA04A4A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.065 * r
          ..strokeCap = StrokeCap.round,
      );
      return;
    }

    final mw = 0.60 * r - open * 0.10 * r;
    final mh = 0.09 * r + open * 0.42 * r;
    final rect = Rect.fromCenter(center: center, width: mw, height: mh);

    canvas.drawOval(rect, Paint()..color = const Color(0xFF7A2E33));
    canvas.drawOval(
      rect.deflate(0.035 * r),
      Paint()..color = const Color(0xFF43151B),
    );
    if (open > 0.20) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            -mw * 0.39,
            center.dy - mh / 2 + 0.015 * r,
            mw * 0.78,
            0.08 * r,
          ),
          Radius.circular(0.03 * r),
        ),
        Paint()..color = Colors.white,
      );
    }
    if (open > 0.55) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, center.dy + mh / 2 - 0.09 * r),
          width: mw * 0.52,
          height: 0.11 * r,
        ),
        Paint()..color = const Color(0xFFC96A72),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AvatarPainter old) =>
      old.teacher.id != teacher.id ||
      old.speaking != speaking ||
      old.listening != listening ||
      old.animate != animate;

  Color _darken(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }

  Color _lighten(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
  }
}
