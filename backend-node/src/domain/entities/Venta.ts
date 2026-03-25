/**
 * @fileoverview Entidades de Venta - Parte de la Capa de Dominio
 * Representa una transacción de venta con soporte para Pago Mixto y Productos Controlados
 */

/**
 * Enum de tipos de pago (HU-25, HU-26, HU-27)
 */
export enum TipoPago {
  EFECTIVO = 'efectivo',
  TARJETA = 'tarjeta',
  MIXTO = 'mixto',
}

/**
 * Value Object: Representa un método de pago individual
 * Se utiliza en array para soportar Pago Mixto (HU-27)
 */
export class Pago {
  /**
   * Tipo de pago (efectivo, tarjeta)
   */
  private readonly tipo: TipoPago;

  /**
   * Monto pagado en este método
   */
  private readonly monto: number;

  /**
   * Referencia de transacción (ej. recibo de tarjeta, número de talonario)
   */
  private readonly referencia?: string;

  constructor(tipo: TipoPago, monto: number, referencia?: string) {
    if (monto <= 0) {
      throw new Error('Monto de pago debe ser mayor a 0');
    }
    this.tipo = tipo;
    this.monto = monto;
    this.referencia = referencia;
  }

  public getTipo(): TipoPago {
    return this.tipo;
  }

  public getMonto(): number {
    return this.monto;
  }

  public getReferencia(): string | undefined {
    return this.referencia;
  }

  public toJSON(): Record<string, any> {
    return {
      tipo: this.tipo,
      monto: this.monto,
      referencia: this.referencia || null,
    };
  }
}

/**
 * Value Object: Representa los datos del médico para productos controlados (HU-22, HU-23)
 * Obligatorio capturar cuando la venta incluya medicamentos controlados
 */
export class DatosReceta {
  /**
   * Cédula de identidad del médico prescriptor
   */
  private readonly ciMedico: string;

  /**
   * Nombre completo del médico prescriptor
   */
  private readonly nombreMedico: string;

  /**
   * Fecha de emisión de la receta
   */
  private readonly fechaReceta: Date;

  constructor(ciMedico: string, nombreMedico: string, fechaReceta: Date) {
    if (!ciMedico || ciMedico.trim() === '') {
      throw new Error('CI del médico es obligatorio');
    }
    if (!nombreMedico || nombreMedico.trim() === '') {
      throw new Error('Nombre del médico es obligatorio');
    }
    this.ciMedico = ciMedico;
    this.nombreMedico = nombreMedico;
    this.fechaReceta = fechaReceta;
  }

  public getCiMedico(): string {
    return this.ciMedico;
  }

  public getNombreMedico(): string {
    return this.nombreMedico;
  }

  public getFechaReceta(): Date {
    return new Date(this.fechaReceta);
  }

  public toJSON(): Record<string, any> {
    return {
      ciMedico: this.ciMedico,
      nombreMedico: this.nombreMedico,
      fechaReceta: this.fechaReceta.toISOString(),
    };
  }
}

/**
 * Value Object: Representa una línea de venta (producto + cantidad)
 */
export class LineaVenta {
  /**
   * Código de barras del producto
   */
  private readonly codigoProducto: string;

  /**
   * Nombre del producto
   */
  private readonly nombreProducto: string;

  /**
   * Cantidad solicitada
   */
  private readonly cantidad: number;

  /**
   * Precio unitario sin IVA
   */
  private readonly precioUnitario: number;

  /**
   * Subtotal de la línea (cantidad * precioUnitario) sin IVA
   */
  private readonly subtotal: number;

  /**
   * Indica si el producto es controlado (requiere receta)
   */
  private readonly esControlado: boolean;

  /**
   * Lote del medicamento (rastreabilidad FEFO)
   */
  private readonly lote?: string;

  constructor(
    codigoProducto: string,
    nombreProducto: string,
    cantidad: number,
    precioUnitario: number,
    esControlado: boolean = false,
    lote?: string,
  ) {
    if (cantidad <= 0) {
      throw new Error('Cantidad debe ser mayor a 0');
    }
    if (precioUnitario < 0) {
      throw new Error('Precio unitario no puede ser negativo');
    }
    this.codigoProducto = codigoProducto;
    this.nombreProducto = nombreProducto;
    this.cantidad = cantidad;
    this.precioUnitario = precioUnitario;
    this.subtotal = cantidad * precioUnitario;
    this.esControlado = esControlado;
    this.lote = lote;
  }

  public getCodigoProducto(): string {
    return this.codigoProducto;
  }

