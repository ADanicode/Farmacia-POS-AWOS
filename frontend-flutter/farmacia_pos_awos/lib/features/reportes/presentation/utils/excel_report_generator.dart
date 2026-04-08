import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_svg/flutter_svg.dart' as svg;
import 'package:syncfusion_flutter_xlsio/xlsio.dart';
import 'package:syncfusion_officechart/officechart.dart';
import 'package:farmacia_pos_awos/presentation/widgets/farmacia_logo.dart';

import '../../domain/entities/venta_reporte.dart';

class ExcelReportGenerator {
  Future<Uint8List> generateVentasXlsx({
    required List<VentaReporte> ventas,
  }) async {
    final Workbook workbook = Workbook();
    final Worksheet sheet = workbook.worksheets[0];
    sheet.name = 'Ventas';

    final Range headerRange = sheet.getRangeByName('A1:F3');
    headerRange.merge();
    headerRange.setText('Reporte de Ventas - Farmacia POS AWOS');
    headerRange.cellStyle.backColor = '#1976D2';
    headerRange.cellStyle.fontColor = '#FFFFFF';
    headerRange.cellStyle.bold = true;
    headerRange.cellStyle.hAlign = HAlignType.center;
    headerRange.cellStyle.vAlign = VAlignType.center;
    headerRange.cellStyle.fontSize = 18;

    final Uint8List logoBytes = await _svgToPngBytes(
      farmaciaLogoSvg,
      width: 220,
      height: 220,
    );
    final Picture logoPicture = sheet.pictures.addStream(1, 1, logoBytes);
    logoPicture.width = 78;
    logoPicture.height = 78;

    const int tableHeaderRow = 5;
    const int dataStartRow = 6;
    final List<String> headers = <String>[
      'Folio',
      'Fecha',
      'Cajero',
      'Metodo de Pago',
      'Total',
      'Estado',
    ];

    for (int i = 0; i < headers.length; i++) {
      final Range cell = sheet.getRangeByIndex(tableHeaderRow, i + 1);
      cell.setText(headers[i]);
      cell.cellStyle.backColor = '#E0E0E0';
      cell.cellStyle.bold = true;
      cell.cellStyle.hAlign = HAlignType.center;
      cell.cellStyle.vAlign = VAlignType.center;
      cell.cellStyle.borders.all.lineStyle = LineStyle.thin;
    }

    int currentRow = dataStartRow;
    for (final VentaReporte venta in ventas) {
      sheet.getRangeByIndex(currentRow, 1).setText(venta.folio);

      final Range fechaCell = sheet.getRangeByIndex(currentRow, 2);
      fechaCell.dateTime = venta.fecha;
      fechaCell.numberFormat = 'dd/mm/yyyy hh:mm';

      sheet.getRangeByIndex(currentRow, 3).setText(venta.cajero);
      sheet.getRangeByIndex(currentRow, 4).setText(venta.metodoPago);

      final Range totalCell = sheet.getRangeByIndex(currentRow, 5);
      totalCell.setNumber(venta.total);
      totalCell.numberFormat = r'$#,##0.00';

      sheet.getRangeByIndex(currentRow, 6).setText(venta.estado.toUpperCase());
      currentRow++;
    }

    final int dataEndRow = currentRow - 1;
    if (ventas.isNotEmpty) {
      final Range tableRange = sheet.getRangeByName('A5:F$dataEndRow');
      tableRange.cellStyle.borders.all.lineStyle = LineStyle.thin;
    }

    final int statsRow = (ventas.isEmpty ? dataStartRow : dataEndRow) + 2;
    final String formulaStartRow = ventas.isEmpty
        ? '6'
        : dataStartRow.toString();
    final String formulaEndRow = ventas.isEmpty ? '6' : dataEndRow.toString();

    sheet.getRangeByName('D$statsRow').setText('Ingreso Total');
    sheet
        .getRangeByName('E$statsRow')
        .setFormula('=SUM(E$formulaStartRow:E$formulaEndRow)');
    sheet.getRangeByName('D${statsRow + 1}').setText('Promedio de Ticket');
    sheet
        .getRangeByName('E${statsRow + 1}')
        .setFormula('=AVERAGE(E$formulaStartRow:E$formulaEndRow)');

    final Range statLabelRange = sheet.getRangeByName(
      'D$statsRow:D${statsRow + 1}',
    );
    statLabelRange.cellStyle.bold = true;

    final Range statValuesRange = sheet.getRangeByName(
      'E$statsRow:E${statsRow + 1}',
    );
    statValuesRange.numberFormat = r'$#,##0.00';
    statValuesRange.cellStyle.backColor = '#F3F8FD';
    statValuesRange.cellStyle.borders.all.lineStyle = LineStyle.thin;

    final Map<String, double> totalesPorMetodo = <String, double>{};
    for (final VentaReporte venta in ventas) {
      final String metodo = venta.metodoPago.trim().isEmpty
          ? 'Sin especificar'
          : venta.metodoPago.trim();
      totalesPorMetodo[metodo] = (totalesPorMetodo[metodo] ?? 0) + venta.total;
    }

    final int chartHeaderRow = 5;
    sheet.getRangeByName('H$chartHeaderRow').setText('Metodo');
    sheet.getRangeByName('I$chartHeaderRow').setText('Total');
    sheet.getRangeByName('H$chartHeaderRow:I$chartHeaderRow').cellStyle
      ..backColor = '#E0E0E0'
      ..bold = true
      ..borders.all.lineStyle = LineStyle.thin;

    int methodRow = chartHeaderRow + 1;
    if (totalesPorMetodo.isEmpty) {
      sheet.getRangeByName('H$methodRow').setText('Sin datos');
      sheet.getRangeByName('I$methodRow').setNumber(0);
      methodRow++;
    } else {
      totalesPorMetodo.forEach((String metodo, double total) {
        sheet.getRangeByName('H$methodRow').setText(metodo);
        final Range totalCell = sheet.getRangeByName('I$methodRow');
        totalCell.setNumber(total);
        totalCell.numberFormat = r'$#,##0.00';
        methodRow++;
      });
    }

    final int chartDataEndRow = methodRow - 1;
    final ChartCollection charts = ChartCollection(sheet);
    final Chart chart = charts.add();
    chart.chartType = ExcelChartType.pie;
    chart.dataRange = sheet.getRangeByName('H6:I$chartDataEndRow');
    chart.isSeriesInRows = false;
    chart.chartTitle = 'Distribucion por Metodo de Pago';
    chart.topRow = 5;
    chart.leftColumn = 8;
    chart.bottomRow = 22;
    chart.rightColumn = 13;
    sheet.charts = charts;

    for (int col = 1; col <= 9; col++) {
      sheet.autoFitColumn(col);
    }

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();
    return Uint8List.fromList(bytes);
  }

  Future<Uint8List> _svgToPngBytes(
    String svgXml, {
    required int width,
    required int height,
  }) async {
    final svg.PictureInfo pictureInfo = await svg.vg.loadPicture(
      svg.SvgStringLoader(svgXml),
      null,
    );

    final ui.Image image = await pictureInfo.picture.toImage(width, height);
    final ByteData? byteData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );

    image.dispose();
    pictureInfo.picture.dispose();

    if (byteData == null) {
      throw StateError('No se pudo convertir el logo SVG a PNG.');
    }

    return byteData.buffer.asUint8List();
  }
}
