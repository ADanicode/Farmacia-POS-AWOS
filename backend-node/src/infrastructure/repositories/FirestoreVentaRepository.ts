/**
 * @fileoverview FirestoreVentaRepository - Persistencia de ventas en Firestore
 * Implementa IVentaRepository con operaciones CRUD y reportes
 * Colecciones: tickets_ventas, auditoria_recetas
 */

import { Firestore, Timestamp } from 'firebase-admin/firestore';
import { Venta, LineaVenta, Pago, TipoPago, DatosReceta } from '@domain/entities/Venta';
import {
  IVentaRepository,
  IFiltrosVenta,
  IPaginacionVentas,
  IAuditoriaVenta,
} from '@application/interfaces/IVentaRepository';

/**
 * Interfaz para documento Firestore de venta
 */
interface FirestoreVentaDoc {
  ventaId: string;
  usuarioId: string;
  lineas: Array<{
    codigoProducto: string;
    nombreProducto: string;
    cantidad: number;
    precioUnitario: number;
    esControlado: boolean;
    lote?: string;
  }>;
  pagos: Array<{
    tipo: TipoPago;
    monto: number;
    referencia?: string;
  }>;
  subtotal: number;
  iva: number;
  total: number;
  cambio: number;
  ivaPercentaje: number;
  datosReceta?: {
    ciMedico: string;
    nombreMedico: string;
    fechaReceta: Timestamp;
  };
  tieneProductosControlados: boolean;
  estado: string;
  fechaVenta: Timestamp;
  fechaCreacion: Timestamp;
  fechaActualizacion: Timestamp;
}

/**
 * FirestoreVentaRepository - Adaptador de persistencia para ventas
 * Responsabilidades:
 * - Crear y recuperar ventas (HU-28)
 * - Persistir auditoría de recetas (HU-30)
 * - Anular ventas con auditoría (HU-35)
 * - Generar reportes y estadísticas (HU-39)
 */
export class FirestoreVentaRepository implements IVentaRepository {
  private readonly firestore: Firestore;
  private readonly COLECCION_VENTAS = 'tickets_ventas';
  private readonly COLECCION_AUDITORIA = 'auditoria_recetas';

  constructor(firestore: Firestore) {
    this.firestore = firestore;
    console.log(`[FirestoreVentaRepository] Inicializado`);
  }

  /**
   * Crear una nueva venta (SAGA STEP 2)
   */
  public async crear(venta: Venta): Promise<Venta> {
    try {
      console.log(`[FirestoreVentaRepository] Creando venta ${venta.getId()}`);

      const doc: FirestoreVentaDoc = {
        ventaId: venta.getId(),
        usuarioId: venta.getUsuarioId(),
        lineas: venta.getLineas().map((l) => ({
          codigoProducto: l.getCodigoProducto(),
          nombreProducto: l.getNombreProducto(),
          cantidad: l.getCantidad(),
          precioUnitario: l.getPrecioUnitario(),
          esControlado: l.esProductoControlado(),
          lote: l.getLote(),
        })),
        pagos: venta.getPagos().map((p) => ({
          tipo: p.getTipo(),
          monto: p.getMonto(),
          referencia: p.getReferencia(),
        })),
        subtotal: venta.getSubtotal(),
        iva: venta.getIVA(),
        total: venta.getTotal(),
        cambio: venta.getCambio(),
        ivaPercentaje: 19,
        datosReceta: venta.getDatosReceta()
          ? {
              ciMedico: venta.getDatosReceta()!.getCiMedico(),
              nombreMedico: venta.getDatosReceta()!.getNombreMedico(),
              fechaReceta: Timestamp.fromDate(
                venta.getDatosReceta()!.getFechaReceta(),
              ),
            }
          : undefined,
        tieneProductosControlados: venta.getTieneProductosControlados(),
        estado: venta.getEstado(),
        fechaVenta: Timestamp.fromDate(venta.getFechaVenta()),
        fechaCreacion: Timestamp.now(),
        fechaActualizacion: Timestamp.now(),
      };

      await this.firestore
        .collection(this.COLECCION_VENTAS)
        .doc(venta.getId())
        .set(doc);

      console.log(
        `[FirestoreVentaRepository] ✅ Venta ${venta.getId()} persistida en Firestore`,
      );

      return venta;
    } catch (error: any) {
      console.error(
        `[FirestoreVentaRepository] Error creando venta: ${error.message}`,
      );
      throw new Error(`Error persistiendo venta: ${error.message}`);
    }
  }

