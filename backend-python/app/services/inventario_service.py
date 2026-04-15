from sqlalchemy.orm import Session
from sqlalchemy import text


class InventarioService:

    def __init__(self, db: Session):
        self.db = db
        self._movimientos_columns_cache = None

    def _obtener_columnas_movimientos(self) -> set:
        if self._movimientos_columns_cache is not None:
            return self._movimientos_columns_cache

        rows = self.db.execute(text("""
            SELECT column_name
            FROM information_schema.columns
            WHERE table_name = 'farm_movimientos_inventario'
        """)).fetchall()

        self._movimientos_columns_cache = {row.column_name for row in rows}
        return self._movimientos_columns_cache

    def _first_existing_column(self, columnas_existentes: set, candidatas: list):
        for col in candidatas:
            if col in columnas_existentes:
                return col
        return None

    def _registrar_receta_auxiliar(self, venta_id: str, datos_receta) -> None:
        if not datos_receta:
            return

        tablas_candidatas = [
            "auditoria_recetas",
            "farm_auditoria_recetas",
            "farm_recetas_retenidas",
            "recetas_retenidas",
        ]

        for tabla in tablas_candidatas:
            try:
                existe = self.db.execute(text("""
                    SELECT 1
                    FROM information_schema.tables
                    WHERE table_name = :table_name
                    LIMIT 1
                """), {"table_name": tabla}).fetchone()

                if not existe:
                    continue

                rows = self.db.execute(text("""
                    SELECT column_name
                    FROM information_schema.columns
                    WHERE table_name = :table_name
                """), {"table_name": tabla}).fetchall()
                columnas = {row.column_name for row in rows}

                referencia_col = self._first_existing_column(
                    columnas,
                    ["referencia", "venta_id", "ventaid", "folio", "ticket_id"],
                )
                ci_col = self._first_existing_column(
                    columnas,
                    ["ci_medico", "cedula_medico", "medico_ci", "ci_doctor"],
                )
                nombre_col = self._first_existing_column(
                    columnas,
                    ["nombre_medico", "medico_nombre", "nombre_doctor"],
                )
                fecha_col = self._first_existing_column(
                    columnas,
                    ["fecha_receta", "receta_fecha", "fecha_prescripcion"],
                )

                columnas_insert = []
                valores_insert = {}

                if referencia_col:
                    columnas_insert.append(referencia_col)
                    valores_insert[referencia_col] = venta_id
                if ci_col and getattr(datos_receta, 'ciMedico', None):
                    columnas_insert.append(ci_col)
                    valores_insert[ci_col] = datos_receta.ciMedico
                if nombre_col and getattr(datos_receta, 'nombreMedico', None):
                    columnas_insert.append(nombre_col)
                    valores_insert[nombre_col] = datos_receta.nombreMedico
                if fecha_col and getattr(datos_receta, 'fechaReceta', None):
                    columnas_insert.append(fecha_col)
                    valores_insert[fecha_col] = datos_receta.fechaReceta

                # Si solo hay referencia y no hay datos de receta útiles, insertamos el ticket sin receta.
                if not columnas_insert:
                    continue

                col_sql = ", ".join(columnas_insert)
                val_sql = ", ".join([f":{c}" for c in columnas_insert])

                self.db.execute(text(
                    f"INSERT INTO {tabla} ({col_sql}) VALUES ({val_sql})"
                ), valores_insert)
                # Insertó exitosamente en una tabla candidata; no seguir intentando.
                return
            except Exception:
                # El esquema real puede tener restricciones adicionales. Intentamos con la siguiente tabla.
                continue

    def _insertar_movimiento_venta(self, lote_id: int, cantidad: int, venta_id: str, datos_receta) -> None:
        columnas_mov = self._obtener_columnas_movimientos()
        columnas_insert = ["lote_id", "tipo", "cantidad", "referencia"]
        valores_insert = {
            "lote_id": lote_id,
            "tipo": "VENTA",
            "cantidad": cantidad,
            "referencia": venta_id,
        }

        ci_col = self._first_existing_column(
            columnas_mov,
            ["ci_medico", "cedula_medico", "medico_ci", "ci_doctor"],
        )
        nombre_col = self._first_existing_column(
            columnas_mov,
            ["nombre_medico", "medico_nombre", "nombre_doctor"],
        )
        fecha_col = self._first_existing_column(
            columnas_mov,
            ["fecha_receta", "receta_fecha", "fecha_prescripcion"],
        )

        if ci_col:
            columnas_insert.append(ci_col)
            valores_insert[ci_col] = getattr(datos_receta, 'ciMedico', None)
        if nombre_col:
            columnas_insert.append(nombre_col)
            valores_insert[nombre_col] = getattr(datos_receta, 'nombreMedico', None)
        if fecha_col:
            columnas_insert.append(fecha_col)
            valores_insert[fecha_col] = getattr(datos_receta, 'fechaReceta', None)

        col_sql = ", ".join(columnas_insert)
        val_sql = ", ".join([f":{c}" for c in columnas_insert])
        self.db.execute(text(
            f"INSERT INTO farm_movimientos_inventario ({col_sql}) VALUES ({val_sql})"
        ), valores_insert)

    def _lineas_requieren_receta(self, lineas: list) -> bool:
        for linea in lineas:
            medicamento_id = int(linea.codigoProducto)
            row = self.db.execute(text("""
                SELECT requiere_receta
                FROM farm_medicamentos
                WHERE id = :id
                LIMIT 1
            """), {"id": medicamento_id}).fetchone()

            if row and getattr(row, "requiere_receta", False):
                return True

        return False

    def descontar_stock(self, venta_id: str, lineas: list, datos_receta=None) -> list:
        resultado = []

        # Algunos esquemas validan receta en trigger consultando tablas auxiliares.
        # Registramos primero la receta si aplica para que la inserción de movimientos pueda pasar.
        if datos_receta or self._lineas_requieren_receta(lineas):
            receta_obj = datos_receta if datos_receta else type(
                "DatosRecetaDummy",
                (),
                {"ciMedico": None, "nombreMedico": None, "fechaReceta": None}
            )()
            self._registrar_receta_auxiliar(venta_id, receta_obj)

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

            self._insertar_movimiento_venta(
                lote.id,
                cantidad_requerida,
                venta_id,
                datos_receta,
            )

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