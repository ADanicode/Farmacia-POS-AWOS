import 'package:equatable/equatable.dart';

import '../../../domain/entities/medicamento.dart';
import '../../../domain/entities/medicamento_stock.dart';

/// Estado de carga para la búsqueda de medicamentos.
enum SearchStatus {
  /// Estado inicial sin resultados todavía.
  initial,

  /// Estado mientras se consulta el backend.
  loading,

  /// Estado cuando se obtuvo respuesta correcta.
  success,

  /// Estado cuando ocurrió un error.
  failure,
}

/// Estado inmutable del SearchBloc.
class SearchState extends Equatable {
  /// Estado de procesamiento actual.
  final SearchStatus status;

  /// Texto actual de la búsqueda.
  final String query;

  /// Resultados de catálogo obtenidos.
  final List<Medicamento> resultados;

  /// Mensaje de error para mostrar en UI.
  final String? errorMessage;

  /// Stock disponible por medicamento (id -> stock/lote FEFO).
  final Map<int, MedicamentoStock> stockPorMedicamento;

  /// Constructor principal del estado de búsqueda.
  const SearchState({
    required this.status,
    required this.query,
    required this.resultados,
    required this.stockPorMedicamento,
    this.errorMessage,
  });

  /// Crea el estado inicial del SearchBloc.
  factory SearchState.initial() {
    return const SearchState(
      status: SearchStatus.initial,
      query: '',
      resultados: <Medicamento>[],
      stockPorMedicamento: <int, MedicamentoStock>{},
      errorMessage: null,
    );
  }

  /// Crea una copia del estado actual con cambios puntuales.
  SearchState copyWith({
    SearchStatus? status,
    String? query,
    List<Medicamento>? resultados,
    Map<int, MedicamentoStock>? stockPorMedicamento,
    String? errorMessage,
  }) {
    return SearchState(
      status: status ?? this.status,
      query: query ?? this.query,
      resultados: resultados ?? this.resultados,
      stockPorMedicamento: stockPorMedicamento ?? this.stockPorMedicamento,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    status,
    query,
    resultados,
    stockPorMedicamento,
    errorMessage,
  ];
}
