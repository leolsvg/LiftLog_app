import 'package:flutter/material.dart';

class AnatomyIcon extends StatelessWidget {
  final String category;
  final Color baseColor = const Color(0xFF4A5568); // Corps gris foncé
  final Color highlightColor = const Color(0xFFFF3333); // Muscle ciblé en rouge fluo

  const AnatomyIcon({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final cleanCategory = category.toLowerCase();

    return Container(
      width: 45,
      height: 45,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF13171C), // Fond sombre LiftLog
        borderRadius: BorderRadius.circular(8),
      ),
      child: CustomPaint(
        painter: _AnatomyPainter(
          category: cleanCategory,
          baseColor: baseColor,
          highlightColor: highlightColor,
        ),
      ),
    );
  }
}

class _AnatomyPainter extends CustomPainter {
  final String category;
  final Color baseColor;
  final Color highlightColor;

  _AnatomyPainter({
    required this.category,
    required this.baseColor,
    required this.highlightColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final w = size.width;
    final h = size.height;

    // --- Dessin de la Tête ---
    paint.color = baseColor;
    canvas.drawCircle(Offset(w * 0.5, h * 0.15), h * 0.1, paint);

    // --- Détermination des zones de surbrillance rouge ---
    bool isPecs = category.contains('pectoraux') || category.contains('pec');
    bool isDos = category.contains('dorsal') || category.contains('dos') || category.contains('trapèze');
    bool isQuads = category.contains('quadriceps') || category.contains('cuisse');
    bool isIschios = category.contains('ischio');
    bool isEpaules = category.contains('deltoïde') || category.contains('épaule');
    bool isBras = category.contains('biceps') || category.contains('triceps') || category.contains('bras');
    bool isAbdos = category.contains('abdo') || category.contains('droit de l\'abdomen');

    // --- Buste / Tronc Central ---
    // Pectoraux / Abdos / Dos
    paint.color = (isPecs || isAbdos || isDos) ? highlightColor : baseColor;
    final Path torso = Path()
      ..moveTo(w * 0.35, h * 0.28)
      ..lineTo(w * 0.65, h * 0.28)
      ..lineTo(w * 0.60, h * 0.60)
      ..lineTo(w * 0.40, h * 0.60)
      ..close();
    canvas.drawPath(torso, paint);

    // Si on veut affiner le rendu : Séparation visuelle des Pecs (Haut du buste)
    if (!isPecs && !isAbdos && !isDos) {
      paint.color = baseColor;
    }

    // --- Épaules & Bras Gauche ---
    paint.color = (isEpaules || isBras) ? highlightColor : baseColor;
    final Path leftArm = Path()
      ..moveTo(w * 0.32, h * 0.28)
      ..lineTo(w * 0.20, h * 0.55)
      ..lineTo(w * 0.26, h * 0.57)
      ..lineTo(w * 0.35, h * 0.32)
      ..close();
    canvas.drawPath(leftArm, paint);

    // --- Épaules & Bras Droit ---
    final Path rightArm = Path()
      ..moveTo(w * 0.68, h * 0.28)
      ..lineTo(w * 0.80, h * 0.55)
      ..lineTo(w * 0.74, h * 0.57)
      ..lineTo(w * 0.65, h * 0.32)
      ..close();
    canvas.drawPath(rightArm, paint);

    // --- Jambe Gauche (Quads / Ischios) ---
    paint.color = (isQuads || isIschios) ? highlightColor : baseColor;
    final Path leftLeg = Path()
      ..moveTo(w * 0.40, h * 0.62)
      ..lineTo(w * 0.35, h * 0.95)
      ..lineTo(w * 0.44, h * 0.95)
      ..lineTo(w * 0.49, h * 0.62)
      ..close();
    canvas.drawPath(leftLeg, paint);

    // --- Jambe Droit (Quads / Ischios) ---
    final Path rightLeg = Path()
      ..moveTo(w * 0.60, h * 0.62)
      ..lineTo(w * 0.65, h * 0.95)
      ..lineTo(w * 0.56, h * 0.95)
      ..lineTo(w * 0.51, h * 0.62)
      ..close();
    canvas.drawPath(rightLeg, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}