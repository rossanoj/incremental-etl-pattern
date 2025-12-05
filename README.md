# Incremental ETL Pattern with Soft Delete

git remote set-url origin https://rossanoj@github.com/rossanoj/incremental-etl-pattern.git

Un patrón completo de ETL incremental con manejo de soft deletes, pensado para procesos de sincronización entre tablas origen-destino.

## 🎯 Objetivo

Este repositorio proporciona tres estrategias de carga de datos para diferentes escenarios:

1. **Carga inicial completa** (Full Load)
2. **Carga incremental** (solo nuevos/actualizados)
3. **Reprocesamiento** (con soft delete de registros eliminados)

## 📋 Características

- ✅ Manejo de inserts y updates mediante `MERGE`
- ✅ Soft delete de registros eliminados en origen
- ✅ Tablas temporales para staging
- ✅ Filtrado por fecha para optimizar cargas
- ✅ Parámetros configurables
- ✅ Verificaciones incluidas

## 🗂️ Estructura del Proyecto

```
scripts/
├── initial_load/
│   └── full_load.sql          # Primera carga completa
├── incremental/
│   └── incremental_load.sql   # Cargas regulares incrementales
└── reprocessing/
    └── full_reprocess.sql     # Reprocesamiento con soft delete
```

## 🚀 Guía de Uso

### 1️⃣ Primera Ejecución: Carga Inicial

Ejecutar **una sola vez** al iniciar el proceso:

```bash
# Crea las tablas y carga los datos iniciales
psql -f scripts/initial_load/full_load.sql
```

**¿Qué hace?**
- Crea tabla `origen_products` (fuente de datos)
- Crea tabla `destino_products` (con campos de control)
- Inserta 25 productos de ejemplo
- Realiza carga completa inicial

### 2️⃣ Cargas Regulares: Incremental

Ejecutar **periódicamente** (diario, horario, etc.):

```bash
# Solo carga registros nuevos o modificados
psql -f scripts/incremental/incremental_load.sql
```

**¿Qué hace?**
- Detecta registros con `updated_at` mayor al último procesado
- Actualiza productos existentes
- Inserta productos nuevos
- ⚠️ **NO elimina** productos que desaparecieron

**Ideal para:** Cargas automáticas frecuentes donde los deletes son raros.

### 3️⃣ Reprocesamiento: Full Reprocess

Ejecutar **cuando sea necesario** corregir o sincronizar:

```bash
# Reprocesa todo y marca inactivos los eliminados
psql -f scripts/reprocessing/full_reprocess.sql
```

**¿Qué hace?**
- Elimina registros obsoletos del origen
- Reprocesa datos de un rango de fechas específico
- Marca como inactivos (`is_active = FALSE`) los registros eliminados
- Reactiva registros que volvieron al origen

**Ideal para:** Correcciones, auditorías, o cuando se detectan inconsistencias.

## 📊 Esquema de Tablas

### Tabla Origen
```sql
origen_products (
    product_id   INT PRIMARY KEY,
    product_name TEXT,
    price        NUMERIC(10,2),
    created_at   TIMESTAMP,
    updated_at   TIMESTAMP
)
```

### Tabla Destino (con campos de control)
```sql
destino_products (
    product_id   INT PRIMARY KEY,
    product_name TEXT,
    price        NUMERIC(10,2),
    created_at   TIMESTAMP,
    updated_at   TIMESTAMP,
    is_active    BOOLEAN,      -- Control de soft delete
    inactive_at  TIMESTAMP      -- Fecha de inactivación
)
```

## 🔄 Flujo de Trabajo Típico

```
┌─────────────────────┐
│  1. Full Load       │  ← Solo primera vez
│  (25 productos)     │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  2. Incremental     │  ← Ejecuciones diarias/horarias
│  (+8 productos)     │     Solo carga nuevos/modificados
│  (7 actualizados)   │
└──────────┬──────────┘
           │
           ▼
┌─────────────────────┐
│  3. Reprocess       │  ← Cuando sea necesario
│  (-5 descontinuados)│     Sincroniza y marca inactivos
│  (rango: 2025-01+)  │
└─────────────────────┘
```

## ⚙️ Parámetros Configurables

En `full_reprocess.sql`, puedes ajustar:

```sql
-- Rango de fechas a reprocesar
WHERE created_at >= '2025-01-01 00:00:00'  -- ⬅️ Modificar según necesidad
   OR updated_at >= '2025-01-01 00:00:00'
```

## 🎭 Casos de Uso

### ✅ Usar Incremental cuando:
- Cargas automáticas frecuentes (cada hora, cada día)
- Los deletes son poco frecuentes
- Priorizas velocidad sobre precisión absoluta
- No necesitas detectar inmediatamente productos descontinuados

### ✅ Usar Reprocess cuando:
- Detectas inconsistencias en los datos
- Necesitas sincronizar completamente origen y destino
- Quieres limpiar productos obsoletos/descontinuados
- Después de una migración o corrección masiva
- Auditorías periódicas (semanal/mensual)

## 🔍 Verificación de Resultados

Cada script incluye una query de verificación al final:

```sql
SELECT 
    product_id,
    product_name,
    is_active,
    inactive_at,
    CASE 
        WHEN is_active THEN 'Activo'
        ELSE 'Inactivo'
    END AS estado
FROM destino_products 
ORDER BY product_id;
```

## 🛠️ Requisitos

- PostgreSQL 9.5+ (por el uso de `MERGE`)
- Permisos de `CREATE TABLE`, `INSERT`, `UPDATE`, `DELETE`
- Para bases de datos sin `MERGE`, ver [alternativas con UPSERT]

## 📝 Notas Importantes

1. **Soft Delete vs Hard Delete**: Este patrón usa soft delete (`is_active = FALSE`) para mantener histórico
2. **Idempotencia**: Los scripts pueden ejecutarse múltiples veces sin duplicar datos
3. **Performance**: El incremental es más rápido, el reprocess es más completo
4. **Tablas temporales**: Se limpian automáticamente al final de cada script

## 🤝 Contribuciones

Si tienes mejoras o casos de uso adicionales, ¡las contribuciones son bienvenidas!

## 📄 Licencia

MIT License - Libre para usar en proyectos comerciales y personales

---

**¿Dudas?** Revisa los comentarios dentro de cada script SQL, están completamente documentados paso a paso.