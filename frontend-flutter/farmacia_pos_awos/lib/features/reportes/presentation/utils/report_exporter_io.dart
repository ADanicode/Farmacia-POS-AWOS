import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/venta_reporte.dart';

Future<String?> exportVentasCsv({
  required List<VentaReporte> ventas,
  required String fileName,
}) async {
  final List<List<dynamic>> rows = <List<dynamic>>[
    <dynamic>['Folio', 'Fecha', 'Cajero', 'Metodo', 'Total', 'Estado'],
    ...ventas.map(
      (VentaReporte v) => <dynamic>[
        v.folio,
        v.fecha.toIso8601String(),
        v.cajero,
        v.metodoPago,
        v.total,
        v.estado,
      ],
    ),
  ];

  final String csv = const ListToCsvConverter().convert(rows);
  final Directory dir = await getApplicationDocumentsDirectory();
  final File file = File('${dir.path}/$fileName.csv');
  await file.writeAsString(csv, flush: true);
  return file.path;
}
