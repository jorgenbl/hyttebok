import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Tegnet hytteomslag: en koselig hytte med snø, furutrær og sol.
///
/// Brukt som standard «omslag» på bokens frontside og i lesevisningen når
/// boka ikke har eget omslagsbilde. Farger hentes fra temaets
/// [ColorScheme], slik at den fungerer i både lyst og mørkt tema.
class CabinIllustration extends StatelessWidget {
  const CabinIllustration({super.key, this.height = 150});

  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(size: Size.infinite, painter: _CabinPainter(scheme)),
    );
  }
}

class _CabinPainter extends CustomPainter {
  _CabinPainter(this.s);

  final ColorScheme s;

  /// Varm, gyllen farge til sol, vinduslys og «snø i sollys».
  static const _warm = Color(0xFFFFC94D);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final ground = h * 0.80;

    // Himmel.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h),
      Paint()..color = s.primaryContainer,
    );

    // Sol (øverst til høyre).
    final sun = Offset(w * 0.82, h * 0.20);
    canvas.drawCircle(sun, h * 0.085, Paint()..color = _warm);
    canvas.drawCircle(
      sun,
      h * 0.13,
      Paint()..color = _warm.withValues(alpha: 0.25),
    );

    // Snøflokker i himmelen.
    final flakes = const [
      (0.15, 0.18),
      (0.30, 0.32),
      (0.48, 0.14),
      (0.62, 0.30),
      (0.72, 0.16),
      (0.90, 0.34),
      (0.38, 0.24),
    ];
    final flakePaint = Paint()
      ..color = s.onPrimaryContainer.withValues(alpha: 0.35);
    for (final f in flakes) {
      canvas.drawCircle(Offset(w * f.$1, h * f.$2), h * 0.012, flakePaint);
    }

    // Fjernhøyder bak snøa.
    _hills(canvas, w, h, ground);

    // Snøa (forplene).
    final snow = Path()
      ..moveTo(0, ground + h * 0.02)
      ..quadraticBezierTo(w * 0.5, ground - h * 0.05, w, ground + h * 0.01)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(snow, Paint()..color = s.surface);

    // Hytta.
    _cabin(canvas, w, h, ground);

    // Trær.
    _pine(canvas, Offset(w * 0.14, ground + h * 0.005), h * 0.34);
    _pine(canvas, Offset(w * 0.26, ground - h * 0.005), h * 0.26);
    _pine(canvas, Offset(w * 0.88, ground + h * 0.0), h * 0.30);
  }

  void _hills(Canvas canvas, double w, double h, double ground) {
    final paint = Paint()
      ..color = s.secondaryContainer
      ..style = PaintingStyle.fill;
    // Kuppelaktige høyder bak snøa – størrelse i forhold til høyden, slik
    // at de ikke svømmer i himmelen på brede skjermer.
    for (final (cx, radius) in [(0.22 * w, 0.30 * h), (0.78 * w, 0.38 * h)]) {
      canvas.drawCircle(Offset(cx, ground + h * 0.14), radius, paint);
    }
  }

  void _cabin(Canvas canvas, double w, double h, double ground) {
    final cw = math.min(w * 0.40, h * 1.15);
    final ch = h * 0.42;
    final cx = w * 0.48;
    final bottom = ground + h * 0.02;
    final top = bottom - ch;

    // Kropp.
    final body = Path()
      ..addRect(Rect.fromLTWH(cx - cw / 2, top, cw, ch))
      ..close();
    canvas.drawPath(body, Paint()..color = s.primary);

    // Takk (trekant over kroppen, med utstikkende kant).
    final roof = Path()
      ..moveTo(cx - cw * 0.62, top)
      ..lineTo(cx, top - ch * 0.62)
      ..lineTo(cx + cw * 0.62, top)
      ..close();
    canvas.drawPath(roof, Paint()..color = s.primary);

    // Snørygg langs taket.
    final ridge = Path()
      ..moveTo(cx - cw * 0.58, top - ch * 0.045)
      ..lineTo(cx, top - ch * 0.665)
      ..lineTo(cx + cw * 0.58, top - ch * 0.045);
    canvas.drawPath(
      ridge,
      Paint()
        ..color = s.onPrimary
        ..style = PaintingStyle.stroke
        ..strokeWidth = h * 0.055
        ..strokeCap = StrokeCap.round,
    );

    // Rør på høyre takside.
    final chimneyW = cw * 0.15;
    final chimney = Rect.fromLTWH(
      cx + cw * 0.24,
      top - ch * 0.38,
      chimneyW,
      ch * 0.30,
    );
    canvas.drawRect(
      chimney,
      Paint()..color = s.primary.withValues(alpha: 0.85),
    );
    // Snø på røra.
    canvas.drawRect(
      Rect.fromLTWH(
        chimney.left - 2,
        chimney.top - h * 0.018,
        chimneyW + 4,
        h * 0.03,
      ),
      Paint()..color = s.onPrimary,
    );

    // Logglyfter (horisontale linjer i veggen).
    final logPaint = Paint()
      ..color = s.onPrimary.withValues(alpha: 0.25)
      ..strokeWidth = 1.5;
    for (var i = 1; i <= 3; i++) {
      final y = top + ch * (0.18 * i);
      canvas.drawLine(
        Offset(cx - cw / 2 + 2, y),
        Offset(cx + cw / 2 - 2, y),
        logPaint,
      );
    }

    // Dør (midt, rundet toppkant).
    final doorW = cw * 0.24;
    final doorH = ch * 0.52;
    final doorRect = Rect.fromLTWH(
      cx - doorW / 2,
      bottom - doorH,
      doorW,
      doorH,
    );
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        doorRect,
        topLeft: Radius.circular(doorW * 0.5),
        topRight: Radius.circular(doorW * 0.5),
      ),
      Paint()..color = s.onPrimary,
    );

    // Vindu med varmt lys (til venstre for døren).
    final winSize = cw * 0.22;
    final winRect = Rect.fromLTWH(
      cx - cw * 0.42,
      top + ch * 0.30,
      winSize,
      winSize,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(winRect, const Radius.circular(3)),
      Paint()..color = _warm,
    );
    final frame = Paint()
      ..color = s.onPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(winRect, const Radius.circular(3)),
      frame,
    );
    // Rutenett i vinduet.
    canvas.drawLine(
      Offset(winRect.center.dx, winRect.top),
      Offset(winRect.center.dx, winRect.bottom),
      frame,
    );
    canvas.drawLine(
      Offset(winRect.left, winRect.center.dy),
      Offset(winRect.right, winRect.center.dy),
      frame,
    );
  }

  /// Furutre i tre «etasje»-trekanter med stokk. [base] er der stokken møter
  /// snøa; [size] er total høyde.
  void _pine(Canvas canvas, Offset base, double size) {
    final trunkH = size * 0.18;
    final trunkW = size * 0.10;
    final green = s.secondary;

    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(base.dx, base.dy - trunkH / 2),
        width: trunkW,
        height: trunkH,
      ),
      Paint()..color = s.primary.withValues(alpha: 0.8),
    );

    final layers = 3;
    final topY = base.dy - size;
    for (var i = 0; i < layers; i++) {
      final t = i / layers;
      final layerBottom = topY + (size - trunkH) * (0.45 + 0.55 * t);
      final halfW = (size * 0.30) * (0.55 + 0.45 * t);
      final tri = Path()
        ..moveTo(base.dx - halfW, layerBottom)
        ..lineTo(base.dx, topY + (size - trunkH) * (0.08 + 0.28 * t))
        ..lineTo(base.dx + halfW, layerBottom)
        ..close();
      canvas.drawPath(tri, Paint()..color = green);
    }
  }

  @override
  bool shouldRepaint(_CabinPainter oldDelegate) => oldDelegate.s != s;
}
