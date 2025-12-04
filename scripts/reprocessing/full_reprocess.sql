/*
==============================================================================
SCRIPT: Full Reprocessing with Soft Delete
DESCRIPTION: Reprocesamiento completo con manejo de registros eliminados
CUANDO USAR: Cuando necesitas sincronizar completamente origen y destino
             detectando y marcando productos descontinuados/eliminados
==============================================================================
*/

-- Eliminar productos obsoletos del ORIGEN
-- (Simula productos descontinuados que ya no existen en el sistema fuente)
DELETE FROM origen_products WHERE product_id IN (
    3,  -- Monitor LED 24" (descontinuado)
    9,  -- Tarjeta SD 64GB (fuera de stock)
    16, -- Cable HDMI 2m (descontinuado)
    19, -- Lámpara LED Escritorio (sin proveedor)
    22  -- Chromebook (fin de línea)
);

-- Crear tabla temporal para reprocesar
-- Filtra por rango de fechas (parametrizable según necesidad)
CREATE TEMP TABLE stg_reprocess AS
SELECT *
FROM origen_products
WHERE created_at >= '2025-01-01 00:00:00' 
   OR updated_at >= '2025-01-01 00:00:00'; 

-- Ver qué se va a reprocesar
SELECT * FROM stg_reprocess ORDER BY product_id;

-- 🟦 PASO 3: MERGE completo con soft delete
-- Este MERGE hace 3 cosas:
--   1. MATCHED: actualiza registros que existen en origen
--   2. NOT MATCHED: inserta nuevos registros
--   3. NOT MATCHED BY SOURCE: marca como inactivos los que ya NO están en origen
MERGE INTO destino_products AS d
USING stg_reprocess AS s
ON d.product_id = s.product_id
-- 1 Si existe en ORIGEN y DESTINO → ACTUALIZAR
WHEN MATCHED THEN
    UPDATE SET
        product_name = s.product_name,
        price        = s.price,
        updated_at   = s.updated_at,
        is_active    = TRUE,
        inactive_at  = NULL
-- 2 Si existe en ORIGEN pero NO en DESTINO → INSERTAR
WHEN NOT MATCHED THEN
    INSERT (
        product_id, 
        product_name, 
        price,
        created_at, 
        updated_at,
        is_active, 
        inactive_at
    )
    VALUES (
        s.product_id, 
        s.product_name, 
        s.price,
        s.created_at, 
        s.updated_at,
        TRUE, 
        NULL
    )
--  3 Si existe en DESTINO pero NO en ORIGEN → MARCAR INACTIVO (soft delete)
WHEN NOT MATCHED BY SOURCE 
    -- Solo marca inactivos los que están en el rango de reproceso
    AND d.created_at >= '2025-01-01 00:00:00'
THEN
    UPDATE SET 
        is_active   = FALSE,
        inactive_at = NOW();

DROP TABLE IF EXISTS stg_reprocess;

SELECT *
    FROM destino_products 
    ORDER BY product_id;