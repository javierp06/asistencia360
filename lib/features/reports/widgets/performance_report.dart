import 'package:flutter/material.dart';

class PerformanceReport extends StatelessWidget {
  const PerformanceReport({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Gráfico circular de rendimiento (simulado)
        Container(
          height: 250,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Distribución de Rendimiento',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Expanded(
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 180,
                        height: 180,
                        child: CustomPaint(
                          painter: _PieChartPainter(),
                        ),
                      ),
                      const Text(
                        '85%',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _LegendItem(color: Color(0xFF4CAF50), label: 'Excelente (60%)'),
                  SizedBox(width: 16),
                  _LegendItem(color: Color(0xFFFFC107), label: 'Regular (25%)'),
                  SizedBox(width: 16),
                  _LegendItem(color: Color(0xFFF44336), label: 'A mejorar (15%)'),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Top performers
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Top Empleados por Rendimiento',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              ListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildPerformanceItem('Juan Pérez', 95, Colors.green),
                  _buildPerformanceItem('María García', 90, Colors.green),
                  _buildPerformanceItem('Carlos Rodríguez', 85, Colors.green),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Áreas de mejora
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Áreas de Mejora',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              _buildImprovementArea('Puntualidad', 0.7),
              const SizedBox(height: 12),
              _buildImprovementArea('Trabajo en equipo', 0.9),
              const SizedBox(height: 12),
              _buildImprovementArea('Comunicación', 0.8),
              const SizedBox(height: 12),
              _buildImprovementArea('Resolución de problemas', 0.6),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPerformanceItem(String name, int score, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.grey[200],
            child: const Icon(Icons.person, color: Colors.grey),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: score / 100,
                  color: color,
                  backgroundColor: Colors.grey[200],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '$score%',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImprovementArea(String area, double score) {
    return Row(
      children: [
        Expanded(
          child: Text(area),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 2,
          child: LinearProgressIndicator(
            value: score,
            backgroundColor: Colors.grey[300],
            color: score > 0.8
                ? Colors.green
                : score > 0.6
                    ? Colors.amber
                    : Colors.red,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${(score * 100).toInt()}%',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _PieChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 25;

    // Dibujamos tres secciones del gráfico circular
    // 60% verde
    paint.color = const Color(0xFF4CAF50);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708, // -90 grados en radianes (inicio superior)
      2 * 3.14159 * 0.6, // 60% del círculo
      false,
      paint,
    );

    // 25% amarillo
    paint.color = const Color(0xFFFFC107);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708 + 2 * 3.14159 * 0.6,
      2 * 3.14159 * 0.25, // 25% del círculo
      false,
      paint,
    );

    // 15% rojo
    paint.color = const Color(0xFFF44336);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708 + 2 * 3.14159 * 0.85,
      2 * 3.14159 * 0.15, // 15% del círculo
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_PieChartPainter oldDelegate) => false;
}