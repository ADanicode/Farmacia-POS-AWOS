import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_svg/flutter_svg.dart' as svg;
import 'package:syncfusion_flutter_xlsio/xlsio.dart';
import 'package:syncfusion_officechart/officechart.dart';
import 'package:farmacia_pos_awos/presentation/widgets/farmacia_logo.dart';

import '../../domain/entities/venta_reporte.dart';

/// Genera un Workbook XLSX multi-hoja con inteligencia de ventas corporativa:
/// Dashboard Ejecutivo, Datos Transaccionales y Análisis Estadístico.
class ExcelReportGenerator {
  // ─── Paleta corporativa ──────────────────────────────────────────────────
  static const String _azulCorp = '#1565C0';
  static const String _verdeCorp = '#1B5E20';
  static const String _verdeClaro = '#E8F5E9';
  static const String _grisOscuro = '#37474F';
  static const String _blanco = '#FFFFFF';
  static const String _filaPar = '#F5F9FF';

  Future<Uint8List> generateVentasXlsx({
    required List<VentaReporte> ventas,
  }) async {
    // Se crea con 3 hojas explícitas para garantizar estructura multi-hoja.
    final Workbook workbook = Workbook(3);

    // ── Crear las 3 hojas ─────────────────────────────────────────────────
    final Worksheet sheetDashboard = workbook.worksheets[0];
    sheetDashboard.name = 'Dashboard';
    final Worksheet sheetDatos = workbook.worksheets[1];
    sheetDatos.name = 'Datos Transaccionales';
    final Worksheet sheetStats = workbook.worksheets[2];
    sheetStats.name = 'Analisis Estadistico';

    // ── Logo SVG → PNG (una sola conversión para todo el libro) ──────────
    final Uint8List logoBytes = await _svgToPngBytes(
      farmaciaLogoSvg,
      width: 240,
      height: 240,
    );

    // ── Pre-cómputo de KPIs ───────────────────────────────────────────────
    final int numVentas = ventas.length;
    final double ventaTotal = ventas.fold(
      0.0,
      (double a, VentaReporte v) => a + v.total,
    );
    final double ivaTotal = ventas.fold(
      0.0,
      (double a, VentaReporte v) => a + v.iva,
    );
    final double ticketPromedio = numVentas > 0 ? ventaTotal / numVentas : 0.0;

    // ── Pre-cómputo distribución de métodos de pago ───────────────────────
    final Map<String, double> totalesPorMetodo = <String, double>{};
    for (final VentaReporte v in ventas) {
      final String m = v.metodoPago.trim().isEmpty
          ? 'Sin especificar'
          : v.metodoPago.trim();
      totalesPorMetodo[m] = (totalesPorMetodo[m] ?? 0.0) + v.total;
    }

    // ── Pre-cómputo estadísticas diarias ──────────────────────────────────
    final Map<String, _DiaStats> statsPorDia = <String, _DiaStats>{};
    for (final VentaReporte v in ventas) {
      final String dia =
          '${v.fecha.year.toString().padLeft(4, '0')}-'
          '${v.fecha.month.toString().padLeft(2, '0')}-'
          '${v.fecha.day.toString().padLeft(2, '0')}';
      statsPorDia.putIfAbsent(dia, () => _DiaStats(dia));
      statsPorDia[dia]!.add(v);
    }
    final List<_DiaStats> diasOrdenados = statsPorDia.values.toList()
      ..sort((_DiaStats a, _DiaStats b) => a.dia.compareTo(b.dia));

    // ── Construir cada hoja ───────────────────────────────────────────────
    await _buildDashboard(
      sheet: sheetDashboard,
      logoBytes: logoBytes,
      ventaTotal: ventaTotal,
      ticketPromedio: ticketPromedio,
      ivaTotal: ivaTotal,
      totalesPorMetodo: totalesPorMetodo,
    );

    _buildDatosTransaccionales(sheet: sheetDatos, ventas: ventas);

    _buildAnalisisEstadistico(
      sheet: sheetStats,
      diasOrdenados: diasOrdenados,
      totalVentas: numVentas,
    );

    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();
    return Uint8List.fromList(bytes);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HOJA 1 · DASHBOARD EJECUTIVO
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _buildDashboard({
    required Worksheet sheet,
    required Uint8List logoBytes,
    required double ventaTotal,
    required double ticketPromedio,
    required double ivaTotal,
    required Map<String, double> totalesPorMetodo,
  }) async {
    sheet.showGridlines = false;

    // Fondo corporativo superior para dar carácter ejecutivo al dashboard.
    final Range heroBand = sheet.getRangeByName('A1:L5');
    heroBand.cellStyle.backColor = '#E3F2FD';

    // Logo en A1
    final Picture logo = sheet.pictures.addStream(1, 1, logoBytes);
    logo.width = 80;
    logo.height = 80;

    // Título corporativo C2:I3
    final Range titleRange = sheet.getRangeByName('C2:I3');
    titleRange.merge();
    titleRange.setText('DASHBOARD DE INTELIGENCIA DE VENTAS');
    titleRange.cellStyle.backColor = _azulCorp;
    titleRange.cellStyle.fontColor = _blanco;
    titleRange.cellStyle.bold = true;
    titleRange.cellStyle.fontSize = 20;
    titleRange.cellStyle.hAlign = HAlignType.center;
    titleRange.cellStyle.vAlign = VAlignType.center;

    // Subtítulo C4:I4
    final Range subtitleRange = sheet.getRangeByName('C4:I4');
    subtitleRange.merge();
    subtitleRange.setText(
      'Farmacia POS AWOS — Reporte de Inteligencia de Ventas',
    );
    subtitleRange.cellStyle.fontColor = '#546E7A';
    subtitleRange.cellStyle.italic = true;
    subtitleRange.cellStyle.hAlign = HAlignType.center;
    subtitleRange.cellStyle.fontSize = 10;

    final Range versionBadge = sheet.getRangeByName('J2:L2');
    versionBadge.merge();
    versionBadge.setText('Workbook Inteligencia v2');
    versionBadge.cellStyle.backColor = '#0D47A1';
    versionBadge.cellStyle.fontColor = _blanco;
    versionBadge.cellStyle.bold = true;
    versionBadge.cellStyle.hAlign = HAlignType.center;
    versionBadge.cellStyle.vAlign = VAlignType.center;
    versionBadge.cellStyle.borders.all.lineStyle = LineStyle.medium;

    // Etiqueta de sección KPIs B6:L6
    final Range kpiSection = sheet.getRangeByName('B6:L6');
    kpiSection.merge();
    kpiSection.setText('INDICADORES CLAVE DE DESEMPEÑO (KPIs)');
    kpiSection.cellStyle.bold = true;
    kpiSection.cellStyle.fontColor = _grisOscuro;
    kpiSection.cellStyle.fontSize = 12;
    kpiSection.cellStyle.hAlign = HAlignType.center;

    // Tres tarjetas KPI
    _buildKpiCard(
      sheet: sheet,
      labelAddr: 'B8:D8',
      valueAddr: 'B9:D10',
      label: 'VENTA TOTAL',
      value: ventaTotal,
    );
    _buildKpiCard(
      sheet: sheet,
      labelAddr: 'F8:H8',
      valueAddr: 'F9:H10',
      label: 'TICKET PROMEDIO',
      value: ticketPromedio,
    );
    _buildKpiCard(
      sheet: sheet,
      labelAddr: 'J8:L8',
      valueAddr: 'J9:L10',
      label: 'TOTAL IVA RECAUDADO',
      value: ivaTotal,
    );

    // Tabla auxiliar de métodos de pago (columnas N:O, a la derecha del área visible)
    const int chartHeaderRow = 12;
    sheet.getRangeByName('N$chartHeaderRow').setText('Metodo de Pago');
    sheet.getRangeByName('O$chartHeaderRow').setText('Total');
    final Range chartTh = sheet.getRangeByName(
      'N$chartHeaderRow:O$chartHeaderRow',
    );
    chartTh.cellStyle.backColor = '#CFD8DC';
    chartTh.cellStyle.bold = true;

    int methodRow = chartHeaderRow + 1;
    if (totalesPorMetodo.isEmpty) {
      sheet.getRangeByName('N$methodRow').setText('Sin datos');
      sheet.getRangeByName('O$methodRow').setNumber(0);
      methodRow++;
    } else {
      totalesPorMetodo.forEach((String metodo, double total) {
        sheet.getRangeByName('N$methodRow').setText(metodo);
        final Range tCell = sheet.getRangeByName('O$methodRow');
        tCell.setNumber(total);
        tCell.numberFormat = r'$#,##0.00';
        methodRow++;
      });
    }
    final int chartDataEndRow = methodRow - 1;

    // Gráfico circular — posicionado debajo de los KPIs
    final ChartCollection charts = ChartCollection(sheet);
    final Chart chart = charts.add();
    chart.chartType = ExcelChartType.pie;
    chart.dataRange = sheet.getRangeByName(
      'N${chartHeaderRow + 1}:O$chartDataEndRow',
    );
    chart.isSeriesInRows = false;
    chart.chartTitle = 'Distribucion por Metodo de Pago';
    chart.topRow = 12;
    chart.leftColumn = 2;
    chart.bottomRow = 28;
    chart.rightColumn = 12;
    sheet.charts = charts;

    for (int c = 1; c <= 15; c++) {
      sheet.autoFitColumn(c);
    }

    // Reducimos visualmente la tabla auxiliar del chart para priorizar el dashboard.
    sheet.getRangeByName('N1:N200').columnWidth = 2;
    sheet.getRangeByName('O1:O200').columnWidth = 2;
  }

  /// Dibuja una tarjeta KPI con fila de etiqueta y fila de valor.
  void _buildKpiCard({
    required Worksheet sheet,
    required String labelAddr,
    required String valueAddr,
    required String label,
    required double value,
  }) {
    final Range labelCell = sheet.getRangeByName(labelAddr);
    labelCell.merge();
    labelCell.setText(label);
    labelCell.cellStyle.backColor = '#0D47A1';
    labelCell.cellStyle.fontColor = _blanco;
    labelCell.cellStyle.bold = true;
    labelCell.cellStyle.hAlign = HAlignType.center;
    labelCell.cellStyle.vAlign = VAlignType.center;
    labelCell.cellStyle.fontSize = 11;
    labelCell.cellStyle.borders.all.lineStyle = LineStyle.medium;

    final Range valueCell = sheet.getRangeByName(valueAddr);
    valueCell.merge();
    valueCell.setNumber(value);
    valueCell.numberFormat = r'$#,##0.00';
    valueCell.cellStyle.backColor = _verdeClaro;
    valueCell.cellStyle.fontColor = _verdeCorp;
    valueCell.cellStyle.bold = true;
    valueCell.cellStyle.hAlign = HAlignType.center;
    valueCell.cellStyle.vAlign = VAlignType.center;
    valueCell.cellStyle.fontSize = 16;
    valueCell.cellStyle.borders.all.lineStyle = LineStyle.medium;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HOJA 2 · DATOS TRANSACCIONALES
  // ─────────────────────────────────────────────────────────────────────────
  void _buildDatosTransaccionales({
    required Worksheet sheet,
    required List<VentaReporte> ventas,
  }) {
    // Encabezado de hoja A1:H2
    final Range sheetTitle = sheet.getRangeByName('A1:H2');
    sheetTitle.merge();
    sheetTitle.setText('DATOS TRANSACCIONALES — Farmacia POS AWOS');
    sheetTitle.cellStyle.backColor = _grisOscuro;
    sheetTitle.cellStyle.fontColor = _blanco;
    sheetTitle.cellStyle.bold = true;
    sheetTitle.cellStyle.hAlign = HAlignType.center;
    sheetTitle.cellStyle.vAlign = VAlignType.center;
    sheetTitle.cellStyle.fontSize = 14;
    sheet.showGridlines = true;

    // Cabecera de tabla en fila 4
    const int headerRow = 4;
    const int dataStartRow = 5;
    const List<String> headers = <String>[
      'Folio',
      'Fecha',
      'Cajero',
      'Subtotal',
      'IVA',
      'Total',
      'Metodo de Pago',
      'Receta Retenida',
    ];

    for (int i = 0; i < headers.length; i++) {
      final Range cell = sheet.getRangeByIndex(headerRow, i + 1);
      cell.setText(headers[i]);
      cell.cellStyle.backColor = _azulCorp;
      cell.cellStyle.fontColor = _blanco;
      cell.cellStyle.bold = true;
      cell.cellStyle.hAlign = HAlignType.center;
      cell.cellStyle.vAlign = VAlignType.center;
      cell.cellStyle.borders.all.lineStyle = LineStyle.thin;
    }

    // Inmovilizar encabezados (filas 1-4 fijas al hacer scroll vertical)
    sheet.getRangeByName('A5').freezePanes();

    // Filas de datos con zebra striping
    int currentRow = dataStartRow;
    for (int idx = 0; idx < ventas.length; idx++) {
      final VentaReporte v = ventas[idx];
      final String rowBg = idx.isEven ? _blanco : _filaPar;

      void applyStyle(Range c) {
        c.cellStyle.backColor = rowBg;
        c.cellStyle.borders.all.lineStyle = LineStyle.thin;
        c.cellStyle.fontColor = '#263238';
      }

      final Range folioCell = sheet.getRangeByIndex(currentRow, 1);
      folioCell.setText(v.folio);
      applyStyle(folioCell);

      final Range fechaCell = sheet.getRangeByIndex(currentRow, 2);
      fechaCell.dateTime = v.fecha;
      fechaCell.numberFormat = 'dd/mm/yyyy hh:mm';
      applyStyle(fechaCell);

      final Range cajeroCell = sheet.getRangeByIndex(currentRow, 3);
      cajeroCell.setText(v.cajero);
      applyStyle(cajeroCell);

      final Range subtotalCell = sheet.getRangeByIndex(currentRow, 4);
      subtotalCell.setNumber(v.subtotal);
      subtotalCell.numberFormat = r'$#,##0.00';
      applyStyle(subtotalCell);

      final Range ivaCell = sheet.getRangeByIndex(currentRow, 5);
      ivaCell.setNumber(v.iva);
      ivaCell.numberFormat = r'$#,##0.00';
      applyStyle(ivaCell);

      final Range totalCell = sheet.getRangeByIndex(currentRow, 6);
      totalCell.setNumber(v.total);
      totalCell.numberFormat = r'$#,##0.00';
      applyStyle(totalCell);

      final Range metodoCell = sheet.getRangeByIndex(currentRow, 7);
      final String metodoNormalizado = v.metodoPago.trim().isEmpty
          ? 'Sin especificar'
          : v.metodoPago;
      metodoCell.setText(metodoNormalizado);
      applyStyle(metodoCell);

      final Range recetaCell = sheet.getRangeByIndex(currentRow, 8);
      final bool conReceta = v.cedulaMedico != null;
      recetaCell.setText(conReceta ? 'Si' : 'No');
      applyStyle(recetaCell);
      if (conReceta) {
        recetaCell.cellStyle.fontColor = '#B71C1C';
        recetaCell.cellStyle.bold = true;
      }

      currentRow++;
    }

    for (int c = 1; c <= 8; c++) {
      sheet.autoFitColumn(c);
    }

    // Ajustes de ancho para consistencia visual corporativa.
    sheet.getRangeByName('A1').columnWidth = 15;
    sheet.getRangeByName('B1').columnWidth = 20;
    sheet.getRangeByName('C1').columnWidth = 22;
    sheet.getRangeByName('D1').columnWidth = 14;
    sheet.getRangeByName('E1').columnWidth = 14;
    sheet.getRangeByName('F1').columnWidth = 14;
    sheet.getRangeByName('G1').columnWidth = 18;
    sheet.getRangeByName('H1').columnWidth = 16;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HOJA 3 · ANÁLISIS ESTADÍSTICO
  // ─────────────────────────────────────────────────────────────────────────
  void _buildAnalisisEstadistico({
    required Worksheet sheet,
    required List<_DiaStats> diasOrdenados,
    required int totalVentas,
  }) {
    sheet.showGridlines = false;

    // Encabezado de hoja A1:G2
    final Range sheetTitle = sheet.getRangeByName('A1:G2');
    sheetTitle.merge();
    sheetTitle.setText('ANALISIS ESTADISTICO — Farmacia POS AWOS');
    sheetTitle.cellStyle.backColor = '#004D40';
    sheetTitle.cellStyle.fontColor = _blanco;
    sheetTitle.cellStyle.bold = true;
    sheetTitle.cellStyle.hAlign = HAlignType.center;
    sheetTitle.cellStyle.vAlign = VAlignType.center;
    sheetTitle.cellStyle.fontSize = 14;

    // ── Sección 1: Análisis Financiero Diario ─────────────────────────────
    final Range section1Lbl = sheet.getRangeByName('A4:G4');
    section1Lbl.merge();
    section1Lbl.setText('ANALISIS FINANCIERO DIARIO');
    section1Lbl.cellStyle.bold = true;
    section1Lbl.cellStyle.fontSize = 12;
    section1Lbl.cellStyle.backColor = '#E0F2F1';
    section1Lbl.cellStyle.fontColor = '#00695C';
    section1Lbl.cellStyle.hAlign = HAlignType.center;

    const int dailyHeaderRow = 5;
    const int dailyDataStart = 6;
    const List<String> dailyHeaders = <String>[
      'Fecha',
      'Num. Ventas',
      'Subtotal',
      'IVA',
      'Total del Dia',
      'Venta Max.',
      'Venta Min.',
    ];

    for (int i = 0; i < dailyHeaders.length; i++) {
      final Range cell = sheet.getRangeByIndex(dailyHeaderRow, i + 1);
      cell.setText(dailyHeaders[i]);
      cell.cellStyle.backColor = '#00695C';
      cell.cellStyle.fontColor = _blanco;
      cell.cellStyle.bold = true;
      cell.cellStyle.hAlign = HAlignType.center;
      cell.cellStyle.borders.all.lineStyle = LineStyle.thin;
    }

    int currentRow = dailyDataStart;
    for (int idx = 0; idx < diasOrdenados.length; idx++) {
      final _DiaStats dia = diasOrdenados[idx];
      final String rowBg = idx.isEven ? _blanco : '#E0F7FA';

      void applyStyle(Range c) {
        c.cellStyle.backColor = rowBg;
        c.cellStyle.borders.all.lineStyle = LineStyle.thin;
      }

      final Range diaCell = sheet.getRangeByIndex(currentRow, 1);
      diaCell.setText(dia.dia);
      applyStyle(diaCell);

      final Range numCell = sheet.getRangeByIndex(currentRow, 2);
      numCell.setNumber(dia.numVentas.toDouble());
      numCell.numberFormat = '0';
      numCell.cellStyle.hAlign = HAlignType.center;
      applyStyle(numCell);

      final Range subtCell = sheet.getRangeByIndex(currentRow, 3);
      subtCell.setNumber(dia.subtotal);
      subtCell.numberFormat = r'$#,##0.00';
      applyStyle(subtCell);

      final Range ivaCell = sheet.getRangeByIndex(currentRow, 4);
      ivaCell.setNumber(dia.iva);
      ivaCell.numberFormat = r'$#,##0.00';
      applyStyle(ivaCell);

      final Range totalCell = sheet.getRangeByIndex(currentRow, 5);
      totalCell.setNumber(dia.total);
      totalCell.numberFormat = r'$#,##0.00';
      applyStyle(totalCell);

      final Range maxCell = sheet.getRangeByIndex(currentRow, 6);
      maxCell.setNumber(dia.safeMaxVenta);
      maxCell.numberFormat = r'$#,##0.00';
      applyStyle(maxCell);

      final Range minCell = sheet.getRangeByIndex(currentRow, 7);
      minCell.setNumber(dia.safeMinVenta);
      minCell.numberFormat = r'$#,##0.00';
      applyStyle(minCell);

      currentRow++;
    }

    // Rango efectivo de la columna "Total del Día" para fórmulas
    final int dailyDataEnd = diasOrdenados.isEmpty
        ? dailyDataStart
        : currentRow - 1;
    final String dailyTotalRange = 'E$dailyDataStart:E$dailyDataEnd';

    // ── Sección 2: Estadísticas globales con fórmulas nativas ─────────────
    final int statsSection = currentRow + 2;
    final Range section2Lbl = sheet.getRangeByName(
      'A$statsSection:G$statsSection',
    );
    section2Lbl.merge();
    section2Lbl.setText('ESTADISTICAS GLOBALES DEL PERIODO');
    section2Lbl.cellStyle.bold = true;
    section2Lbl.cellStyle.fontSize = 12;
    section2Lbl.cellStyle.backColor = '#FFF9C4';
    section2Lbl.cellStyle.fontColor = '#F57F17';
    section2Lbl.cellStyle.hAlign = HAlignType.center;

    final List<String> statsLabels = <String>[
      'Venta Maxima del Periodo',
      'Venta Minima del Periodo',
      'Promedio Diario de Ventas',
    ];
    final List<String> statsFormulas = <String>[
      '=MAX($dailyTotalRange)',
      '=MIN($dailyTotalRange)',
      '=AVERAGE($dailyTotalRange)',
    ];

    for (int i = 0; i < statsLabels.length; i++) {
      final int row = statsSection + 1 + i;

      final Range lbl = sheet.getRangeByIndex(row, 1);
      lbl.setText(statsLabels[i]);
      lbl.cellStyle.bold = true;
      lbl.cellStyle.backColor = '#FFFDE7';
      lbl.cellStyle.borders.all.lineStyle = LineStyle.thin;

      final Range val = sheet.getRangeByIndex(row, 2);
      if (diasOrdenados.isNotEmpty) {
        val.setFormula(statsFormulas[i]);
      } else {
        val.setNumber(0);
      }
      val.numberFormat = r'$#,##0.00';
      val.cellStyle.backColor = '#FFFDE7';
      val.cellStyle.borders.all.lineStyle = LineStyle.thin;
    }

    // ── Sección 3: Auditoría de retención de recetas médicas ──────────────
    final int recetasSection = statsSection + 5;
    final Range section3Lbl = sheet.getRangeByName(
      'A$recetasSection:G$recetasSection',
    );
    section3Lbl.merge();
    section3Lbl.setText('AUDITORIA DE RETENCION DE RECETAS MEDICAS');
    section3Lbl.cellStyle.bold = true;
    section3Lbl.cellStyle.fontSize = 12;
    section3Lbl.cellStyle.backColor = '#FCE4EC';
    section3Lbl.cellStyle.fontColor = '#880E4F';
    section3Lbl.cellStyle.hAlign = HAlignType.center;

    // Rango de "Receta Retenida" en Hoja 2 para las fórmulas COUNTIF
    final int sheet2DataStart = 5;
    final int sheet2DataEnd = totalVentas == 0
        ? sheet2DataStart
        : sheet2DataStart + totalVentas - 1;
    final String recetaRange =
        "'Datos Transaccionales'!H$sheet2DataStart:H$sheet2DataEnd";

    // Fila: Total de ventas
    _writeAuditRow(
      sheet: sheet,
      row: recetasSection + 1,
      label: 'Total de Ventas en el Periodo',
      bgColor: '#FAFAFA',
      number: totalVentas.toDouble(),
      numFormat: '0',
    );

    // Fila: Con receta — usa COUNTIF nativo de Excel
    _writeAuditRow(
      sheet: sheet,
      row: recetasSection + 2,
      label: 'Ventas con Receta Medica Retenida',
      bgColor: '#FCE4EC',
      formula: '=COUNTIF($recetaRange,"Si")',
      numFormat: '0',
    );

    // Fila: Sin receta
    _writeAuditRow(
      sheet: sheet,
      row: recetasSection + 3,
      label: 'Ventas sin Receta Medica',
      bgColor: '#F3E5F5',
      formula: '=COUNTIF($recetaRange,"No")',
      numFormat: '0',
    );

    // Fila: Porcentaje con receta
    final int pctRow = recetasSection + 4;
    final Range pctLbl = sheet.getRangeByIndex(pctRow, 1);
    pctLbl.setText('Porcentaje con Receta Medica');
    pctLbl.cellStyle.bold = true;
    pctLbl.cellStyle.backColor = '#EDE7F6';
    pctLbl.cellStyle.borders.all.lineStyle = LineStyle.thin;

    final Range pctVal = sheet.getRangeByIndex(pctRow, 2);
    pctVal.setFormula(
      '=IFERROR(B${recetasSection + 2}/B${recetasSection + 1},0)',
    );
    pctVal.numberFormat = '0.00%';
    pctVal.cellStyle.bold = true;
    pctVal.cellStyle.hAlign = HAlignType.center;
    pctVal.cellStyle.backColor = '#EDE7F6';
    pctVal.cellStyle.borders.all.lineStyle = LineStyle.thin;

    for (int c = 1; c <= 7; c++) {
      sheet.autoFitColumn(c);
    }
  }

  /// Escribe una fila en la tabla de auditoría de recetas.
  /// Acepta un [number] literal o una [formula] de Excel (mutuamente excluyentes).
  void _writeAuditRow({
    required Worksheet sheet,
    required int row,
    required String label,
    required String bgColor,
    required String numFormat,
    double? number,
    String? formula,
  }) {
    final Range lbl = sheet.getRangeByIndex(row, 1);
    lbl.setText(label);
    lbl.cellStyle.bold = true;
    lbl.cellStyle.backColor = bgColor;
    lbl.cellStyle.borders.all.lineStyle = LineStyle.thin;

    final Range val = sheet.getRangeByIndex(row, 2);
    if (formula != null) {
      val.setFormula(formula);
    } else {
      val.setNumber(number ?? 0);
    }
    val.numberFormat = numFormat;
    val.cellStyle.hAlign = HAlignType.center;
    val.cellStyle.backColor = bgColor;
    val.cellStyle.borders.all.lineStyle = LineStyle.thin;
  }

  // ─── SVG → PNG ────────────────────────────────────────────────────────────
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

// ─── Clase auxiliar: estadísticas agregadas por día ───────────────────────────
class _DiaStats {
  _DiaStats(this.dia);

  final String dia;
  int numVentas = 0;
  double subtotal = 0;
  double iva = 0;
  double total = 0;
  double _maxVenta = double.negativeInfinity;
  double _minVenta = double.infinity;

  void add(VentaReporte v) {
    numVentas++;
    subtotal += v.subtotal;
    iva += v.iva;
    total += v.total;
    if (v.total > _maxVenta) _maxVenta = v.total;
    if (v.total < _minVenta) _minVenta = v.total;
  }

  double get safeMaxVenta => numVentas > 0 ? _maxVenta : 0;
  double get safeMinVenta => numVentas > 0 ? _minVenta : 0;
}
