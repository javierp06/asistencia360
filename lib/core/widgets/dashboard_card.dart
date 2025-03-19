import 'package:flutter/material.dart';

class DashboardCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final int? count;
  final Color color;
  final VoidCallback onTap;

  const DashboardCard({
    Key? key,
    required this.icon,
    required this.title,
    this.count,
    required this.color,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isWeb = Theme.of(context).platform == TargetPlatform.macOS ||
                 Theme.of(context).platform == TargetPlatform.windows ||
                 Theme.of(context).platform == TargetPlatform.linux;
                 
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(isWeb ? 24.0 : 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: isWeb ? 48.0 : 40.0,
                color: color,
              ),
              SizedBox(height: isWeb ? 16.0 : 8.0),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isWeb ? 18.0 : 16.0,
                ),
                textAlign: TextAlign.center,
              ),
              if (count != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color,
                      fontSize: isWeb ? 16.0 : 14.0,
                    ),
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}