import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class PayrollReport extends StatelessWidget {
  final String period;
  
  const PayrollReport({Key? key, required this.period}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Gráfico de línea para nómina (simulado)
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
                'Tendencia de Nómina Mensual',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: CustomPaint(
                  painter: _LineChartPainter(),
                  child: Container(),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text('Enero', style: TextStyle(fontSize: 10)),
                  Text('Febrero', style: TextStyle(fontSize: 10)),
                  Text('Marzo', style: TextStyle(fontSize: 10)),
                  Text('Abril', style: TextStyle(fontSize: 10)),
                  Text('Mayo', style: TextStyle(fontSize: 10)),
                  Text('Junio', style: TextStyle(fontSize: 10)),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Resumen de gastos
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
                'Resumen de Gastos de Nómina',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _ExpenseItem(
                    title: 'Salarios Base',
                    amount: 60000,
                    color: Colors.blue,
                    percentage: 75,
                  ),
                  _ExpenseItem(
                    title: 'Horas Extra',
                    amount: 5000,
                    color: Colors.green,
                    percentage: 6,
                  ),
                  _ExpenseItem(
                    title: 'Bonificaciones',
                    amount: 15000,
                    color: Colors.purple,
                    percentage: 19,
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Tabla de distribución
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
                'Distribución por Departamento',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              const _DepartmentRow(
                department: 'Guías Turísticos',
                employees: 8,
                total: 32000,
                percentage: 40,
                color: Colors.blue,
              ),
              const Divider(),
              const _DepartmentRow(
                department: 'Administración',
                employees: 4,
                total: 24000,
                percentage: 30,
                color: Colors.green,
              ),
              const Divider(),
              const _DepartmentRow(
                department: 'Transporte',
                employees: 6,
                total: 24000,
                percentage: 30,
                color: Colors.amber,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LineChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.shade300
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
      
    final dotPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;
      
    final fillPaint = Paint()
      ..color = Colors.blue.withOpacity(0.1)
      ..style = PaintingStyle.fill;
      
    // Datos simulados de nómina mensual
    final List<double> data = [55000, 60000, 57000, 65000, 70000, 80000];
    
    // Encontrar máximo para escalar
    final double max = data.reduce((curr, next) => curr > next ? curr : next);
    
    // Calcular puntos en el gráfico
    final List<Offset> points = [];
    for (int i = 0; i < data.length; i++) {
      final x = i * (size.width / (data.length - 1));
      final y = size.height - (data[i] / max * size.height);
      points.add(Offset(x, y));
    }
    
    // Dibujar la línea
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);
    
    // Dibujar el área bajo la línea
    final fillPath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      fillPath.lineTo(points[i].dx, points[i].dy);
    }
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.lineTo(points.first.dx, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);
    
    // Dibujar los puntos
    for (final point in points) {
      canvas.drawCircle(point, 4, dotPaint);
    }
    
    // Dibujar líneas de referencia horizontales
    final dashPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;
      
    for (int i = 1; i < 5; i++) {
      final y = size.height * i / 5;
      final dashPath = Path();
      for (double x = 0; x < size.width; x += 5) {
        dashPath.moveTo(x, y);
        dashPath.lineTo(x + 3, y);
      }
      canvas.drawPath(dashPath, dashPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ExpenseItem extends StatelessWidget {
  final String title;
  final double amount;
  final Color color;
  final int percentage;

  const _ExpenseItem({
    required this.title,
    required this.amount,
    required this.color,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat("#,##0.00", "es_HN");
    
    return Column(
      children: [
        Container(
          height: 100,
          width: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.2),
          ),
          child: Center(
            child: Text(
              '$percentage%',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          'L ${formatter.format(amount)}',
          style: TextStyle(
            fontSize: 14,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _DepartmentRow extends StatelessWidget {
  final String department;
  final int employees;
  final double total;
  final int percentage;
  final Color color;

  const _DepartmentRow({
    required this.department,
    required this.employees,
    required this.total,
    required this.percentage,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat("#,##0.00", "es_HN");
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                department,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text('L ${formatter.format(total)}'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('$employees empleados', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              const Spacer(),
              Text('$percentage%', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ],
      ),
    );
  }
}