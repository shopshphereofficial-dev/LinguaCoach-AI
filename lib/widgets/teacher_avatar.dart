import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/teacher.dart';

/// A hand-drawn, animated avatar of a teacher — face, body, lip sync, blinking,
/// hair motion and breathing, all painted in code (no image assets).
///
/// Animation details:
/// * **Lip sync** — [level] (0..1 voice loudness) drives the mouth opening, and
///   the chin drops with it so the whole jaw moves, not just the lips.
/// * **Head** — nods slightly on loud syllables and tilts while listening.
/// * **Hair** — follows the head with a phase lag, so it trails rather than
///   sticking to the skull.
/// * **Eyes** — random natural blinks, occasional double blinks, and small
///   gaze shifts so the teacher does not stare.
/// * **Body** — gentle breathing and a shoulder bob while speaking.
///
/// Set [animate] to false for a cheap static pose (used in lists and pickers).
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
  Timer? _gazeTimer;

  double _mouthTarget = 0;
  final ValueNotifier<double> _mouth = ValueNotifier<double>(0);
  final ValueNotifier<double> _gaze = ValueNotifier<double>(0);

  static const Animation<double> _still = AlwaysStoppedAnimation<double>(0.35);

  @override
  void initState() {
    super.initState();
    if (widget.animate) {
      _idle = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 6),
      )..repeat();
      _blink = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 90),
      );
      _mouthTicker = createTicker(_onMouthTick)..start();
      _scheduleBlink();
      _scheduleGaze();
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
    _gazeTimer?.cancel();
    _idle?.dispose();
    _blink?.dispose();
    _mouth.dispose();
    _gaze.dispose();
    super.dispose();
  }

  void _onLevel() => _mouthTarget = widget.level?.value ?? 0;

  /// Opens quickly towards the voice level, and relaxes when silent — which is
  /// what makes the mouth feel like speech rather than a volume meter.
  void _onMouthTick(Duration _) {
    final current = _mouth.value;
    final attack = _mouthTarget > current ? 0.55 : 0.30;
    var next = current + (_mouthTarget - current) * attack;
    if (!widget.speaking) next *= 0.88;
    next = next.clamp(0.0, 1.0);
    if ((next - current).abs() > 0.0012) _mouth.value = next;
  }

  void _scheduleBlink() {
    final wait = 1700 + (DateTime.now().millisecondsSinceEpoch % 2900);
    _blinkTimer = Timer(Duration(milliseconds: wait), () async {
      final blink = _blink;
      if (!mounted || blink == null) return;
      await blink.forward();
      await blink.reverse();
      if (mounted && DateTime.now().millisecondsSinceEpoch % 3 == 0) {
        await Future<void>.delayed(const Duration(milliseconds: 120));
        if (!mounted) return;
        await blink.forward();
        await blink.reverse();
      }
      if (mounted) _scheduleBlink();
    });
  }

  /// Small, random gaze shifts so the teacher does not stare straight ahead.
  void _scheduleGaze() {
    _gazeTimer = Timer(
      Duration(milliseconds: 1400 + (DateTime.now().microsecondsSinceEpoch % 2400)),
      () {
        if (!mounted) return;
        final seed = DateTime.now().microsecondsSinceEpoch;
        _gaze.value = ((seed % 200) - 100) / 100.0 * 0.8;
        _scheduleGaze();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final idle = widget.animate ? _idle! : _still;
    final blink = widget.animate ? _blink! : const AlwaysStoppedAnimation(0.0);

    return RepaintBoundary(
      child: SizedBox(
        width: widget.size,
        height: widget.size * 1.24,
        child: CustomPaint(
          painter: _AvatarPainter(
            teacher: widget.teacher,
            idle: idle,
            blink: blink,
            mouth: _mouth,
            gaze: _gaze,
            speaking: widget.speaking,
            listening: widget.listening,
            animate: widget.animate,
            repaint: Listenable.merge([idle, blink, _mouth, _gaze]),
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
  final ValueNotifier<double> gaze;
  final bool speaking;
  final bool listening;
  final bool animate;

  _AvatarPainter({
    required this.teacher,
    required this.idle,
    required this.blink,
    required this.mouth,
    required this.gaze,
    required this.speaking,
    required this.listening,
    required this.animate,
    required Listenable repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final r = w * 0.25;
    final phase = idle.value * 2 * math.pi;
    final open = mouth.value;

    // Body / head motion
    final breath = animate ? math.sin(phase * 2) : 0.0;
    final bob = animate ? math.sin(phase) * h * 0.007 : 0.0;
    // Nod a little on the loud parts of speech, tilt while listening.
    final nod = speaking ? -open * 0.030 : 0.0;
    final tilt = (animate ? math.sin(phase + 0.7) * 0.030 : 0.0) +
        (listening ? -0.045 : 0.0) +
        nod;
    // Hair trails the head.
    final sway = animate ? math.sin(phase * 1.5 - 0.9) * w * 0.014 : 0.0;

    final cx = w * 0.5;
    final cy = h * 0.415 + bob;

    if (speaking) {
      canvas.drawCircle(
        Offset(cx, cy),
        w * 0.56,
        Paint()
          ..shader = RadialGradient(
            colors: [
              teacher.accent.withOpacity(0.24),
              teacher.accent.withOpacity(0.0),
            ],
          ).createShader(
              Rect.fromCircle(center: Offset(cx, cy), radius: w * 0.56)),
      );
    }

    _drawBody(canvas, w, h, r, cx, cy, breath);

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(tilt);

    _drawHairBack(canvas, r, sway);
    _drawNeck(canvas, r);
    _drawHead(canvas, r, w);
    _drawHairFront(canvas, r, sway);
    _drawFace(canvas, r, w, open);

    canvas.restore();
  }

  // ------------------------------------------------------------------- body

  void _drawBody(
    Canvas canvas,
    double w,
    double h,
    double r,
    double cx,
    double cy,
    double breath,
  ) {
    final top = cy + r * 1.26;
    final lift = breath * h * 0.004;

    final torso = Path()
      ..moveTo(w * 0.015, h)
      ..cubicTo(w * 0.04, top + r * 0.28 - lift, w * 0.16, top - r * 0.06 - lift,
          w * 0.34, top - r * 0.10 - lift)
      ..lineTo(w * 0.66, top - r * 0.10 - lift)
      ..cubicTo(w * 0.84, top - r * 0.06 - lift, w * 0.96, top + r * 0.28 - lift,
          w * 0.985, h)
      ..close();
    canvas.drawPath(
      torso,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_lighten(teacher.outfit, 0.06), _darken(teacher.outfit, 0.10)],
        ).createShader(Rect.fromLTWH(0, top - r * 0.10, w, h - top)),
    );

    // shirt opening
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.30, top - r * 0.02 - lift)
        ..lineTo(w * 0.50, top + r * 0.10 - lift)
        ..lineTo(w * 0.70, top - r * 0.02 - lift)
        ..close(),
      Paint()..color = _darken(teacher.outfit, 0.14),
    );
    // collar
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.365, top - r * 0.03 - lift)
        ..lineTo(w * 0.50, top + r * 0.09 - lift)
        ..lineTo(w * 0.635, top - r * 0.03 - lift)
        ..close(),
      Paint()..color = _lighten(teacher.outfit, 0.32),
    );
  }

  // ------------------------------------------------------------------- head

  void _drawNeck(Canvas canvas, double r) {
    final skinDark = _darken(teacher.skin, 0.07);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-0.35 * r, 0.60 * r, 0.70 * r, 0.94 * r),
        Radius.circular(0.30 * r),
      ),
      Paint()..color = skinDark,
    );
    // jaw shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(0, 0.70 * r),
        width: 0.74 * r,
        height: 0.30 * r,
      ),
      Paint()..color = _darken(teacher.skin, 0.15),
    );
    // trapezius: the neck flares into the shoulders
    canvas.drawPath(
      Path()
        ..moveTo(-0.62 * r, 1.30 * r)
        ..cubicTo(-0.50 * r, 1.06 * r, -0.34 * r, 0.98 * r, 0, 0.96 * r)
        ..cubicTo(0.34 * r, 0.98 * r, 0.50 * r, 1.06 * r, 0.62 * r, 1.30 * r)
        ..close(),
      Paint()..color = _darken(teacher.skin, 0.13),
    );
  }

  void _drawHead(Canvas canvas, double r, double w) {
    final head = Path()
      ..moveTo(0, -1.00 * r)
      ..cubicTo(0.62 * r, -1.00 * r, 0.88 * r, -0.62 * r, 0.88 * r, -0.05 * r)
      ..cubicTo(0.88 * r, 0.42 * r, 0.62 * r, 0.80 * r, 0, 0.98 * r)
      ..cubicTo(-0.62 * r, 0.80 * r, -0.88 * r, 0.42 * r, -0.88 * r, -0.05 * r)
      ..cubicTo(-0.88 * r, -0.62 * r, -0.62 * r, -1.00 * r, 0, -1.00 * r)
      ..close();
    canvas.drawPath(
      head,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_lighten(teacher.skin, 0.05), _darken(teacher.skin, 0.06)],
        ).createShader(Rect.fromLTRB(-r, -r, r, r)),
    );
    final ear = Paint()..color = _darken(teacher.skin, 0.05);
    for (final sx in [-0.88, 0.88]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(sx * r, 0.10 * r),
          width: 0.22 * r,
          height: 0.38 * r,
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
        canvas.drawPath(
          Path()
            ..moveTo(-1.10 * r, -0.55 * r)
            ..cubicTo(-1.20 * r, -1.05 * r, -0.70 * r, -1.32 * r, 0, -1.30 * r)
            ..cubicTo(0.70 * r, -1.32 * r, 1.20 * r, -1.05 * r, 1.10 * r, -0.55 * r)
            ..cubicTo(1.16 * r, 0.30 * r, 1.02 * r, 1.00 * r, 0.86 * r, 1.35 * r)
            ..cubicTo(0.60 * r, 1.55 * r, -0.60 * r, 1.55 * r, -0.86 * r, 1.35 * r)
            ..cubicTo(-1.02 * r, 1.00 * r, -1.16 * r, 0.30 * r, -1.10 * r, -0.55 * r)
            ..close(),
          paint,
        );
        break;
      case HairStyle.bob:
        canvas.drawPath(
          Path()
            ..moveTo(-1.04 * r, -0.60 * r)
            ..cubicTo(-1.14 * r, -1.10 * r, -0.66 * r, -1.34 * r, 0, -1.32 * r)
            ..cubicTo(0.66 * r, -1.34 * r, 1.14 * r, -1.10 * r, 1.04 * r, -0.60 * r)
            ..cubicTo(1.06 * r, 0.10 * r, 0.98 * r, 0.55 * r, 0.82 * r, 0.72 * r)
            ..cubicTo(0.55 * r, 0.95 * r, -0.55 * r, 0.95 * r, -0.82 * r, 0.72 * r)
            ..cubicTo(-0.98 * r, 0.55 * r, -1.06 * r, 0.10 * r, -1.04 * r, -0.60 * r)
            ..close(),
          paint,
        );
        break;
      case HairStyle.curly:
        for (var i = 0; i <= 15; i++) {
          final a = math.pi * (0.80 + 1.40 * (i / 15));
          final rr = 0.92 + 0.06 * math.sin(i * 2.1);
          canvas.drawCircle(
            Offset(math.cos(a) * rr * r, math.sin(a) * rr * r - 0.02 * r),
            0.40 * r,
            paint,
          );
        }
        for (var i = 0; i < 4; i++) {
          for (final sx in [-1.02, 1.02]) {
            canvas.drawCircle(
              Offset(sx * r, 0.10 * r + i * 0.30 * r),
              0.34 * r,
              paint,
            );
          }
        }
        break;
      default:
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(0, -0.04 * r),
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
    final sheen = Paint()..color = teacher.hairLight.withOpacity(0.45);
    canvas.save();
    canvas.translate(sway * 0.6, 0);
    switch (teacher.hairStyle) {
      case HairStyle.long:
      case HairStyle.bob:
        canvas.drawPath(
          Path()
            ..moveTo(-0.90 * r, -0.30 * r)
            ..cubicTo(-0.92 * r, -1.02 * r, -0.60 * r, -1.22 * r, -0.10 * r, -1.18 * r)
            ..cubicTo(0.30 * r, -1.30 * r, 0.80 * r, -1.16 * r, 0.90 * r, -0.55 * r)
            ..cubicTo(0.72 * r, -0.86 * r, 0.34 * r, -1.00 * r, 0.02 * r, -0.92 * r)
            ..cubicTo(-0.28 * r, -0.86 * r, -0.62 * r, -0.80 * r, -0.90 * r, -0.30 * r)
            ..close(),
          paint,
        );
        canvas.drawPath(
          Path()
            ..moveTo(-0.62 * r, -0.62 * r)
            ..cubicTo(-0.50 * r, -1.00 * r, -0.20 * r, -1.10 * r, 0.06 * r, -1.06 * r)
            ..cubicTo(-0.18 * r, -0.94 * r, -0.44 * r, -0.82 * r, -0.62 * r, -0.62 * r)
            ..close(),
          sheen,
        );
        break;
      case HairStyle.short:
        canvas.drawPath(
          Path()
            ..moveTo(-0.92 * r, -0.26 * r)
            ..cubicTo(-0.94 * r, -1.04 * r, -0.60 * r, -1.26 * r, 0, -1.20 * r)
            ..cubicTo(0.60 * r, -1.26 * r, 0.94 * r, -1.04 * r, 0.92 * r, -0.26 * r)
            ..cubicTo(0.80 * r, -0.62 * r, 0.50 * r, -0.80 * r, 0.22 * r, -0.76 * r)
            ..cubicTo(0, -0.84 * r, -0.30 * r, -0.80 * r, -0.92 * r, -0.26 * r)
            ..close(),
          paint,
        );
        canvas.drawPath(
          Path()
            ..moveTo(-0.58 * r, -0.52 * r)
            ..cubicTo(-0.44 * r, -1.00 * r, -0.10 * r, -1.12 * r, 0.18 * r, -1.06 * r)
            ..cubicTo(-0.12 * r, -0.90 * r, -0.40 * r, -0.74 * r, -0.58 * r, -0.52 * r)
            ..close(),
          sheen,
        );
        break;
      case HairStyle.bun:
        canvas.drawCircle(Offset(0.02 * r, -1.16 * r), 0.30 * r, paint);
        canvas.drawCircle(Offset(0.02 * r, -1.16 * r), 0.30 * r, sheen);
        canvas.drawPath(
          Path()
            ..moveTo(-0.90 * r, -0.28 * r)
            ..cubicTo(-0.92 * r, -1.06 * r, -0.60 * r, -1.26 * r, 0, -1.20 * r)
            ..cubicTo(0.60 * r, -1.26 * r, 0.92 * r, -1.06 * r, 0.90 * r, -0.28 * r)
            ..cubicTo(0.66 * r, -0.70 * r, 0.30 * r, -0.86 * r, 0, -0.80 * r)
            ..cubicTo(-0.32 * r, -0.86 * r, -0.66 * r, -0.70 * r, -0.90 * r, -0.28 * r)
            ..close(),
          paint,
        );
        break;
      case HairStyle.curly:
        for (var i = 0; i <= 8; i++) {
          final x = -0.86 * r + (i / 8) * 1.72 * r;
          canvas.drawCircle(
            Offset(x, -0.78 * r + math.sin(i * 1.9) * 0.06 * r),
            0.26 * r,
            paint,
          );
        }
        break;
    }
    canvas.restore();
  }

  // ------------------------------------------------------------------- face

  void _drawFace(Canvas canvas, double r, double w, double open) {
    const eyeY = -0.04;
    const eyeDx = 0.335;
    const eyeW = 0.355;
    const eyeH = 0.30;
    final closure = blink.value;
    final lookX = gaze.value * 0.045 * r;

    // eyebrows — soft arch
    final browPaint = Paint()
      ..color = _lighten(teacher.hair, 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.045 * r
      ..strokeCap = StrokeCap.round;
    for (final dx in [-eyeDx, eyeDx]) {
      canvas.drawArc(
        Rect.fromCenter(
          center: Offset(dx * r, (eyeY - 0.44) * r),
          width: eyeW * 1.12 * r,
          height: eyeH * 0.80 * r,
        ),
        math.pi * 1.11,
        math.pi * 0.78,
        false,
        browPaint,
      );
    }

    for (final dx in [-eyeDx, eyeDx]) {
      final center = Offset(dx * r, eyeY * r);
      final eyeRect =
          Rect.fromCenter(center: center, width: eyeW * r, height: eyeH * r);

      canvas.drawOval(eyeRect, Paint()..color = const Color(0xFFFBFBFB));

      final irisCenter = center.translate(lookX, 0.025 * r);
      final irisRect = Rect.fromCenter(
        center: irisCenter,
        width: eyeW * 0.66 * r,
        height: eyeH * 0.92 * r,
      );
      canvas.drawOval(
        irisRect,
        Paint()
          ..shader = RadialGradient(
            colors: [
              _lighten(teacher.accent, 0.12),
              _darken(teacher.accent, 0.22),
            ],
          ).createShader(irisRect),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: irisCenter,
          width: eyeW * 0.27 * r,
          height: eyeH * 0.42 * r,
        ),
        Paint()..color = const Color(0xFF20140F),
      );
      canvas.drawCircle(
        irisCenter.translate(-eyeW * 0.12 * r, -eyeH * 0.08 * r),
        eyeW * 0.072 * r,
        Paint()..color = Colors.white,
      );

      // upper lash line
      canvas.drawArc(
        eyeRect,
        math.pi * 1.09,
        math.pi * 0.82,
        false,
        Paint()
          ..color = teacher.hair
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.055 * r
          ..strokeCap = StrokeCap.round,
      );
      // lower lid
      canvas.drawArc(
        eyeRect,
        math.pi * 0.13,
        math.pi * 0.74,
        false,
        Paint()
          ..color = _darken(teacher.skin, 0.22).withOpacity(0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.026 * r
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
          math.pi * 1.09,
          math.pi * 0.82,
          false,
          Paint()
            ..color = teacher.hair
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.05 * r
            ..strokeCap = StrokeCap.round,
        );
      }
    }

    // nose
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(0, 0.20 * r),
        width: 0.17 * r,
        height: 0.20 * r,
      ),
      math.pi * 0.17,
      math.pi * 0.66,
      false,
      Paint()
        ..color = _darken(teacher.skin, 0.26)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.038 * r
        ..strokeCap = StrokeCap.round,
    );

    // blush
    for (final dx in [-0.62, 0.62]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(dx * r, 0.30 * r),
          width: 0.34 * r,
          height: 0.20 * r,
        ),
        Paint()
          ..color = const Color(0xFFFF8080)
              .withOpacity(speaking && open > 0.15 ? 0.30 : 0.18),
      );
    }

    _drawMouth(canvas, r, open);
  }

  void _drawMouth(Canvas canvas, double r, double open) {
    // The jaw drops with the voice, so the whole lower face moves.
    final jaw = open * 0.055 * r;
    final center = Offset(0, 0.56 * r + jaw);

    if (open < 0.06) {
      canvas.drawArc(
        Rect.fromCenter(center: center, width: 0.46 * r, height: 0.30 * r),
        math.pi * 0.12,
        math.pi * 0.76,
        false,
        Paint()
          ..color = const Color(0xFFB05A5A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.055 * r
          ..strokeCap = StrokeCap.round,
      );
      return;
    }

    final mw = 0.50 * r - open * 0.06 * r;
    final mh = 0.08 * r + open * 0.40 * r;
    final rect = Rect.fromCenter(center: center, width: mw, height: mh);

    canvas.drawOval(rect, Paint()..color = const Color(0xFF8E3B41));
    canvas.drawOval(
      rect.deflate(0.035 * r),
      Paint()..color = const Color(0xFF4A171D),
    );
    if (open > 0.20) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            -mw * 0.36,
            center.dy - mh / 2 + 0.02 * r,
            mw * 0.72,
            0.07 * r,
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
          width: mw * 0.46,
          height: 0.10 * r,
        ),
        Paint()..color = const Color(0xFFC96A72),
      );
    }
    // lip outline
    canvas.drawOval(
      rect,
      Paint()
        ..color = _darken(teacher.skin, 0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.02 * r,
    );
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
