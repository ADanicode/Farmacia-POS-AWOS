"""
Módulo Anulación - HU-37
Reintegro de stock al anular una venta
"""

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import text
from pydantic import BaseModel, Field
from app.db.dependencies import get_db
from app.uow.uow import UnitOfWork

router = APIRouter(prefix="/api/v1/inventario")


# ============================================================
# MODELOS
# ============================================================

class ReintegrarRequest(BaseModel):
    ventaId: str = Field(..., min_length=1)
    motivo: str = Field(..., min_length=1)


# ============================================================
# HU-37: REINTEGRO DE STOCK POR ANULACIÓN
# ============================================================

@router.post("/reintegrar")
def reintegrar_stock(body: ReintegrarRequest, db: Session = Depends(get_db)):
    """
    HU-37: Reintegrar stock al anular un ticket
    Busca todos los movimientos VENTA de esa ventaId y los revierte
    """
    with UnitOfWork(db):
        # Buscar todos los movimientos de esa venta
        movimientos = db.execute(text("""
            SELECT fm.id, fm.lote_id, fm.cantidad, fl.medicamento_id
            FROM farm_movimientos_inventario fm
            JOIN farm_lotes_inventario fl ON fl.id = fm.lote_id
            WHERE fm.referencia = :venta_id
              AND fm.tipo = 'VENTA'
        """), {"venta_id": body.ventaId}).fetchall()

        if not movimientos:
            raise HTTPException(
                status_code=404,
                detail=f"No se encontraron movimientos para la venta {body.ventaId}"
            )

        reintegrados = []

        for mov in movimientos:
            # Reintegrar al lote original
            db.execute(text("""
                UPDATE farm_lotes_inventario
                SET stock_actual = stock_actual + :cantidad
                WHERE id = :lote_id
            """), {"cantidad": mov.cantidad, "lote_id": mov.lote_id})

            # Registrar movimiento de anulación
            db.execute(text("""
                INSERT INTO farm_movimientos_inventario
                    (lote_id, tipo, cantidad, referencia)
                VALUES
                    (:lote_id, 'ANULACION', :cantidad, :referencia)
            """), {
                "lote_id": mov.lote_id,
                "cantidad": mov.cantidad,
                "referencia": body.ventaId
            })

            reintegrados.append({
                "lote_id": mov.lote_id,
                "medicamento_id": mov.medicamento_id,
                "cantidad_reintegrada": mov.cantidad
            })

        return {
            "ventaId": body.ventaId,
            "motivo": body.motivo,
            "total_lineas_reintegradas": len(reintegrados),
            "detalle": reintegrados
        }