  /**
   * Obtener venta por ID
   */
  public async obtenerPorId(ventaId: string): Promise<Venta> {
    try {
      const docSnapshot = await this.firestore
        .collection(this.COLECCION_VENTAS)
        .doc(ventaId)
        .get();

      if (!docSnapshot.exists) {
        throw new Error(`Venta ${ventaId} no encontrada`);
      }

      return this.mapearDocumentoAVenta(docSnapshot.data() as FirestoreVentaDoc);
    } catch (error: any) {
      console.error(
        `[FirestoreVentaRepository] Error obteniendo venta: ${error.message}`,
      );
      throw error;
    }
  }

  /**
   * Obtener ventas de un usuario (HU-35)
   */
  public async obtenerPorUsuario(
    usuarioId: string,
    filtros?: Partial<IFiltrosVenta>,
  ): Promise<Venta[]> {
    try {
      const limit = filtros?.limit || 50;
      const offset = filtros?.offset || 0;

      let query: any = this.firestore
        .collection(this.COLECCION_VENTAS)
        .where('usuarioId', '==', usuarioId)
        .orderBy('fechaVenta', 'desc');

      if (offset > 0) {
        query = query.offset(offset);
      }

      query = query.limit(limit);

      const snapshot = await query.get();
      return snapshot.docs.map((docSnapshot: any) =>
        this.mapearDocumentoAVenta(docSnapshot.data() as FirestoreVentaDoc),
      );
    } catch (error: any) {
      console.error(
        `[FirestoreVentaRepository] Error obteniendo ventas del usuario: ${error.message}`,
      );
      throw error;
    }
  }

  /**
   * Listar ventas con filtros
   */
  public async listar(filtros: IFiltrosVenta): Promise<IPaginacionVentas> {
    try {
      let query: any = this.firestore.collection(this.COLECCION_VENTAS);

      if (filtros.usuarioId) {
        query = query.where('usuarioId', '==', filtros.usuarioId);
      }

      if (filtros.estado) {
        query = query.where('estado', '==', filtros.estado);
      }

      if (filtros.fechaInicio) {
        query = query.where(
          'fechaVenta',
          '>=',
          Timestamp.fromDate(filtros.fechaInicio),
        );
      }

      if (filtros.fechaFin) {
        query = query.where(
          'fechaVenta',
          '<=',
          Timestamp.fromDate(filtros.fechaFin),
        );
      }

      query = query.orderBy('fechaVenta', 'desc');

      // Obtener total
      const totalSnapshot = await query.get();
      const total = totalSnapshot.docs.length;

      // Aplicar paginación
      const limit = filtros.limit || 50;
      const offset = filtros.offset || 0;
      const pagina = Math.floor(offset / limit) + 1;
      const paginas = Math.ceil(total / limit);

      let paginatedQuery = query.offset(offset).limit(limit);
      const snapshot = await paginatedQuery.get();

      return {
        ventas: snapshot.docs.map((docSnapshot: any) =>
          this.mapearDocumentoAVenta(docSnapshot.data() as FirestoreVentaDoc),
        ),
        total,
        pagina,
        paginas,
      };
    } catch (error: any) {
      console.error(
        `[FirestoreVentaRepository] Error listando ventas: ${error.message}`,
      );
      throw error;
    }
  }

  /**
   * Obtener ventas por período
   */
  public async obtenerPorPeriodo(
    fechaInicio: Date,
    fechaFin: Date,
  ): Promise<Venta[]> {
    try {
      const snapshot = await this.firestore
        .collection(this.COLECCION_VENTAS)
        .where('fechaVenta', '>=', Timestamp.fromDate(fechaInicio))
        .where('fechaVenta', '<=', Timestamp.fromDate(fechaFin))
        .orderBy('fechaVenta', 'asc')
        .get();

      return snapshot.docs.map((docSnapshot) =>
        this.mapearDocumentoAVenta(docSnapshot.data() as FirestoreVentaDoc),
      );
    } catch (error: any) {
      console.error(
        `[FirestoreVentaRepository] Error obteniendo ventas por período: ${error.message}`,
      );
      throw error;
    }
  }

