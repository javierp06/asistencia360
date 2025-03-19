import 'package:flutter/material.dart';

class CustomDataTable extends StatelessWidget {
  final List<DataColumn> columns;
  final List<DataRow> rows;

  const CustomDataTable({
    Key? key,
    required this.columns,
    required this.rows,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columns: columns,
          rows: rows,
          headingRowColor: MaterialStateProperty.resolveWith<Color>(
            (Set<MaterialState> states) {
              return Theme.of(context).colorScheme.surfaceVariant;
            },
          ),
          dataRowMinHeight: 60,
          dataRowMaxHeight: 80,
          headingRowHeight: 60,
          columnSpacing: 24,
          showCheckboxColumn: false,
        ),
      ),
    );
  }
}