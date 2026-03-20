# PROYECTO: FARMACIA-POS-AWOS (POS FARMACÉUTICO) - FUENTE ÚNICA DE VERDAD

## Arquitectura Global y Estándares
- [cite_start]**Arquitectura**: Hexagonal (Puertos y Adaptadores) para el backend[cite: 109, 111].
- [cite_start]**Documentación**: Rigurosa con JSDoc (/** ... */) en todos los archivos (Controladores, Servicios, Middlewares) [cite: 144-150].
- **Clean Code**: Comentarios de una sola línea, solo si son estrictamente necesarios.
- **Validación**: Uso de DTOs (Zod o Joi) para todo el flujo de entrada de datos[cite: 109].
- **Patrón de Transacción**: Saga Pattern para la orquestación distribuida entre Node.js y Python[cite: 113].

## Roles y Tecnologías
- **Samuel**: Senior Backend Architect (Node.js/Express). Orquestador de ventas, seguridad (Firebase Auth/Firestore) y comunicación inter-servicios [cite: 1-13, 107-113].
- **Karel**: Lead DB Admin (Python/FastAPI/PostgreSQL). Lógica FEFO inyectada mediante Triggers y Stored Procedures en DB [cite: 114, 151-154].
- **Daniel**: Frontend Lead (Flutter/BLoC). Clean Architecture en la UI y generación de PDFs [cite: 118-130].

---

## Módulos Críticos y Reglas de Negocio

### 1. Seguridad (SSO + RBAC) - Responsabilidad de Samuel
- **Login**: `POST /api/auth/login` recibe el idToken de Google emitido por el frontend [cite: 5-6].
- **Validación**: Verificar con firebase-admin y cruzar con la colección `perfiles_seguridad` en Firestore[cite: 6, 17].
- **Token**: Emitir JWT propio con el payload de permisos (ej. `permisos: ["crear_venta"]`) [cite: 5-6, 13].
- **Middleware**: Implementar `requirePermissions` para proteger rutas basado en los permisos del JWT [cite: 12-13].

### 2. Orquestación de Venta (Saga Pattern) - Responsabilidad de Samuel
- **Flujo HU-28/29**: Al procesar una venta se sigue la siguiente secuencia: [cite: 107-114]
    1. Validar payload estrictamente con DTOs[cite: 109].
    2. Llamar vía Axios a la API de Python (`/api/inventario/descontar`) [cite: 113-114].
    3. Si Python responde 200 OK, generar folio y persistir el Ticket inmutable en Firestore[cite: 109].
    4. Si se incluyen productos controlados, persistir el registro en la colección `auditoria_recetas`[cite: 146].
    5. **Rollback**: Si la escritura en Firestore falla, ejecutar inmediatamente una compensación en Python (`/api/inventario/compensar`)[cite: 113].

### 3. Motor de Inventario (FEFO) - Responsabilidad de Karel
- El motor PostgreSQL 18 gestiona un Trigger `trg_prevent_negative_stock` para evitar inventarios negativos y un Stored Procedure `sp_descontar_fefo` para el despacho automático priorizando caducidades próximas [cite: 151-154].

---

## Backlog Completo de Historias de Usuario (HUs)

### Módulo 1: Identidad y Perfiles (Samuel)
- **HU-01**: Inicio de Sesión Seguro con Google SSO [cite: 1-6].
- **HU-02**: Cierre de Sesión inmediato y limpieza de estado [cite: 7-9].
- **HU-03**: Restricción de Vistas Financieras para el rol Cajero [cite: 10-13].
- **HU-04**: Registro de Nuevos Empleados y asignación de roles en Firestore [cite: 14-17].
- **HU-05**: Revocación inmediata de acceso a exempleados [cite: 18-21].

### Módulo 2 y 3: Catálogo y Almacén (Karel)
- **HU-06 a HU-11**: Gestión de laboratorios, categorías, alta de medicamentos con código de barras único, actualización de precios y bajas lógicas [cite: 22-46].
- **HU-12 a HU-16**: Ingreso de lotes, validación obligatoria de caducidad (prohibido ingresar caducados), consulta de existencias por lote, monitoreo de riesgos (< 90 días) y declaración de mermas [cite: 47-67].

### Módulo 4 y 5: Punto de Venta y Auditoría Médica (Daniel/Samuel)
- **HU-17 a HU-21**: Búsqueda de alta velocidad con Debounce, gestión de carrito (agregar, ajustar cantidades, retirar) y cálculo dinámico de totales e IVA [cite: 68-84].
- **HU-22 a HU-24**: Advertencia visual de productos controlados, captura obligatoria de datos del médico (Cédula y Nombre) y bloqueo total de la venta si falta información médica [cite: 85-94].

### Módulo 6: Pagos y Orquestación (Samuel)
- **HU-25 a HU-27**: Asistente de cobro en efectivo con cálculo de cambio, cobro con tarjeta y soporte para **Pago Mixto** [cite: 95-106].
- **HU-28 a HU-30**: Registro de ticket inmutable, deducción de inventario orquestada con Python (Saga) y resiliencia ante caídas de red [cite: 107-117].

### Módulo 7 y 8: Comprobantes y Reportes (Daniel/Samuel)
- **HU-31 a HU-34**: Emisión de ticket de 80mm, trazabilidad de lotes en el impreso, constancia de receta retenida y previsualización nativa [cite: 118-130].
- **HU-35 a HU-39**: Consulta de ventas por turno (UID), auditoría global administrativa, anulación de tickets con reintegro de stock, reporte sanitario legal y resumen financiero diario (KPIs) [cite: 131-150].
- **HU-40**: Algoritmo de despacho inteligente FEFO ejecutado en el motor de base de datos [cite: 151-154].