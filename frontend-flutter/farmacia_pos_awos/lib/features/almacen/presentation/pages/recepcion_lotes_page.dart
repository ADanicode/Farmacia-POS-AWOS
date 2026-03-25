import 'package:flutter/material.dart';

import '../../../../core/di/injection_container.dart';
import '../../../pos/data/repositories/catalogo_repository.dart';
import '../../../pos/domain/entities/medicamento.dart';
import '../../data/repositories/almacen_repository.dart';
import '../../domain/entities/lote_riesgo.dart';

/// Pantalla de almacén para ingreso de lotes y monitor de caducidades.
class RecepcionLotesPage extends StatefulWidget {
  /// Constructor por defecto.
  const RecepcionLotesPage({super.key});

  @override
  State<RecepcionLotesPage> createState() => _RecepcionLotesPageState();
}

class _RecepcionLotesPageState extends State<RecepcionLotesPage> {
  final CatalogoRepository _catalogoRepository = sl<CatalogoRepository>();
  final AlmacenRepository _almacenRepository = sl<AlmacenRepository>();

  final TextEditingController _buscarMedicamentoController =
      TextEditingController();
  final TextEditingController _numeroLoteController = TextEditingController();
  final TextEditingController _stockController = TextEditingController();

  List<Medicamento> _catalogo = <Medicamento>[];
  int? _medicamentoIdSeleccionado;
  DateTime? _fechaCaducidad;
  bool _guardando = false;

  Future<List<LoteRiesgo>>? _riesgosFuture;

  @override
  void initState() {
    super.initState();
    _cargarCatalogo();
    _riesgosFuture = _almacenRepository.obtenerLotesProximosCaducar();
  }

  @override
  void dispose() {
    _buscarMedicamentoController.dispose();
    _numeroLoteController.dispose();
    _stockController.dispose();
    super.dispose();
  }

  Future<void> _cargarCatalogo() async {
    final List<Medicamento> catalogo = await _catalogoRepository
        .obtenerCatalogoCacheado();
    if (!mounted) {
      return;
    }
    setState(() {
      _catalogo = catalogo;
    });
  }

  List<Medicamento> _catalogoFiltrado() {
    final String query = _buscarMedicamentoController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return _catalogo;
    }

