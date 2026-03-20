from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import List, Optional
from app.db.dependencies import get_db
from app.services.inventario_service import InventarioService
from app.uow.uow import UnitOfWork

router = APIRouter(prefix="/api/v1/inventario")

class LineaDescontar(BaseModel):
    codigoProducto: str
    cantidad: int
    lote: Optional[str] = None

class DescontarRequest(BaseModel):
    ventaId: str
    lineas: List[LineaDescontar]

class CompensarRequest(BaseModel):
    ventaId: str
    lineas: List[LineaDescontar]

@router.post("/descontar")
def descontar(body: DescontarRequest, db: Session = Depends(get_db)):
    try:
        with UnitOfWork(db):
            service = InventarioService(db)
            resultado = service.descontar_stock(body.ventaId, body.lineas)
            return {"detalle": resultado}
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/compensar")
def compensar(body: CompensarRequest, db: Session = Depends(get_db)):
    try:
        with UnitOfWork(db):
            service = InventarioService(db)
            service.compensar_stock(body.ventaId, body.lineas)
            return {"status": "ok"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))