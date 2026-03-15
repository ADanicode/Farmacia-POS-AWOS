/**
 * @fileoverview VentasController - Controlador de Ventas
 * Expone los endpoints HTTP para la orquestación de ventas (HU-28 a HU-30, HU-35, HU-39)
 * Inyecta VentaService y ReporteService para manejar la lógica sin conocer detalles de implementación
 */

import { Request, Response } from 'express';
import { VentaService, StockInsuficienteError, CompensacionFallidaError, VentaServiceError } from '@application/services/VentaService';
import { ReporteService } from '@application/services/ReporteService';
import { IAuthService } from '@application/interfaces/IAuthService';
import { validarCreateVentaDTO } from '@application/dtos/CreateVentaDTO';
import { ZodError } from 'zod';

/**
 * VentasController - Manejador de solicitudes de ventas
 * Responsabilidades:
 * - Validar entrada (DTO + permisos)
 * - Orquestar flujo de venta con VentaService
 * - Exponer reportes y auditoría con ReporteService
 * - Manejar errores y retornar respuestas HTTP apropiadas
 */

export class VentasController {
  /**
   * Constructor con inyección de dependencias
   * @param ventaService - Servicio de orquestación de ventas
   * @param reporteService - Servicio de generación de reportes
   * @param authService - Servicio de autenticación (para verificaciones adicionales si es necesario)
   */
  constructor(
    private readonly ventaService: VentaService,
    private readonly reporteService: ReporteService,
    private readonly authService: IAuthService,
  ) {}