    return _catalogo
        .where(
          (Medicamento med) =>
              med.nombre.toLowerCase().contains(query) ||
              med.codigoBarras.toLowerCase().contains(query),
        )
        .toList(growable: false);
  }

  DateTime get _manana {
    final DateTime hoy = DateTime.now();
    return DateTime(hoy.year, hoy.month, hoy.day).add(const Duration(days: 1));
  }

  Future<void> _seleccionarFecha() async {
    final DateTime manana = _manana;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fechaCaducidad ?? manana,
      firstDate: manana,
      lastDate: DateTime(manana.year + 10),
      selectableDayPredicate: (DateTime day) {
        final DateTime normalized = DateTime(day.year, day.month, day.day);
        return normalized.isAfter(DateTime.now()) &&
            !normalized.isBefore(manana);
      },
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _fechaCaducidad = DateTime(picked.year, picked.month, picked.day);
    });
  }

  String _formatDate(DateTime value) {
    final String month = value.month.toString().padLeft(2, '0');
    final String day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  Future<void> _guardarLote() async {
    final int? medicamentoId = _medicamentoIdSeleccionado;
    final String numeroLote = _numeroLoteController.text.trim();
    final int? stock = int.tryParse(_stockController.text.trim());
    final DateTime? fecha = _fechaCaducidad;

    if (medicamentoId == null ||
        numeroLote.isEmpty ||
        stock == null ||
        stock <= 0 ||
        fecha == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Completa todos los campos obligatorios.'),
        ),
      );
      return;
    }

    setState(() {
      _guardando = true;
    });

    try {
      await _almacenRepository.registrarLote(
        medicamentoId: medicamentoId,
        numeroLote: numeroLote,
        fechaCaducidad: _formatDate(fecha),
        stockActual: stock,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lote guardado correctamente.')),
      );

      setState(() {
        _numeroLoteController.clear();
        _stockController.clear();
        _fechaCaducidad = null;
      });

      _refrescarRiesgos();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al guardar lote: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _guardando = false;
        });
      }
    }
  }

  Future<void> _refrescarRiesgos() async {
    setState(() {
      _riesgosFuture = _almacenRepository.obtenerLotesProximosCaducar();
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Medicamento> filtrados = _catalogoFiltrado();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Módulo de Almacén'),
          bottom: const TabBar(
            tabs: <Widget>[
              Tab(text: 'Ingreso de Lotes', icon: Icon(Icons.add_box_outlined)),
              Tab(text: 'Monitor de Riesgos', icon: Icon(Icons.warning_amber)),
            ],
          ),
        ),
        body: TabBarView(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: <Widget>[
                  const Text(
                    'Registrar lote',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _buscarMedicamentoController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Buscar medicamento',
                      hintText: 'Nombre o código de barras',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    initialValue:
                        filtrados.any(
                          (Medicamento med) =>
                              med.id == _medicamentoIdSeleccionado,
                        )
                        ? _medicamentoIdSeleccionado
                        : null,
                    items: filtrados
                        .map(
                          (Medicamento med) => DropdownMenuItem<int>(
                            value: med.id,
                            child: Text(
                              '${med.nombre} (${med.codigoBarras})',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (int? value) {
                      setState(() {
                        _medicamentoIdSeleccionado = value;
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Medicamento',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _numeroLoteController,
                    decoration: const InputDecoration(
                      labelText: 'Número de Lote',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _stockController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Cantidad / Stock',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _seleccionarFecha,
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      _fechaCaducidad == null
                          ? 'Seleccionar fecha de caducidad'
                          : 'Caduca: ${_formatDate(_fechaCaducidad!)}',
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Regla: solo se permite desde mañana en adelante.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _guardando ? null : _guardarLote,
                    icon: _guardando
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(_guardando ? 'Guardando...' : 'Guardar'),
                  ),
                ],
              ),
            ),
            RefreshIndicator(
              onRefresh: _refrescarRiesgos,
              child: FutureBuilder<List<LoteRiesgo>>(
                future: _riesgosFuture,
                builder:
                    (
                      BuildContext context,
                      AsyncSnapshot<List<LoteRiesgo>> snapshot,
                    ) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return ListView(
                          children: <Widget>[
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'Error al cargar riesgos: ${snapshot.error}',
                              ),
                            ),
                          ],
                        );
                      }

                      final List<LoteRiesgo> lotes =
                          snapshot.data ?? <LoteRiesgo>[];
                      if (lotes.isEmpty) {
                        return ListView(
                          children: const <Widget>[
                            Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('No hay lotes próximos a caducar.'),
                            ),
                          ],
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: lotes.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (BuildContext context, int index) {
                          final LoteRiesgo lote = lotes[index];
                          final ({Color color, IconData icono}) estilo =
                              _estiloRiesgo(lote.nivelRiesgo);

                          return Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: estilo.color, width: 2),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      Icon(estilo.icono, color: estilo.color),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          lote.medicamentoNombre,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      Chip(
                                        backgroundColor: estilo.color
                                            .withValues(alpha: 0.15),
                                        label: Text(lote.nivelRiesgo),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text('Lote: ${lote.numeroLote}'),
                                  Text('Código: ${lote.codigoBarras}'),
                                  Text('Caduca: ${lote.fechaCaducidad}'),
                                  Text('Días restantes: ${lote.diasRestantes}'),
                                  Text('Stock actual: ${lote.stockActual}'),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
              ),
            ),
          ],
        ),
      ),
    );
  }

  ({Color color, IconData icono}) _estiloRiesgo(String nivel) {
    switch (nivel.toUpperCase()) {
      case 'CRITICO':
        return (color: Colors.red, icono: Icons.dangerous);
      case 'URGENTE':
        return (color: Colors.orange, icono: Icons.warning_amber);
      case 'ALERTA':
      default:
        return (color: Colors.amber.shade700, icono: Icons.info_outline);
    }
  }
}
