"""
Módulo Catálogo - HU-06, HU-07, HU-08, HU-09, HU-10, HU-11
Gestión de categorías, proveedores y medicamentos
"""

from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import text
from pydantic import BaseModel, Field
from typing import List, Optional
from app.db.dependencies import get_db
from app.uow.uow import UnitOfWork

router = APIRouter(prefix="/api/v1/catalogo")


# ============================================================
# MODELOS
# ============================================================

class CategoriaCreate(BaseModel):
    nombre: str = Field(..., min_length=1, max_length=100)

class ProveedorCreate(BaseModel):
    nombre: str = Field(..., min_length=1, max_length=255)
    contacto: Optional[str] = None

class MedicamentoCreate(BaseModel):
    nombre: str = Field(..., min_length=1, max_length=255)
    codigo_barras: str = Field(..., min_length=1, max_length=100)
    precio: float = Field(..., gt=0, description="Precio no puede ser negativo o cero (HU-09)")
    requiere_receta: bool = Field(..., description="Bandera de control sanitario (HU-08)")
    proveedor_id: int
    categoria_id: int

class MedicamentoPrecioUpdate(BaseModel):
    precio: float = Field(..., gt=0, description="Precio debe ser mayor a 0 (HU-09)")

class MedicamentoBajaUpdate(BaseModel):
    activo: bool


# ============================================================
# HU-06: CATEGORÍAS
# ============================================================

@router.post("/categorias", status_code=201)
def crear_categoria(body: CategoriaCreate, db: Session = Depends(get_db)):
    """HU-06: Registrar nueva categoría terapéutica"""
    with UnitOfWork(db):
        resultado = db.execute(text("""
            INSERT INTO farm_categorias (nombre, activo)
            VALUES (:nombre, true)
            RETURNING id, nombre, activo
        """), {"nombre": body.nombre}).fetchone()
        return {"id": resultado.id, "nombre": resultado.nombre, "activo": resultado.activo}


@router.get("/categorias")
def listar_categorias(db: Session = Depends(get_db)):
    """HU-06: Listar todas las categorías activas"""
    rows = db.execute(text("""
        SELECT id, nombre, activo FROM farm_categorias
        WHERE activo = true ORDER BY nombre
    """)).fetchall()
    return [{"id": r.id, "nombre": r.nombre, "activo": r.activo} for r in rows]


# ============================================================
# HU-06: PROVEEDORES
# ============================================================

@router.post("/proveedores", status_code=201)
def crear_proveedor(body: ProveedorCreate, db: Session = Depends(get_db)):
    """HU-06: Registrar nuevo proveedor/laboratorio"""
    with UnitOfWork(db):
        resultado = db.execute(text("""
            INSERT INTO farm_proveedores (nombre, contacto, activo)
            VALUES (:nombre, :contacto, true)
            RETURNING id, nombre, contacto, activo
        """), {"nombre": body.nombre, "contacto": body.contacto}).fetchone()
        return {
            "id": resultado.id,
            "nombre": resultado.nombre,
            "contacto": resultado.contacto,
            "activo": resultado.activo
        }


@router.get("/proveedores")
def listar_proveedores(db: Session = Depends(get_db)):
    """HU-06: Listar todos los proveedores activos"""
    rows = db.execute(text("""
        SELECT id, nombre, contacto, activo FROM farm_proveedores
        WHERE activo = true ORDER BY nombre
    """)).fetchall()
    return [{"id": r.id, "nombre": r.nombre, "contacto": r.contacto} for r in rows]


# ============================================================
# HU-07, HU-08: ALTA DE MEDICAMENTOS
# ============================================================

@router.post("/medicamentos", status_code=201)
def crear_medicamento(body: MedicamentoCreate, db: Session = Depends(get_db)):
    """
    HU-07: Registrar nuevo medicamento
    HU-08: Bandera requiere_receta obligatoria
    """
    with UnitOfWork(db):
        # Verificar código de barras único (HU-07)
        existente = db.execute(text("""
            SELECT id FROM farm_medicamentos
            WHERE codigo_barras = :codigo
        """), {"codigo": body.codigo_barras}).fetchone()

        if existente:
            raise HTTPException(
                status_code=400,
                detail=f"El código de barras {body.codigo_barras} ya existe"
            )

        resultado = db.execute(text("""
            INSERT INTO farm_medicamentos
                (nombre, codigo_barras, precio, requiere_receta, proveedor_id, categoria_id, activo)
            VALUES
                (:nombre, :codigo, :precio, :requiere_receta, :proveedor_id, :categoria_id, true)
            RETURNING id, nombre, codigo_barras, precio, requiere_receta, activo
        """), {
            "nombre": body.nombre,
            "codigo": body.codigo_barras,
            "precio": body.precio,
            "requiere_receta": body.requiere_receta,
            "proveedor_id": body.proveedor_id,
            "categoria_id": body.categoria_id
        }).fetchone()

        return {
            "id": resultado.id,
            "nombre": resultado.nombre,
            "codigo_barras": resultado.codigo_barras,
            "precio": resultado.precio,
            "requiere_receta": resultado.requiere_receta,
            "activo": resultado.activo
        }