  /**
   * POST /api/ventas/procesar
   * Crea una nueva venta siguiendo el Saga Pattern (HU-28, HU-29, HU-30)
   *
   * Flujo HTTP:
   * 1. Validar autenticación (middleware requireAuth)
   * 2. Validar permisos (middleware requirePermissions)
   * 3. Validar DTO con Zod (CreateVentaSchema)
   * 4. Llamar a ventaService.crearVenta()
   * 5. Manejar errores específicos del Saga Pattern
   * 6. Retornar respuesta JSON estructurada
   *
   * Autenticación: ✅ REQUERIDA (middleware requireAuth)
   * Autorización: ✅ REQUERIDA (permisos: crear_venta, descontar_stock)
   *
   * @param req - Request de Express (incluye req.user del middleware requireAuth)
   * @param res - Response de Express
   * @returns JSON con venta procesada o error
   *
   * Request Body: CreateVentaDTO
   * {
   *   usuarioId: string,
   *   lineas: LineaVentaDTO[],
   *   pagos: PagoDTO[],
   *   ivaPercentaje: number (default 19),
   *   datosReceta?: DatosRecetaDTO (obligatorio si hay controlados)
   * }
   *
   * Response 200 OK:
   * {
   *   success: true,
   *   data: {
   *     ventaId: string,
   *     folio: string,
   *     usuario: { uid, email, nombre, role },
   *     lineas: LineaVenta[],
   *     subtotal: number,
   *     iva: number,
   *     total: number,
   *     pagos: Pago[],
   *     estado: 'procesada',
   *     fechaVenta: ISO8601
   *   }
   * }
   */
  public async procesar(req: Request, res: Response): Promise<void> {
    const usuarioAuth = (req as any).user;

    try {
      console.log(
        `[VentasController] POST /api/ventas/procesar - Usuario: ${usuarioAuth.uid}`,
      );

      // ========================================
      // PASO 1: VALIDAR DTO CON ZOD
      // ========================================

      let createVentaDTO;
      try {
        createVentaDTO = validarCreateVentaDTO(req.body);
      } catch (errorZod: any) {
        if (errorZod instanceof ZodError) {
          console.warn(`[VentasController] Validación DTO fallida:`, errorZod.flatten());
          res.status(400).json({
            success: false,
            error: 'Validación de datos fallida',
            details: errorZod.flatten().fieldErrors,
          });
          return;
        }
        throw errorZod;
      }

      console.log(
        `[VentasController] DTO validado - Total: ${createVentaDTO.lineas.reduce((sum, l) => sum + l.cantidad * l.precioUnitario, 0) * (createVentaDTO.ivaPercentaje || 19) / 100}`,
      );

      // ========================================
      // PASO 2: RECREAR ENTIDAD USUARIO DESDE JWT
      // ========================================

      // El usuarioAuth viene del middleware pero necesitamos la entidad Usuario
      // En production, se podría cachear o verificar nuevamente con Firestore
      // Por ahora, confiamos en el JWT validado por requireAuth

      if (usuarioAuth.uid !== createVentaDTO.usuarioId) {
        console.warn(
          `[VentasController] Intento de crear venta para usuario diferente`,
        );
        res.status(403).json({
          success: false,
          error: 'No puedes crear ventas para otro usuario',
        });
        return;
      }

      // ========================================
      // PASO 3: LLAMAR AL VENTA SERVICE (SAGA PATTERN)
      // ========================================

      console.log(
        `[VentasController] Iniciando Saga Pattern para venta...`,
      );

      try {
        // Nota: En una implementación real, obtendríamos la entidad Usuario completa
        // desde Firestore o desde un caché. Por ahora usamos los datos del JWT.
        // Esto se haría típicamente en un middleware específico o en el servicio.

        // Para esta demostración, creamos una entidad Usuario mínima
        // En producción: const usuario = await usuarioRepository.obtenerPorUid(usuarioAuth.uid)

        // Crear usuario temporal desde JWT (suficiente para demostración)
        const { Usuario, RoleType, PermissionType } = require('@domain/entities/Usuario');

        const usuarioTemporal = Usuario.crear(
          usuarioAuth.uid,
          usuarioAuth.email,
          usuarioAuth.nombre || 'Usuario',
          usuarioAuth.role === 'cajero' ? RoleType.CAJERO : RoleType.VENDEDOR,
          usuarioAuth.permisos.map((p: string) =>
            Object.values(PermissionType).includes(p) ? p : null
          ).filter((p: any) => p !== null),
        );

        // SAGA PATTERN AQUÍ
        const ventaProcesada = await this.ventaService.crearVenta(
          usuarioTemporal,
          createVentaDTO,
        );

        console.log(
          `[VentasController] ✅ Venta procesada exitosamente: ${ventaProcesada.getId()}`,
        );

        // ========================================
        // PASO 4: RESPUESTA EXITOSA
        // ========================================

        res.status(200).json({
          success: true,
          data: {
            ventaId: ventaProcesada.getId(),
            folio: ventaProcesada.getId(),
            usuario: {
              uid: usuarioAuth.uid,
              email: usuarioAuth.email,
              nombre: usuarioAuth.nombre,
              role: usuarioAuth.role,
            },
            lineas: ventaProcesada.getLineas().map((l) => ({
              codigo: l.getCodigoProducto(),
              nombre: l.getNombreProducto(),
              cantidad: l.getCantidad(),
              precioUnitario: l.getPrecioUnitario(),
              subtotal: l.getSubtotal(),
              esControlado: l.esProductoControlado(),
              lote: l.getLote(),
            })),
            subtotal: ventaProcesada.getSubtotal(),
            iva: ventaProcesada.getIVA(),
            total: ventaProcesada.getTotal(),
            cambio: ventaProcesada.getCambio(),
            pagos: ventaProcesada.getPagos().map((p) => ({
              tipo: p.getTipo(),
              monto: p.getMonto(),
              referencia: p.getReferencia(),
            })),
            tieneProductosControlados: ventaProcesada.getTieneProductosControlados(),
            estado: ventaProcesada.getEstado(),
            fechaVenta: ventaProcesada.getFechaVenta().toISOString(),
          },
          timestamp: new Date().toISOString(),
        });
      } catch (errorSaga: any) {
        // ========================================
        // MANEJO DE ERRORES DEL SAGA PATTERN
        // ========================================

        if (errorSaga instanceof StockInsuficienteError) {
          // Stock insuficiente en Python
          console.warn(
            `[VentasController] Stock insuficiente para venta`,
            errorSaga.detalles,
          );
          res.status(400).json({
            success: false,
            error: 'Stock insuficiente',
            code: 'STOCK_INSUFICIENTE',
            detalles: errorSaga.detalles,
          });
          return;
        }

        if (errorSaga instanceof CompensacionFallidaError) {
          // CRÍTICO: Venta persistida pero compensación falló
          console.error(
            `[VentasController] ❌ FALLO CRÍTICO EN COMPENSACIÓN`,
            {
              ventaId: errorSaga.ventaId,
              error: errorSaga.errorOriginal.message,
            },
          );
          res.status(500).json({
            success: false,
            error: 'Error crítico en el sistema. Contactar a soporte inmediatamente.',
            code: 'COMPENSACION_FALLIDA',
            ventaId: errorSaga.ventaId,
            message: 'La venta fue persistida pero falló el reintegro de stock. Intervención manual requerida.',
          });
          return;
        }

        if (errorSaga instanceof VentaServiceError) {
          // Error general del servicio
          console.error(
            `[VentasController] Error en servicio de ventas:`,
            errorSaga.message,
          );
          res.status(400).json({
            success: false,
            error: errorSaga.message,
            code: errorSaga.code,
          });
          return;
        }

        // Error desconocido
        console.error(`[VentasController] Error inesperado:`, errorSaga);
        res.status(500).json({
          success: false,
          error: 'Error inesperado al procesar venta',
          message: errorSaga.message,
        });
      }
    } catch (errorGeneral: any) {
      console.error(`[VentasController] Error general no capturado:`, errorGeneral);
      res.status(500).json({
        success: false,
        error: 'Error interno del servidor',
      });
    }
  }

  /**
   * GET /api/ventas/:ventaId
   * Obtiene una venta por su ID (folio)
   *
   * @param req - Request con params.ventaId
   * @param res - Response de Express
   */
  public async obtener(req: Request, res: Response): Promise<void> {
    try {
      const { ventaId } = req.params;

      if (!ventaId) {
        res.status(400).json({
          success: false,
          error: 'ventaId es requerido',
        });
        return;
      }

      const venta = await this.ventaService.obtenerVenta(ventaId);

      res.status(200).json({
        success: true,
        data: venta.toJSON(),
      });
    } catch (error: any) {
      console.error(`[VentasController] Error obteniendo venta:`, error);
      res.status(404).json({
        success: false,
        error: 'Venta no encontrada',
      });
    }
  }
}
