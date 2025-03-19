import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/request.dart';


class RequestList extends StatelessWidget {
  final List<Request> requests;
  final Function(Request, RequestStatus)? onUpdateStatus;

  const RequestList({
    Key? key, 
    required this.requests, 
    this.onUpdateStatus
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final request = requests[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ExpansionTile(
            leading: _getLeadingIcon(request.type),
            title: Text(_getRequestTitle(request)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mostrar el nombre del empleado si está disponible y hay un callback de admin
                if (onUpdateStatus != null && request.employeeName != null)
                  Text(
                    'Solicitado por: ${request.employeeName}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                const SizedBox(height: 4),
                Text(
                  '${_formatDate(request.startDate)} - ${_formatDate(request.endDate)}',
                ),
              ],
            ),
            trailing: _getStatusChip(request.status),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Motivo: ${request.reason}'),
                    if (request.hours != null)
                      Text('Horas: ${request.hours}'),
                    if (request.comments != null && request.comments!.isNotEmpty)
                      Text('Comentarios: ${request.comments}'),
                    if (request.attachmentUrl != null)
                      InkWell(
                        onTap: () {
                          // Abrir el documento adjunto (por ejemplo mediante url_launcher)
                          final Uri url = Uri.parse(request.attachmentUrl!);
                          // Necesitarías importar url_launcher y usar launchUrl(url)
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Abriendo documento: ${request.attachmentUrl}')),
                          );
                        },
                        child: Row(
                          children: const [
                            Icon(Icons.attach_file),
                            SizedBox(width: 8),
                            Text('Ver documento adjunto', 
                              style: TextStyle(
                                color: Colors.blue, 
                                decoration: TextDecoration.underline
                              )
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    Text(
                      'Fecha de solicitud: ${DateFormat('dd/MM/yyyy').format(request.createdAt)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    // Agregar botones de acción para administradores
                    if (onUpdateStatus != null && request.status == RequestStatus.pending)
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(Icons.cancel, color: Colors.white),
                              label: const Text('Rechazar'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => onUpdateStatus!(request, RequestStatus.rejected),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.check_circle, color: Colors.white),
                              label: const Text('Aprobar'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              onPressed: () => onUpdateStatus!(request, RequestStatus.approved),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _getLeadingIcon(RequestType type) {
    switch (type) {
      case RequestType.permission:
        return const CircleAvatar(
          child: Icon(Icons.event_busy),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        );
      
      case RequestType.vacation:
        return const CircleAvatar(
          child: Icon(Icons.beach_access),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        );
      case RequestType.disability:
        return const CircleAvatar(
          child: Icon(Icons.medical_services),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        );
    }
  }

  Widget _getStatusChip(RequestStatus status) {
    switch (status) {
      case RequestStatus.pending:
        return const Chip(
          label: Text('Pendiente'),
          backgroundColor: Color(0xFFFFF9C4), // Yellow light
          labelStyle: TextStyle(color: Colors.amber),
        );
      case RequestStatus.approved:
        return const Chip(
          label: Text('Aprobado'),
          backgroundColor: Color(0xFFE8F5E9), // Green light
          labelStyle: TextStyle(color: Colors.green),
        );
      case RequestStatus.rejected:
        return const Chip(
          label: Text('Rechazado'),
          backgroundColor: Color(0xFFFFEBEE), // Red light
          labelStyle: TextStyle(color: Colors.red),
        );
    }
  }

  String _getRequestTitle(Request request) {
    switch (request.type) {
      case RequestType.permission:
        return 'Permiso';
      case RequestType.vacation:
        return 'Vacaciones';
      case RequestType.disability:
        return 'Incapacidad';
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }
}