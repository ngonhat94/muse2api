import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Local vector artwork: no asset fetch can delay the credential check.
class ShibaLoadingPage extends StatelessWidget {
  const ShibaLoadingPage({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: SafeArea(child: Center(child: RunningShiba())),
  );
}

class RunningShiba extends StatefulWidget {
  const RunningShiba({super.key});

  @override
  State<RunningShiba> createState() => _RunningShibaState();
}

class _RunningShibaState extends State<RunningShiba>
    with SingleTickerProviderStateMixin {
  late final AnimationController _stride = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 640),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) || !TickerMode.of(context)) {
      _stride.stop();
      _stride.value = 0;
    } else {
      _stride.repeat();
    }
  }

  @override
  void dispose() {
    _stride.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Đang kiểm tra API key đã lưu. Vui lòng chờ.',
    liveRegion: true,
    child: ExcludeSemantics(
      child: RepaintBoundary(
        child: SizedBox(
          width: 176,
          height: 128,
          child: CustomPaint(painter: _ShibaPainter(_stride)),
        ),
      ),
    ),
  );
}

class _ShibaPainter extends CustomPainter {
  _ShibaPainter(this.stride) : super(repaint: stride);
  final Animation<double> stride;
  static const fur = Color(0xFFE5A15B);
  static const cream = Color(0xFFFFEBD1);
  static const ink = Color(0xFF302820);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 176, size.height / 128);
    final phase = stride.value * math.pi * 2;
    final gait = math.sin(phase);
    final lift = 3 * math.cos(phase * 2);
    final paint = Paint()..isAntiAlias = true;
    void oval(Rect rect, Color color) {
      canvas.drawOval(rect, paint..color = color);
    }

    void line(Offset a, Offset b, Color color, double width) {
      canvas.drawLine(
        a,
        b,
        paint
          ..color = color
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );
    }

    // A quiet contact patch anchors the run without adding another loader.
    oval(
      Rect.fromCenter(center: const Offset(87, 108), width: 83, height: 5),
      const Color(0xFF38383F),
    );
    canvas.save();
    canvas.translate(0, lift);
    // Curled tail, cream tip and far-side legs.
    final tail = Path()
      ..moveTo(48, 66)
      ..cubicTo(20, 69, 22, 35, 39, 43)
      ..cubicTo(52, 49, 40, 62, 34, 53);
    canvas.drawPath(
      tail,
      paint
        ..color = fur
        ..style = PaintingStyle.stroke
        ..strokeWidth = 13
        ..strokeCap = StrokeCap.round,
    );
    paint.style = PaintingStyle.fill;
    oval(const Rect.fromLTWH(27, 40, 13, 13), cream);
    for (final x in [62.0, 110.0]) {
      final swing = x < 80 ? -gait : gait;
      line(
        Offset(x, 78),
        Offset(x + swing * 13, 99),
        const Color(0xFFAF713F),
        9,
      );
      line(
        Offset(x + swing * 13, 99),
        Offset(x + swing * 17 + 7, 100),
        cream,
        7,
      );
    }
    oval(const Rect.fromLTWH(42, 53, 85, 39), fur);
    oval(const Rect.fromLTWH(60, 73, 61, 17), cream);
    // Near legs counter-swing with bent ankles and soft paws.
    for (final x in [57.0, 108.0]) {
      final swing = x < 80 ? gait : -gait;
      final knee = Offset(x + swing * 9, 90);
      final paw = Offset(x + swing * 18, 102 - math.max(0, swing) * 7);
      line(Offset(x, 77), knee, fur, 11);
      line(knee, paw, fur, 8);
      line(paw, paw + const Offset(7, 0), cream, 7);
    }
    // Pointed ears, rounded cheek and the characteristic pale Shiba muzzle.
    final ears = Path()
      ..moveTo(105, 49)
      ..lineTo(106, 25)
      ..quadraticBezierTo(111, 23, 121, 39)
      ..lineTo(132, 38)
      ..lineTo(139, 24)
      ..quadraticBezierTo(144, 29, 144, 52)
      ..close();
    canvas.drawPath(ears, paint..color = fur);
    final inner = Path()
      ..moveTo(109, 32)
      ..lineTo(111, 46)
      ..lineTo(119, 41)
      ..close()
      ..moveTo(138, 33)
      ..lineTo(133, 44)
      ..lineTo(141, 47)
      ..close();
    canvas.drawPath(inner, paint..color = const Color(0xFFC77B64));
    oval(const Rect.fromLTWH(99, 37, 50, 42), fur);
    oval(const Rect.fromLTWH(113, 57, 39, 22), cream);
    oval(const Rect.fromLTWH(142, 56, 10, 7), ink);
    oval(const Rect.fromLTWH(130, 48, 4, 5), ink);
    oval(const Rect.fromLTWH(127, 43, 8, 3), cream);
    line(const Offset(140, 67), const Offset(145, 66), ink, 1.8);
    // Small peach bandana echoes Muse's existing warm accent.
    final scarf = Path()
      ..moveTo(108, 72)
      ..lineTo(122, 76)
      ..lineTo(111, 87)
      ..close();
    canvas.drawPath(scarf, paint..color = const Color(0xFFF4A27C));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ShibaPainter oldDelegate) => oldDelegate.stride != stride;
}
