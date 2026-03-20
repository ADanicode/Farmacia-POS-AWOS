"""
Módulo Almacén - HU-12, HU-13, HU-14, HU-15, HU-16
Gestión de lotes, caducidades y mermas
"""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import text
from pydantic import BaseModel, Field, validator
from typing import Optional
from datetime import date, timedelta
from app.db.dependencies import get_db
from app.uow.uow import UnitOfWork

router = APIRouter(prefix="/api/v1/almacen")


# ============================================================
# MODELOS
# ============================================================

class LoteCreate(BaseModel):
    medicamento_id: int
    numero_lote: str = Field(..., min_length=1, max_length=100)
    fecha_caducidad: date
    stock_actual: int = Field(..., gt=0)

    @validator("fecha_caducidad")
    def validar_fecha_caducidad(cls, v):
        """HU-13: Rechazar lotes caducados o que caducan hoy"""
        if v <= date.today():
            raise ValueError(
                "La fecha de caducidad debe ser posterior a hoy (HU-13)"
            )
        return v

class MermaCreate(BaseModel):
    lote_id: int
    cantidad: int = Field(..., gt=0)
    motivo: str = Field(..., min_length=1)


# ============================================================
# HU-12, HU-13: INGRESO DE LOTES
# ============================================================

@router.post("/lotes", status_code=201)
def ingresar_lote(body: LoteCreate, db: Session = Depends(get_db)):
    """
    HU-12: Registrar nuevo lote de inventario
    HU-13: Validar que la fecha de caducidad sea futura
    """
    with UnitOfWork(db):
        # Verificar que el medicamento existe y está activo
        med = db.execute(text("""
            SELECT id, nombre FROM farm_medicamentos
            WHERE id = :id AND activo = true
        """), {"id": body.medicamento_id}).fetchone()

        if not med:
            raise HTTPException(
                status_code=404,
                detail="Medicamento no encontrado o descontinuado"
            )

        resultado = db.execute(text("""
            INSERT INTO farm_lotes_inventario
                (medicamento_id, numero_lote, fecha_caducidad, stock_actual)
            VALUES
                (:med_id, :numero_lote, :fecha_caducidad, :stock)
            RETURNING id, medicamento_id, numero_lote, fecha_caducidad, stock_actual
        """), {
            "med_id": body.medicamento_id,
            "numero_lote": body.numero_lote,
            "fecha_caducidad": body.fecha_caducidad,
            "stock": body.stock_actual
        }).fetchone()

        return {
            "id": resultado.id,
            "medicamento_id": resultado.medicamento_id,
            "medicamento_nombre": med.nombre,
            "numero_lote": resultado.numero_lote,
            "fecha_caducidad": str(resultado.fecha_caducidad),
            "stock_actual": resultado.stock_actual
        }


# ============================================================
# HU-14: CONSULTA DE EXISTENCIAS POR LOTE
# ============================================================

@router.get("/medicamentos/{medicamento_id}/lotes")
def consultar_lotes(medicamento_id: int, db: Session = Depends(get_db)):
    """
    HU-14: Ver desglose de lotes activos de un medicamento
    Solo lotes con stock > 0, ordenados por fecha de caducidad (FEFO)
    """
    med = db.execute(text("""
        SELECT id, nombre FROM farm_medicamentos WHERE id = :id
    """), {"id": medicamento_id}).fetchone()

    if not med:
        raise HTTPException(status_code=404, detail="Medicamento no encontrado")

    rows = db.execute(text("""
        SELECT
            id, numero_lote, fecha_caducidad, stock_actual,
            CASE
                WHEN fecha_caducidad <= CURRENT_DATE + INTERVAL '90 days'
                THEN true ELSE false
            END AS proximo_caducar
        FROM farm_lotes_inventario
        WHERE medicamento_id = :med_id
          AND stock_actual > 0
          AND fecha_caducidad >= CURRENT_DATE
        ORDER BY fecha_caducidad ASC
    """), {"med_id": medicamento_id}).fetchall()

    return {
        "medicamento_id": med.id,
        "medicamento_nombre": med.nombre,
        "total_lotes": len(rows),
        "stock_total": sum(r.stock_actual for r in rows),
        "lotes": [
            {
                "id": r.id,
                "numero_lote": r.numero_lote,
                "fecha_caducidad": str(r.fecha_caducidad),
                "stock_actual": r.stock_actual,
                "proximo_caducar": r.proximo_caducar
            }
            for r in rows
        ]
    }