# ============================================================
# HU-10: BÚSQUEDA DE MEDICAMENTOS (ILIKE, ignora mayúsculas)
# ============================================================

@router.get("/medicamentos")
def buscar_medicamentos(
    nombre: Optional[str] = Query(None, description="Buscar por nombre (ignora mayúsculas y acentos)"),
    db: Session = Depends(get_db)
):
    """HU-10: Búsqueda maestra de catálogo con ILIKE"""
    if nombre:
        rows = db.execute(text("""
            SELECT
                fm.id, fm.nombre, fm.codigo_barras, fm.precio,
                fm.requiere_receta, fm.activo,
                fc.nombre AS categoria,
                fp.nombre AS proveedor
            FROM farm_medicamentos fm
            LEFT JOIN farm_categorias fc ON fc.id = fm.categoria_id
            LEFT JOIN farm_proveedores fp ON fp.id = fm.proveedor_id
            WHERE fm.activo = true
              AND unaccent(lower(fm.nombre)) ILIKE unaccent(lower(:nombre))
            ORDER BY fm.nombre
        """), {"nombre": f"%{nombre}%"}).fetchall()
    else:
        rows = db.execute(text("""
            SELECT
                fm.id, fm.nombre, fm.codigo_barras, fm.precio,
                fm.requiere_receta, fm.activo,
                fc.nombre AS categoria,
                fp.nombre AS proveedor
            FROM farm_medicamentos fm
            LEFT JOIN farm_categorias fc ON fc.id = fm.categoria_id
            LEFT JOIN farm_proveedores fp ON fp.id = fm.proveedor_id
            WHERE fm.activo = true
            ORDER BY fm.nombre
        """)).fetchall()

    return [
        {
            "id": r.id,
            "nombre": r.nombre,
            "codigo_barras": r.codigo_barras,
            "precio": r.precio,
            "requiere_receta": r.requiere_receta,
            "categoria": r.categoria,
            "proveedor": r.proveedor
        }
        for r in rows
    ]


# ============================================================
# HU-09: ACTUALIZACIÓN DE PRECIOS
# ============================================================

@router.put("/medicamentos/{medicamento_id}/precio")
def actualizar_precio(
    medicamento_id: int,
    body: MedicamentoPrecioUpdate,
    db: Session = Depends(get_db)
):
    """HU-09: Actualizar precio de medicamento (no acepta precio <= 0)"""
    with UnitOfWork(db):
        resultado = db.execute(text("""
            UPDATE farm_medicamentos
            SET precio = :precio
            WHERE id = :id AND activo = true
            RETURNING id, nombre, precio
        """), {"precio": body.precio, "id": medicamento_id}).fetchone()

        if not resultado:
            raise HTTPException(status_code=404, detail="Medicamento no encontrado")

        return {"id": resultado.id, "nombre": resultado.nombre, "precio": resultado.precio}


# ============================================================
# HU-11: BAJA LÓGICA DE MEDICAMENTO
# ============================================================

@router.patch("/medicamentos/{medicamento_id}/baja")
def baja_medicamento(medicamento_id: int, db: Session = Depends(get_db)):
    """HU-11: Marcar medicamento como descontinuado (baja lógica)"""
    with UnitOfWork(db):
        resultado = db.execute(text("""
            UPDATE farm_medicamentos
            SET activo = false
            WHERE id = :id
            RETURNING id, nombre, activo
        """), {"id": medicamento_id}).fetchone()

        if not resultado:
            raise HTTPException(status_code=404, detail="Medicamento no encontrado")

        return {
            "id": resultado.id,
            "nombre": resultado.nombre,
            "activo": resultado.activo,
            "mensaje": "Medicamento descontinuado correctamente"
        }