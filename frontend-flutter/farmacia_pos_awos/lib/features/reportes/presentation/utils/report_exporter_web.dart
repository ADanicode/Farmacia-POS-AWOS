import 'dart:convert';
import 'dart:typed_data';

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

Future<String?> saveReportFile({
  required Uint8List bytes,
  required String fileName,
  required String extension,
  required String mimeType,
}) async {
  final html.Blob blob = html.Blob(<dynamic>[bytes], mimeType);
  final String url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', '$fileName.$extension')
    ..click();
  html.Url.revokeObjectUrl(url);
  return null;
}
