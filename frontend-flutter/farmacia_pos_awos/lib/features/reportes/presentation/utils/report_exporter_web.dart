import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:universal_html/html.dart' as html;

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
  final List<int> bytes = utf8.encode(csv);

  final html.Blob blob = html.Blob(<dynamic>[bytes], 'text/csv;charset=utf-8');
  final String url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', '$fileName.csv')
    ..click();
  html.Url.revokeObjectUrl(url);

  return null;
}
