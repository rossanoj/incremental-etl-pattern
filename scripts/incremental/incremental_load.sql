/*
==============================================================================
SCRIPT: Incremental Load (SIN considerar borrados)
DESCRIPTION: Carga incremental basada en fecha de actualización
CUANDO USAR: Ejecuciones regulares para cargar solo nuevos/actualizados
NOTA: NO maneja registros borrados en origen (soft delete)
==============================================================================
*/

-- Simular nuevos datos en ORIGEN
-- ACTUALIZAR productos existentes (7 actualizaciones)
UPDATE origen_products
SET 
    price = CASE 
        WHEN product_id = 1 THEN 12.00
        WHEN product_id = 2 THEN 22.50
        WHEN product_id = 3 THEN 180.00
        WHEN product_id = 5 THEN 70.00
        WHEN product_id = 6 THEN 50.00
        WHEN product_id = 10 THEN 320.00
        WHEN product_id = 24 THEN 95.00
        ELSE price 
    END,
    updated_at = '2025-02-01 13:30' 
WHERE 
    product_id IN (1, 2, 3, 5, 6, 10, 24); 

INSERT INTO origen_products VALUES
(26, 'Teclado Ergonómico', 45.00, '2025-02-01 14:00', '2025-02-01 14:00'),
(27, 'Mouse Vertical', 35.00, '2025-02-01 14:30', '2025-02-01 14:30'),
(28, 'Monitor Curvo 27"', 280.00, '2025-02-01 15:00', '2025-02-01 15:00'),
(29, 'Micrófono USB', 55.00, '2025-02-01 15:30', '2025-02-01 15:30'),
(30, 'Silla Gaming', 199.00, '2025-02-01 16:00', '2025-02-01 16:00'),
(31, 'Escritorio Ajustable', 350.00, '2025-02-01 16:30', '2025-02-01 16:30'),
(32, 'Cooler RGB', 28.00, '2025-02-01 17:00', '2025-02-01 17:00'),
(33, 'Switch Ethernet 8 puertos', 42.00, '2025-02-01 17:30', '2025-02-01 17:30');

CREATE TEMP TABLE stg_products AS
SELECT *
FROM origen_products
WHERE updated_at > (
    SELECT COALESCE(MAX(updated_at), '1900-01-01')
    FROM destino_products
);

-- Ver qué se va a cargar
SELECT * FROM stg_products;

-- MERGE incremental
-- Actualiza existentes e inserta nuevos
-- NO marca inactivos los que desaparecieron
MERGE INTO destino_products AS d
USING stg_products AS s
ON d.product_id = s.product_id
WHEN MATCHED THEN
    UPDATE SET
        product_name = s.product_name,
        price        = s.price,
        updated_at   = s.updated_at,
        is_active    = TRUE,
        inactive_at  = NULL
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
    );

DROP TABLE IF EXISTS stg_products;

SELECT * FROM destino_products ORDER BY product_id;