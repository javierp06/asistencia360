import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminAttendanceList extends StatelessWidget {
  const AdminAttendanceList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Datos de ejemplo
    final attendanceRecords = [
      {
        'name': 'Juan Pérez',
        'status': 'Presente',
        'checkIn': '08:02',
        'checkOut': '17:05',
        'date': DateTime.now(),
      },
      {
        'name': 'María García',
        'status': 'Presente',
        'checkIn': '07:55',
        'checkOut': '17:00',
        'date': DateTime.now(),
      },
      {
        'name': 'Carlos Rodríguez',
        'status': 'Ausente',
        'checkIn': '--:--',
        'checkOut': '--:--',
        'date': DateTime.now(),
      },
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Asistencia del Personal',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: attendanceRecords.length,
              itemBuilder: (context, index) {
                final record = attendanceRecords[index];
                final isPresent = record['status'] == 'Presente';
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isPresent ? Colors.green : Colors.red,
                      child: Icon(
                        isPresent ? Icons.check : Icons.close,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(record['name'].toString()),
                    subtitle: Text('Entrada: ${record['checkIn']} | Salida: ${record['checkOut']}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.edit),
                      onPressed: () {
                        // Acción para editar el registro
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}