# ============================================================
# HU-15: MONITOREO DE CADUCIDADES (próximos 90 días)
# ============================================================

@router.get("/lotes/proximos-caducar")
def lotes_proximos_caducar(db: Session = Depends(get_db)):
    """
    HU-15: Panel de lotes que caducan en los próximos 90 días
    Para toma de decisiones de venta rápida
    """
    rows = db.execute(text("""
        SELECT
            fl.id AS lote_id,
            fl.numero_lote,
            fl.fecha_caducidad,
            fl.stock_actual,
            fm.id AS medicamento_id,
            fm.nombre AS medicamento_nombre,
            fm.codigo_barras,
            (fl.fecha_caducidad - CURRENT_DATE) AS dias_restantes,
            CASE
                WHEN fl.fecha_caducidad <= CURRENT_DATE + INTERVAL '30 days'
                    THEN 'CRITICO'
                WHEN fl.fecha_caducidad <= CURRENT_DATE + INTERVAL '60 days'
                    THEN 'URGENTE'
                ELSE 'ALERTA'
            END AS nivel_riesgo
        FROM farm_lotes_inventario fl
        JOIN farm_medicamentos fm ON fm.id = fl.medicamento_id
        WHERE fl.fecha_caducidad <= CURRENT_DATE + INTERVAL '90 days'
          AND fl.fecha_caducidad >= CURRENT_DATE
          AND fl.stock_actual > 0
          AND fm.activo = true
        ORDER BY fl.fecha_caducidad ASC
    """)).fetchall()

    return {
        "total": len(rows),
        "lotes": [
            {
                "lote_id": r.lote_id,
                "numero_lote": r.numero_lote,
                "medicamento_id": r.medicamento_id,
                "medicamento_nombre": r.medicamento_nombre,
                "codigo_barras": r.codigo_barras,
                "fecha_caducidad": str(r.fecha_caducidad),
                "dias_restantes": r.dias_restantes,
                "stock_actual": r.stock_actual,
                "nivel_riesgo": r.nivel_riesgo
            }
            for r in rows
        ]
    }


# ============================================================
# HU-16: DECLARACIÓN DE MERMAS
# ============================================================

@router.post("/mermas", status_code=201)
def registrar_merma(body: MermaCreate, db: Session = Depends(get_db)):
    """
    HU-16: Reportar merma de un lote (daño o caducidad)
    Descuenta stock sin registrar ingreso económico
    """
    with UnitOfWork(db):
        # Verificar lote y stock disponible
        lote = db.execute(text("""
            SELECT fl.id, fl.stock_actual, fl.numero_lote, fm.nombre AS medicamento
            FROM farm_lotes_inventario fl
            JOIN farm_medicamentos fm ON fm.id = fl.medicamento_id
            WHERE fl.id = :lote_id
        """), {"lote_id": body.lote_id}).fetchone()

        if not lote:
            raise HTTPException(status_code=404, detail="Lote no encontrado")

        if lote.stock_actual < body.cantidad:
            raise HTTPException(
                status_code=400,
                detail=f"Stock insuficiente. Disponible: {lote.stock_actual}, solicitado: {body.cantidad}"
            )

        # Descontar stock del lote
        db.execute(text("""
            UPDATE farm_lotes_inventario
            SET stock_actual = stock_actual - :cantidad
            WHERE id = :lote_id
        """), {"cantidad": body.cantidad, "lote_id": body.lote_id})

        # Registrar en ventas_mermas
        merma = db.execute(text("""
            INSERT INTO ventas_mermas (lote_id, cantidad, motivo)
            VALUES (:lote_id, :cantidad, :motivo)
            RETURNING id, lote_id, cantidad, motivo
        """), {
            "lote_id": body.lote_id,
            "cantidad": body.cantidad,
            "motivo": body.motivo
        }).fetchone()

        # Registrar movimiento en inventario
        db.execute(text("""
            INSERT INTO farm_movimientos_inventario
                (lote_id, tipo, cantidad, referencia)
            VALUES
                (:lote_id, 'MERMA', :cantidad, :motivo)
        """), {
            "lote_id": body.lote_id,
            "cantidad": body.cantidad,
            "motivo": body.motivo
        })

        return {
            "id": merma.id,
            "lote_id": merma.lote_id,
            "numero_lote": lote.numero_lote,
            "medicamento": lote.medicamento,
            "cantidad_merma": merma.cantidad,
            "motivo": merma.motivo,
            "stock_restante": lote.stock_actual - body.cantidad
        }