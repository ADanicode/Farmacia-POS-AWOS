# Backend Node.js - Lleve-Llevele POS Farmacéutico

## 📋 Descripción

API Orquestadora del sistema POS farmacéutico construida con **Node.js/Express** bajo Arquitectura Hexagonal (Puertos y Adaptadores).

**Responsabilidades principales:**
- 🔐 Seguridad: SSO con Google + Firebase + JWT + RBAC
- 🔄 Orquestación de Ventas: Saga Pattern con Python backend
- 📝 Auditoría: Registro inmutable de recetas controladas

## 🏗️ Estructura de Carpetas - Arquitectura Hexagonal

```
src/
├── domain/                 # Capa de Dominio (Pura)
│   ├── entities/          # Entidades básicas (Venta, Usuario, etc)
│   ├── interfaces/        # Interfaces de casos de uso
│   └── value-objects/     # Objetos de valor immutables
│
├── application/           # Capa de Aplicación
│   ├── dtos/             # Data Transfer Objects (Zod schemas)
│   ├── services/         # Lógica de negocio y orquestación
│   └── interfaces/       # Puertos (contrato de repositorios)
│
├── infrastructure/        # Capa de Infraestructura
│   ├── external/         # Llamadas a servicios externos (Python)
│   ├── persistence/      # Adapters de Firestore
│   ├── repositories/     # Implementaciones de repositorios
│   └── http/             # Clientes HTTP (Axios)
│
├── interfaces/           # Puertos de Entrada
│   ├── controllers/      # HTTP Controllers
│   ├── middlewares/      # Express middlewares (Auth, Validation)
│   └── routes/          # Rutas Express
│
├── config/              # Configuración centralizada
└── main.ts             # Punto de entrada
```

## ⚡ Comenzando

### 1. Instalación de dependencias
```bash
npm install
```

### 2. Configurar variables de entorno
```bash
cp .env.example .env
# Editar .env con credenciales reales
```

### 3. Desarrollo
```bash
npm run dev
```

### 4. Build
```bash
npm run build
npm start
```

## 📦 Dependencias Principales

- **express** (4.18.2): Framework web
- **firebase-admin** (12.0.0): Autenticación + Firestore
- **jsonwebtoken** (9.1.2): Generación de JWT
- **axios** (1.6.0): Cliente HTTP para Python backend
- **zod** (3.22.4): Validación con DTOs
- **dotenv** (16.3.1): Variables de entorno

## 📐 Estándares de Codificación

✅ **JSDoc riguroso**: Todo controlador, servicio y middleware debe estar documentado
```typescript
/**
 * Procesa una venta nueva siguiendo Saga Pattern
 * @param createVentaDto - DTO validado con Zod
 * @returns Ticket inmutable persistido en Firestore
 */
```

✅ **Clean Code**: Comentarios solo cuando sea estrictamente necesario

✅ **Inyección de Dependencias**: Servicios desacoplados por interfaces

✅ **DTOs con Zod**: Validación estricta en todos los endpoints

## 🔗 Comunicación Inter-Servicios

### Llamadas a Python Backend (Karel)
```typescript
// POST /api/inventario/descontar
// Compensación en caso de fallo: POST /api/inventario/compensar
```

### Consulta de Roles (Firestore)
```typescript
// Colección: perfiles_seguridad
// Campo: permisos (Array de permisos autorizados)
```

### Persistencia de Tickets
```typescript
// Colección: tickets_ventas (immutable)
// Colección: auditoria_recetas (productos controlados)
```

## 📝 Historias de Usuario Asociadas

- HU-01 a HU-05: Identidad y Seguridad
- HU-25 a HU-30: Pagos y Orquestación
- HU-31 a HU-39: Comprobantes y Reportes (parcial)

---

**Autor:** Samuel - Senior Backend Architect
**Última actualización:** 2026-03-13