  public getNombreProducto(): string {
    return this.nombreProducto;
  }

  public getCantidad(): number {
    return this.cantidad;
  }

  public getPrecioUnitario(): number {
    return this.precioUnitario;
  }

  public getSubtotal(): number {
    return this.subtotal;
  }

  public esProductoControlado(): boolean {
    return this.esControlado;
  }

  public getLote(): string | undefined {
    return this.lote;
  }

  public toJSON(): Record<string, any> {
    return {
      codigoProducto: this.codigoProducto,
      nombreProducto: this.nombreProducto,
      cantidad: this.cantidad,
      precioUnitario: this.precioUnitario,
      subtotal: this.subtotal,
      esControlado: this.esControlado,
      lote: this.lote || null,
    };
  }
}

/**
 * Clase Venta - Entidad de Dominio Principal
 * Representa una transacción de venta completa con orquestación Saga Pattern
 * Soporta: Pago Mixto (HU-27), Productos Controlados (HU-22-23), Auditoría
 */
export class Venta {
  /**
   * Identificador único de la venta (folio)
   */
  private readonly id: string;

  /**
   * Usuario que realizó la venta
   */
  private readonly usuarioId: string;

  /**
   * Array de líneas de venta (productos)
   */
  private readonly lineas: LineaVenta[];

  /**
   * Array de métodos de pago (HU-27: Pago Mixto)
   */
  private readonly pagos: Pago[];

  /**
   * Datos de receta médica si hay productos controlados (HU-23)
   */
  private readonly datosReceta?: DatosReceta;

  /**
   * Subtotal sin IVA
   */
  private readonly subtotal: number;

  /**
   * Valor del IVA (HU-17: cálculo dinámico)
   */
  private readonly iva: number;

  /**
   * Total con IVA
   */
  private readonly total: number;

  /**
   * Cambio entregado (si hay pago en efectivo)
   */
  private readonly cambio: number;

  /**
   * Fecha y hora de la venta
   */
  private readonly fechaVenta: Date;

  /**
   * Indica si hay productos controlados
   */
  private readonly tieneProductosControlados: boolean;

  /**
   * Estado de la venta (pendiente, procesada, anulada)
   */
  private estado: 'pendiente' | 'procesada' | 'anulada';

  /**
   * Constructor privado para forzar uso de factory methods
   */
  private constructor(
    id: string,
    usuarioId: string,
    lineas: LineaVenta[],
    pagos: Pago[],
    subtotal: number,
    iva: number,
    total: number,
    cambio: number,
    estado: 'pendiente' | 'procesada' | 'anulada' = 'pendiente',
    datosReceta?: DatosReceta,
    fechaVenta?: Date,
  ) {
    this.id = id;
    this.usuarioId = usuarioId;
    this.lineas = lineas;
    this.pagos = pagos;
    this.subtotal = subtotal;
    this.iva = iva;
    this.total = total;
    this.cambio = cambio;
    this.estado = estado;
    this.datosReceta = datosReceta;
    this.fechaVenta = fechaVenta ? new Date(fechaVenta) : new Date();
    this.tieneProductosControlados = lineas.some((l) =>
      l.esProductoControlado(),
    );
  }

  /**
   * Factory method - Crear una nueva venta
   * @param id - Folio único de la venta
   * @param usuarioId - ID del vendedor
   * @param lineas - Array de líneas de venta
   * @param pagos - Array de pagos (soporta múltiples para Pago Mixto)
   * @param iva - Porcentaje de IVA
   * @param datosReceta - Opcional, requerido si hay productos controlados
   * @returns Nueva instancia de Venta
   */
  public static crear(
    id: string,
    usuarioId: string,
    lineas: LineaVenta[],
    pagos: Pago[],
    ivaPercentaje: number = 19,
    datosReceta?: DatosReceta,
  ): Venta {
    if (lineas.length === 0) {
      throw new Error('La venta debe tener al menos una línea');
    }

    if (pagos.length === 0) {
      throw new Error('La venta debe tener al menos un pago');
    }

    const subtotal = lineas.reduce((sum, linea) => sum + linea.getSubtotal(), 0);
    const iva = subtotal * (ivaPercentaje / 100);
    const total = subtotal + iva;

    const totalPagado = pagos.reduce((sum, pago) => sum + pago.getMonto(), 0);
    if (Math.abs(totalPagado - total) > 0.01) {
      throw new Error(
        'La suma de los pagos debe coincidir con el total de la venta',
      );
    }

    const tieneControlados = lineas.some((l) => l.esProductoControlado());
    if (tieneControlados && !datosReceta) {
      throw new Error(
        'Datos de receta médica obligatorios para productos controlados',
      );
    }

    let cambio = 0;
    const pagosEfectivo = pagos.filter((p) => p.getTipo() === TipoPago.EFECTIVO);
    if (pagosEfectivo.length > 0) {
      const totalEfectivo = pagosEfectivo.reduce(
        (sum, p) => sum + p.getMonto(),
        0,
      );
      cambio = Math.max(0, totalEfectivo - total);
    }

    return new Venta(
      id,
      usuarioId,
      lineas,
      pagos,
      subtotal,
      iva,
      total,
      cambio,
      'pendiente',
      datosReceta,
    );
  }

