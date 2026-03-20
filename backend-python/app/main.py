from fastapi import FastAPI
from app.api import inventario, catalogo, almacen, anulacion

app = FastAPI(
    title="Farmacia POS - Inventario Service",
    version="1.0.0",
    description="Backend Python - Gestión de inventario, catálogo y almacén"
)

# Módulo inventario (HU-29, HU-40)
app.include_router(inventario.router)

# Módulo catálogo (HU-06, HU-07, HU-08, HU-09, HU-10, HU-11)
app.include_router(catalogo.router)

# Módulo almacén (HU-12, HU-13, HU-14, HU-15, HU-16)
app.include_router(almacen.router)

# Módulo anulación (HU-37)
app.include_router(anulacion.router)

@app.get("/health")
def health():
    return {"status": "ok", "service": "inventario-python"}