  /**
   * Anular una venta (HU-35)
   */
  public async anular(
    ventaId: string,
    razon: string,
    usuarioId: string,
  ): Promise<Venta> {
    try {
      console.log(
        `[FirestoreVentaRepository] Anulando venta ${ventaId} por: ${razon}`,
      );

      const ventaDocSnapshot = await this.firestore
        .collection(this.COLECCION_VENTAS)
        .doc(ventaId)
        .get();

      if (!ventaDocSnapshot.exists) {
        throw new Error(`Venta ${ventaId} no encontrada`);
      }

      await this.firestore
        .collection(this.COLECCION_VENTAS)
        .doc(ventaId)
        .update({
          estado: 'anulada',
          razonAnulacion: razon,
          usuarioAnulacion: usuarioId,
          fechaAnulacion: Timestamp.now(),
          fechaActualizacion: Timestamp.now(),
        });

      return this.mapearDocumentoAVenta(ventaDocSnapshot.data() as FirestoreVentaDoc);
    } catch (error: any) {
      console.error(
        `[FirestoreVentaRepository] Error anulando venta: ${error.message}`,
      );
      throw error;
    }
  }

  /**
   * Registrar auditoría de producto controlado (HU-30)
   */
  public async registrarRecetaControlada(
    ventaId: string,
    datosReceta: { ciMedico: string; nombreMedico: string; fechaReceta: Date },
    productosControlados: Array<{
      codigo: string;
      nombre: string;
      cantidad: number;
      lote: string;
    }>,
  ): Promise<string> {
    try {
      console.log(
        `[FirestoreVentaRepository] Registrando auditoría de receta para venta ${ventaId}`,
      );

      const docRef = await this.firestore
        .collection(this.COLECCION_AUDITORIA)
        .add({
          ventaId,
          datosReceta: {
            ciMedico: datosReceta.ciMedico,
            nombreMedico: datosReceta.nombreMedico,
            fechaReceta: Timestamp.fromDate(datosReceta.fechaReceta),
          },
          productosControlados,
          fechaRegistro: Timestamp.now(),
        });

      console.log(
        `[FirestoreVentaRepository] ✅ Auditoría de receta registrada para venta ${ventaId}`,
      );

      return docRef.id;
    } catch (error: any) {
      console.error(
        `[FirestoreVentaRepository] Error registrando auditoría: ${error.message}`,
      );
      throw error;
    }
  }

  /**
   * Obtener auditoría de recetas
   */
  public async obtenerAuditoriaRecetas(
    filtros?: Partial<{
      fechaInicio: Date;
      fechaFin: Date;
      ciMedico: string;
      limit: number;
      offset: number;
    }>,
  ): Promise<any[]> {
    try {
      let query: any = this.firestore.collection(this.COLECCION_AUDITORIA);

      if (filtros?.fechaInicio) {
        query = query.where(
          'fechaRegistro',
          '>=',
          Timestamp.fromDate(filtros.fechaInicio),
        );
      }

      if (filtros?.fechaFin) {
        query = query.where(
          'fechaRegistro',
          '<=',
          Timestamp.fromDate(filtros.fechaFin),
        );
      }

      query = query.orderBy('fechaRegistro', 'desc');

      if (filtros?.limit) {
        query = query.limit(filtros.limit);
      }

      const snapshot = await query.get();
      return snapshot.docs.map((docSnapshot: any) => docSnapshot.data());
    } catch (error: any) {
      console.error(
        `[FirestoreVentaRepository] Error obteniendo auditoría: ${error.message}`,
      );
      throw error;
    }
  }

  /**
   * Obtener ventas por lote FEFO (HU-31, HU-40)
   */
  public async obtenerPorLote(lote: string): Promise<Venta[]> {
    try {
      const snapshot = await this.firestore
        .collection(this.COLECCION_VENTAS)
        .where('lineas', 'array-contains', { lote })
        .get();

      return snapshot.docs.map((docSnapshot) =>
        this.mapearDocumentoAVenta(docSnapshot.data() as FirestoreVentaDoc),
      );
    } catch (error: any) {
      console.error(
        `[FirestoreVentaRepository] Error obteniendo ventas por lote: ${error.message}`,
      );
      throw error;
    }
  }

  /**
   * Registrar auditoría de operación
   */
  public async registrarAuditoria(auditoria: IAuditoriaVenta): Promise<string> {
    try {
      const docRef = await this.firestore.collection('auditoria_operaciones').add({
        ventaId: auditoria.ventaId,
        tipo: auditoria.tipo,
        usuarioId: auditoria.usuarioId,
        cambios: auditoria.cambios,
        razon: auditoria.razon,
        timestamp: Timestamp.fromDate(auditoria.timestamp),
      });

      return docRef.id;
    } catch (error: any) {
      console.error(
        `[FirestoreVentaRepository] Error registrando auditoría: ${error.message}`,
      );
      throw error;
    }
  }

