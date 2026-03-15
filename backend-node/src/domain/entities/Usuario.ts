/**
 * @fileoverview Entidad Usuario - Parte de la Capa de Dominio
 * Representa un usuario del sistema con role y permisos (RBAC)
 * Mapea a la colección perfiles_seguridad de Firestore
 */

/**
 * Enum de roles disponibles en el sistema
 */
export enum RoleType {
  ADMIN = 'admin',
  GERENTE = 'gerente',
  FARMACEUTICO = 'farmaceutico',
  CAJERO = 'cajero',
  VENDEDOR = 'vendedor',
}

/**
 * Enum de permisos granulares (RBAC)
 */
export enum PermissionType {
  CREAR_VENTA = 'crear_venta',
  CONSULTAR_INVENTARIO = 'consultar_inventario',
  DESCONTAR_STOCK = 'descontar_stock',
  ANULAR_VENTA = 'anular_venta',
  VER_REPORTES_FINANCIEROS = 'ver_reportes_financieros',
  GESTIONAR_USUARIOS = 'gestionar_usuarios',
  REVERSAR_TRANSACCION = 'reversar_transaccion',
}

/**
 * Clase Usuario - Entidad de Dominio
 * Representa un usuario autenticado con sus permisos derivados de perfiles_seguridad
 * Esta es una entidad pura del dominio sin dependencias externas
 */
export class Usuario {
  /**
   * Identificador único del usuario (UID de Firebase)
   */
  private readonly id: string;

  /**
   * Email del usuario (de Google SSO)
   */
  private readonly email: string;

  /**
   * Nombre completo del usuario
   */
  private readonly nombre: string;

  /**
   * Role principal del usuario
   */
  private readonly role: RoleType;

  /**
   * Permisos específicos derivados del role (puede haber permisos adicionales)
   */
  private readonly permisos: PermissionType[];

  /**
   * Fecha de creación del usuario
   */
  private readonly fechaCreacion: Date;

  /**
   * Indica si el usuario está activo
   */
  private readonly activo: boolean;

  /**
   * Constructor privado para forzar el uso de métodos factory
   */
  private constructor(
    id: string,
    email: string,
    nombre: string,
    role: RoleType,
    permisos: PermissionType[],
    fechaCreacion: Date,
    activo: boolean,
  ) {
    this.id = id;
    this.email = email;
    this.nombre = nombre;
    this.role = role;
    this.permisos = permisos;
    this.fechaCreacion = fechaCreacion;
    this.activo = activo;
  }

  /**
   * Factory method - Crear un nuevo usuario desde Firestore
   * @param id - UID del usuario
   * @param email - Email de autenticación
   * @param nombre - Nombre completo
   * @param role - Role asignado
   * @param permisos - Array de permisos
   * @param activo - Estado del usuario
   * @returns Nueva instancia de Usuario
   */
  public static crear(
    id: string,
    email: string,
    nombre: string,
    role: RoleType,
    permisos: PermissionType[],
    activo: boolean = true,
  ): Usuario {
    return new Usuario(
      id,
      email,
      nombre,
      role,
      permisos,
      new Date(),
      activo,
    );
  }

  /**
   * Factory method - Reconstitur un usuario desde datos persistidos
   * @param data - Datos del documento Firestore
   * @returns Instancia reconstitida de Usuario
   */
  public static desdeFirestore(data: any): Usuario {
    return new Usuario(
      data.id,
      data.email,
      data.nombre,
      data.role,
      data.permisos,
      new Date(data.fechaCreacion),
      data.activo,
    );
  }

  /**
   * Verifica si el usuario posee un permiso específico
   * @param permiso - Permiso a verificar
   * @returns true si el usuario tiene el permiso
   */
  public tienePermiso(permiso: PermissionType): boolean {
    return this.permisos.includes(permiso);
  }

  /**
   * Verifica si el usuario posee TODOS los permisos solicitados
   * @param permisos - Array de permisos requeridos
   * @returns true si el usuario tiene todos los permisos
   */
  public tienePermisosMultiples(permisos: PermissionType[]): boolean {
    return permisos.every((p) => this.permisos.includes(p));
  }

  /**
   * Comprueba si el usuario está autorizado para realizar una acción
   * @returns true si el usuario está activo
   */
  public estaAutorizado(): boolean {
    return this.activo;
  }

  public getId(): string {
    return this.id;
  }

  public getEmail(): string {
    return this.email;
  }

  public getNombre(): string {
    return this.nombre;
  }

  public getRole(): RoleType {
    return this.role;
  }

  public getPermisos(): PermissionType[] {
    return [...this.permisos];
  }

  public getFechaCreacion(): Date {
    return new Date(this.fechaCreacion);
  }

  public isActivo(): boolean {
    return this.activo;
  }

  /**
   * Serializa el usuario para persistencia o transmisión
   * @returns Objeto serializable
   */
  public toJSON(): Record<string, any> {
    return {
      id: this.id,
      email: this.email,
      nombre: this.nombre,
      role: this.role,
      permisos: this.permisos,
      fechaCreacion: this.fechaCreacion.toISOString(),
      activo: this.activo,
    };
  }
}
