import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class WeightChart extends StatelessWidget {
  final List<double> weightHistory;
  final double targetWeight;

  const WeightChart({
    super.key,
    required this.weightHistory,
    required this.targetWeight,
  });

  @override
  Widget build(BuildContext context) {
    // Si aucune donnée, on affiche un graphique vide
    if (weightHistory.isEmpty) {
      return const Center(child: Text("Ajoute une pesée pour voir ton évolution", style: TextStyle(color: Colors.grey)));
    }

    // Création des points du graphique
    List<FlSpot> spots = [];
    for (int i = 0; i < weightHistory.length; i++) {
      spots.add(FlSpot(i.toDouble(), weightHistory[i]));
    }

    // Calcul des échelles pour que la courbe soit bien centrée
    double minW = weightHistory.reduce((a, b) => a < b ? a : b);
    double maxW = weightHistory.reduce((a, b) => a > b ? a : b);

    // Si on a un objectif, on s'assure qu'il rentre dans le cadre de l'écran
    if (targetWeight > 0) {
      if (targetWeight < minW) minW = targetWeight;
      if (targetWeight > maxW) maxW = targetWeight;
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey[850], strokeWidth: 0.5),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (value, meta) {
                // Affiche "J-3", "J-2", etc. en bas
                if (value.toInt() >= 0 && value.toInt() < weightHistory.length) {
                  int daysAgo = weightHistory.length - 1 - value.toInt();
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(daysAgo == 0 ? 'Auj.' : 'J-$daysAgo', style: const TextStyle(color: Colors.grey, fontSize: 10)),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) => Text(value.toStringAsFixed(1), style: const TextStyle(color: Colors.grey, fontSize: 11)),
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: weightHistory.length > 1 ? (weightHistory.length - 1).toDouble() : 1.0,
        minY: minW - 1, // Petite marge en bas
        maxY: maxW + 1, // Petite marge en haut
        
        // 🎯 La fameuse ligne d'objectif !
        extraLinesData: ExtraLinesData(
          horizontalLines: targetWeight > 0 ? [
            HorizontalLine(
              y: targetWeight,
              color: Colors.greenAccent,
              strokeWidth: 2,
              dashArray: [5, 5], // Ligne pointillée
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topRight,
                padding: const EdgeInsets.only(right: 5, bottom: 5),
                style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12),
                labelResolver: (line) => 'Cible',
              ),
            )
          ] : [],
        ),
        
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.orangeAccent,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [Colors.orangeAccent.withValues(alpha:0.3), Colors.orangeAccent.withValues(alpha:0.0)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}