  /**
   * Obtener estadísticas de ventas (HU-39)
   */
  public async obtenerEstadisticas(
    fechaInicio: Date,
    fechaFin: Date,
  ): Promise<{
    totalVentas: number;
    cantidadVentas: number;
    ticketPromedio: number;
    ventasMayoreMenor: { mayor: Venta; menor: Venta };
    ventasPorMetodo: Record<string, number>;
  }> {
    try {
      const ventas = await this.obtenerPorPeriodo(fechaInicio, fechaFin);

      if (ventas.length === 0) {
        return {
          totalVentas: 0,
          cantidadVentas: 0,
          ticketPromedio: 0,
          ventasMayoreMenor: { mayor: ventas[0], menor: ventas[0] },
          ventasPorMetodo: {},
        };
      }

      const totalVentas = ventas.reduce((sum, v) => sum + v.getTotal(), 0);
      const ventasOrdenadas = ventas.sort(
        (a, b) => a.getTotal() - b.getTotal(),
      );

      const ventasPorMetodo: Record<string, number> = {};
      ventas.forEach((v) => {
        v.getPagos().forEach((p) => {
          const tipo = p.getTipo();
          ventasPorMetodo[tipo] = (ventasPorMetodo[tipo] || 0) + p.getMonto();
        });
      });

      return {
        totalVentas,
        cantidadVentas: ventas.length,
        ticketPromedio: totalVentas / ventas.length,
        ventasMayoreMenor: {
          mayor: ventasOrdenadas[ventasOrdenadas.length - 1],
          menor: ventasOrdenadas[0],
        },
        ventasPorMetodo,
      };
    } catch (error: any) {
      console.error(
        `[FirestoreVentaRepository] Error obteniendo estadísticas: ${error.message}`,
      );
      throw error;
    }
  }

  /**
   * Verificar si venta existe
   */
  public async existe(ventaId: string): Promise<boolean> {
    try {
      const docSnapshot = await this.firestore
        .collection(this.COLECCION_VENTAS)
        .doc(ventaId)
        .get();
      return docSnapshot.exists;
    } catch (error: any) {
      console.error(
        `[FirestoreVentaRepository] Error verificando existencia: ${error.message}`,
      );
      return false;
    }
  }

  /**
   * Mapear documento Firestore a entidad Venta
   */
  private mapearDocumentoAVenta(doc: FirestoreVentaDoc): Venta {
    const lineas = doc.lineas.map(
      (l) =>
        new LineaVenta(
          l.codigoProducto,
          l.nombreProducto,
          l.cantidad,
          l.precioUnitario,
          l.esControlado,
          l.lote,
        ),
    );

    const pagos = doc.pagos.map(
      (p) => new Pago(p.tipo, p.monto, p.referencia),
    );

    let datosReceta: DatosReceta | undefined;
    if (doc.datosReceta) {
      datosReceta = new DatosReceta(
        doc.datosReceta.ciMedico,
        doc.datosReceta.nombreMedico,
        doc.datosReceta.fechaReceta.toDate(),
      );
    }

    return Venta.desdeFirestore({
      id: doc.ventaId,
      usuarioId: doc.usuarioId,
      lineas: lineas.map((l) => ({
        codigoProducto: l.getCodigoProducto(),
        nombreProducto: l.getNombreProducto(),
        cantidad: l.getCantidad(),
        precioUnitario: l.getPrecioUnitario(),
        esControlado: l.esProductoControlado(),
        lote: l.getLote(),
      })),
      pagos: pagos.map((p) => ({
        tipo: p.getTipo(),
        monto: p.getMonto(),
        referencia: p.getReferencia(),
      })),
      subtotal: doc.subtotal,
      iva: doc.iva,
      total: doc.total,
      cambio: doc.cambio,
      estado: doc.estado,
      datosReceta: datosReceta
        ? {
            ciMedico: datosReceta.getCiMedico(),
            nombreMedico: datosReceta.getNombreMedico(),
            fechaReceta: datosReceta.getFechaReceta(),
          }
        : undefined,
    });
  }
}
