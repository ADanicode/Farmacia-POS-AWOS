/**
 * @fileoverview FirestoreVentaRepository - Persistencia de ventas en Firestore
 * Implementa IVentaRepository con operaciones CRUD y reportes
 * Blindado contra errores de 'undefined' para compatibilidad con Google Cloud.
 */

import { Firestore, Timestamp } from 'firebase-admin/firestore';
import { Venta, LineaVenta, Pago, TipoPago, DatosReceta } from '@domain/entities/Venta';
import {
  IVentaRepository,
  IFiltrosVenta,
  IPaginacionVentas,
  IAuditoriaVenta,
} from '@application/interfaces/IVentaRepository';

export class FirestoreVentaRepository implements IVentaRepository {
  private readonly firestore: Firestore;
  private readonly COLECCION_VENTAS = 'tickets_ventas';
  private readonly COLECCION_AUDITORIA = 'auditoria_recetas';

  constructor(firestore: Firestore) {
    this.firestore = firestore;
    console.log(`[FirestoreVentaRepository] Inicializado`);
  }

  /**
   * Crear una nueva venta (HU-28)
   * Limpia dinámicamente campos opcionales para evitar errores de Firestore
   */
  public async crear(venta: Venta): Promise<Venta> {
    try {
      console.log(`[FirestoreVentaRepository] Creando venta ${venta.getId()}`);

      // 1. Construimos el objeto base con campos obligatorios
      const doc: any = {
        ventaId: venta.getId(),
        usuarioId: venta.getUsuarioId(),
        lineas: venta.getLineas().map((l) => ({
          codigoProducto: l.getCodigoProducto(),
          nombreProducto: l.getNombreProducto(),
          cantidad: l.getCantidad(),
          precioUnitario: l.getPrecioUnitario(),
          esControlado: l.esProductoControlado(),
          lote: l.getLote() || "", // Evita undefined
        })),
        pagos: venta.getPagos().map((p) => ({
          tipo: p.getTipo(),
          monto: p.getMonto(),
          referencia: p.getReferencia() || "", // Evita undefined
        })),
        subtotal: venta.getSubtotal(),
        iva: venta.getIVA(),
        total: venta.getTotal(),
        cambio: venta.getCambio(),
        ivaPercentaje: 16, 
        tieneProductosControlados: venta.getTieneProductosControlados(),
        estado: venta.getEstado(),
        fechaVenta: Timestamp.fromDate(venta.getFechaVenta()),
        fechaCreacion: Timestamp.now(),
        fechaActualizacion: Timestamp.now(),
      };

      // 2. Solo agregamos datosReceta si realmente existen (Bypass de undefined)
      const receta = venta.getDatosReceta();
      if (receta) {
        doc.datosReceta = {
          ciMedico: receta.getCiMedico(),
          nombreMedico: receta.getNombreMedico(),
          fechaReceta: Timestamp.fromDate(receta.getFechaReceta()),
        };
      }

      // 3. Persistencia física en la nube
      await this.firestore
        .collection(this.COLECCION_VENTAS)
        .doc(venta.getId())
        .set(doc);

      console.log(`\x1b[32m%s\x1b[0m`, `[FirestoreVentaRepository] ✅ Venta ${venta.getId()} persistida en la nube`);

      return venta;
    } catch (error: any) {
      console.error(`[FirestoreVentaRepository] Error: ${error.message}`);
      throw new Error(`Error persistiendo venta: ${error.message}`);
    }
  }

  public async obtenerPorId(ventaId: string): Promise<Venta> {
    const docSnapshot = await this.firestore.collection(this.COLECCION_VENTAS).doc(ventaId).get();
    if (!docSnapshot.exists) throw new Error(`Venta ${ventaId} no encontrada`);
    return this.mapearDocumentoAVenta(docSnapshot.data() as any);
  }

  public async obtenerPorUsuario(usuarioId: string, filtros?: any): Promise<Venta[]> {
    const snapshot = await this.firestore
      .collection(this.COLECCION_VENTAS)
      .where('usuarioId', '==', usuarioId)
      .orderBy('fechaVenta', 'desc')
      .limit(filtros?.limit || 50)
      .get();
    return snapshot.docs.map(doc => this.mapearDocumentoAVenta(doc.data() as any));
  }

  public async anular(ventaId: string, razon: string, usuarioId: string): Promise<Venta> {
    await this.firestore.collection(this.COLECCION_VENTAS).doc(ventaId).update({
      estado: 'anulada',
      razonAnulacion: razon,
      usuarioAnulacion: usuarioId,
      fechaAnulacion: Timestamp.now(),
      fechaActualizacion: Timestamp.now(),
    });
    return this.obtenerPorId(ventaId);
  }

  public async registrarRecetaControlada(ventaId: string, datosReceta: any, productos: any[]): Promise<string> {
    const docRef = await this.firestore.collection(this.COLECCION_AUDITORIA).add({
      ventaId,
      datosReceta: { ...datosReceta, fechaReceta: Timestamp.fromDate(datosReceta.fechaReceta) },
      productosControlados: productos,
      fechaRegistro: Timestamp.now(),
    });
    return docRef.id;
  }

  public async existe(ventaId: string): Promise<boolean> {
    const doc = await this.firestore.collection(this.COLECCION_VENTAS).doc(ventaId).get();
    return doc.exists;
  }

  // --- Métodos de Reportes ---
  public async listar(filtros: any): Promise<any> { return { ventas: [], total: 0 }; }
  public async obtenerPorPeriodo(inicio: Date, fin: Date): Promise<Venta[]> { return []; }
  public async obtenerAuditoriaRecetas(filtros?: any): Promise<any[]> { return []; }
  public async obtenerPorLote(lote: string): Promise<Venta[]> { return []; }
  public async registrarAuditoria(auditoria: any): Promise<string> { return ""; }
  public async obtenerEstadisticas(inicio: Date, fin: Date): Promise<any> { return {}; }

  private mapearDocumentoAVenta(doc: any): Venta {
    const lineas = doc.lineas.map((l: any) => new LineaVenta(l.codigoProducto, l.nombreProducto, l.cantidad, l.precioUnitario, l.esControlado, l.lote));
    const pagos = doc.pagos.map((p: any) => new Pago(p.tipo, p.monto, p.referencia));
    return Venta.desdeFirestore({ ...doc, id: doc.ventaId, lineas, pagos, 
        datosReceta: doc.datosReceta ? { ...doc.datosReceta, fechaReceta: doc.datosReceta.fechaReceta.toDate() } : undefined 
    });
  }
}