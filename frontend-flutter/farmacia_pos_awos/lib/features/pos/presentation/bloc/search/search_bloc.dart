import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:stream_transform/stream_transform.dart';

import '../../../data/repositories/catalogo_repository.dart';
import '../../../domain/entities/medicamento.dart';
import '../../../domain/entities/medicamento_stock.dart';
import 'search_event.dart';
import 'search_state.dart';

/// BLoC de búsqueda de medicamentos para el módulo POS.
class SearchBloc extends Bloc<SearchEvent, SearchState> {
  /// Repositorio para consultar catálogo remoto.
  final CatalogoRepository _catalogoRepository;

  /// Constructor principal del SearchBloc.
  SearchBloc({required CatalogoRepository catalogoRepository})
    : _catalogoRepository = catalogoRepository,
      super(SearchState.initial()) {
    // PATRON: DEBOUNCE - Evita ráfagas de llamadas HTTP al tipear.
    // CUMPLE HU-17: BUSQUEDA EN MOSTRADOR (ALTA VELOCIDAD).
    on<SearchQueryChanged>(
      _onQueryChanged,
      transformer: _debounce(const Duration(milliseconds: 300)),
    );

    // Precarga del catálogo al iniciar para eliminar roundtrip por tecla.
    _catalogoRepository.obtenerCatalogoCacheado();
  }

  /// Crea un transformador debounce para eventos de texto de búsqueda.
  EventTransformer<T> _debounce<T>(Duration duration) {
    return (Stream<T> events, EventMapper<T> mapper) {
      return events.debounce(duration).asyncExpand(mapper);
    };
  }

  /// Maneja el cambio de query y filtra catálogo local cacheado.
  Future<void> _onQueryChanged(
    SearchQueryChanged event,
    Emitter<SearchState> emit,
  ) async {
    if (!_catalogoRepository.tieneCatalogoEnMemoria) {
      emit(
        state.copyWith(
          status: SearchStatus.loading,
          query: event.query,
          errorMessage: null,
        ),
      );
    }

    try {
      final List<Medicamento> resultados = await _catalogoRepository
          .buscarEnCache(event.query);

      emit(
        state.copyWith(
          status: SearchStatus.success,
          query: event.query,
          resultados: resultados,
          stockPorMedicamento: state.stockPorMedicamento,
          errorMessage: null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: SearchStatus.failure,
          query: event.query,
          resultados: const <Medicamento>[],
          stockPorMedicamento: <int, MedicamentoStock>{},
          errorMessage: e.toString(),
        ),
      );
    }
  }
}