  /**
   * Reconstitur una venta desde datos persistidos en Firestore
   * @param data - Documento de Firestore
   * @returns Instancia reconstitida de Venta
   */
  public static desdeFirestore(data: any): Venta {
    const lineas = (data.lineas || []).map(
      (line: any) =>
        new LineaVenta(
          line.codigoProducto,
          line.nombreProducto,
          line.cantidad,
          line.precioUnitario,
          line.esControlado,
          line.lote,
        ),
    );

    const pagos = (data.pagos || []).map(
      (pago: any) => new Pago(pago.tipo, pago.monto, pago.referencia),
    );

    let datosReceta: DatosReceta | undefined;
    if (data.datosReceta) {
      datosReceta = new DatosReceta(
        data.datosReceta.ciMedico,
        data.datosReceta.nombreMedico,
        new Date(data.datosReceta.fechaReceta),
      );
    }

    const fechaVenta = Venta.parseFechaFirestore(data.fechaVenta);

    const venta = new Venta(
      data.id,
      data.usuarioId,
      lineas,
      pagos,
      data.subtotal,
      data.iva,
      data.total,
      data.cambio,
      data.estado,
      datosReceta,
      fechaVenta,
    );

    return venta;
  }

  private static parseFechaFirestore(raw: any): Date {
    if (!raw) {
      return new Date(0);
    }

    if (raw instanceof Date) {
      return new Date(raw);
    }

    if (typeof raw?.toDate === 'function') {
      return raw.toDate();
    }

    if (typeof raw === 'string' || typeof raw === 'number') {
      return new Date(raw);
    }

    if (typeof raw === 'object' && raw._seconds) {
      return new Date(raw._seconds * 1000);
    }

    return new Date(0);
  }

  /**
   * Marcar la venta como procesada (después de persistencia exitosa)
   */
  public marcarComoProcesada(): void {
    this.estado = 'procesada';
  }

  /**
   * Marcar la venta como anulada
   */
  public marcarComoAnulada(): void {
    this.estado = 'anulada';
  }

  public getId(): string {
    return this.id;
  }

  public getUsuarioId(): string {
    return this.usuarioId;
  }

  public getLineas(): LineaVenta[] {
    return [...this.lineas];
  }

  public getPagos(): Pago[] {
    return [...this.pagos];
  }

  public getDatosReceta(): DatosReceta | undefined {
    return this.datosReceta;
  }

  public getSubtotal(): number {
    return this.subtotal;
  }

  public getIVA(): number {
    return this.iva;
  }

  public getTotal(): number {
    return this.total;
  }

  public getCambio(): number {
    return this.cambio;
  }

  public getTieneProductosControlados(): boolean {
    return this.tieneProductosControlados;
  }

  public getEstado(): 'pendiente' | 'procesada' | 'anulada' {
    return this.estado;
  }

  public getFechaVenta(): Date {
    return new Date(this.fechaVenta);
  }

  /**
   * Obtener el tipo de pago general (efectivo, tarjeta, mixto)
   * @returns Tipo de pago predominante
   */
  public getTipoPagoGeneral(): TipoPago {
    if (this.pagos.length === 1) {
      return this.pagos[0].getTipo();
    }
    return TipoPago.MIXTO;
  }

  /**
   * Serializar la venta para persistencia
   * @returns Objeto serializable
   */
  public toJSON(): Record<string, any> {
    return {
      id: this.id,
      usuarioId: this.usuarioId,
      lineas: this.lineas.map((l) => l.toJSON()),
      pagos: this.pagos.map((p) => p.toJSON()),
      datosReceta: this.datosReceta?.toJSON() || null,
      subtotal: this.subtotal,
      iva: this.iva,
      total: this.total,
      cambio: this.cambio,
      tieneProductosControlados: this.tieneProductosControlados,
      estado: this.estado,
      fechaVenta: this.fechaVenta.toISOString(),
    };
  }
}
