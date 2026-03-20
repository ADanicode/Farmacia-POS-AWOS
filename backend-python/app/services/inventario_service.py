from sqlalchemy.orm import Session
from sqlalchemy import text


class InventarioService:

    def __init__(self, db: Session):
        self.db = db

    def descontar_stock(self, venta_id: str, lineas: list) -> list:
        resultado = []

        for linea in lineas:
            # Node envía codigoProducto (que es el ID del medicamento)
            medicamento_id = int(linea.codigoProducto)
            cantidad_requerida = linea.cantidad

            # FEFO: lote más próximo a vencer con stock suficiente
            # FOR UPDATE: bloqueo pesimista para evitar sobreventa (HU-40)
            lote = self.db.execute(text("""
                SELECT id, stock_actual, fecha_caducidad
                FROM farm_lotes_inventario
                WHERE medicamento_id = :med_id
                  AND stock_actual >= :cantidad
                  AND fecha_caducidad >= CURRENT_DATE
                ORDER BY fecha_caducidad ASC
                LIMIT 1
                FOR UPDATE
            """), {
                "med_id": medicamento_id,
                "cantidad": cantidad_requerida
            }).fetchone()

            if not lote:
                raise ValueError(
                    f"Stock insuficiente para medicamento {medicamento_id}"
                )

            # Descontar stock
            self.db.execute(text("""
                UPDATE farm_lotes_inventario
                SET stock_actual = stock_actual - :cantidad
                WHERE id = :lote_id
            """), {
                "cantidad": cantidad_requerida,
                "lote_id": lote.id
            })

            # Registrar movimiento
            self.db.execute(text("""
                INSERT INTO farm_movimientos_inventario
                    (lote_id, tipo, cantidad, referencia)
                VALUES
                    (:lote_id, 'VENTA', :cantidad, :referencia)
            """), {
                "lote_id": lote.id,
                "cantidad": cantidad_requerida,
                "referencia": venta_id
            })

            resultado.append({
                "lote_id": lote.id,
                "medicamento_id": medicamento_id,
                "cantidad_descontada": cantidad_requerida,
                "fecha_caducidad": str(lote.fecha_caducidad)
            })

        return resultado

    def compensar_stock(self, venta_id: str, lineas: list) -> None:
        for linea in lineas:
            medicamento_id = int(linea.codigoProducto)

            movimiento = self.db.execute(text("""
                SELECT fm.lote_id, fm.cantidad
                FROM farm_movimientos_inventario fm
                JOIN farm_lotes_inventario fl ON fl.id = fm.lote_id
                WHERE fm.referencia = :venta_id
                  AND fl.medicamento_id = :med_id
                  AND fm.tipo = 'VENTA'
                LIMIT 1
            """), {
                "venta_id": venta_id,
                "med_id": medicamento_id
            }).fetchone()

            if not movimiento:
                continue

            self.db.execute(text("""
                UPDATE farm_lotes_inventario
                SET stock_actual = stock_actual + :cantidad
                WHERE id = :lote_id
            """), {
                "cantidad": movimiento.cantidad,
                "lote_id": movimiento.lote_id
            })

            self.db.execute(text("""
                INSERT INTO farm_movimientos_inventario
                    (lote_id, tipo, cantidad, referencia)
                VALUES
                    (:lote_id, 'COMPENSACION', :cantidad, :referencia)
            """), {
                "lote_id": movimiento.lote_id,
                "cantidad": movimiento.cantidad,
                "referencia": venta_id
            })