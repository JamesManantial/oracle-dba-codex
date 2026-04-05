# 🗄️ Database Management

## About
Personal repository of an Oracle DBA and Oracle ACE Apprentice. 
Contains scripts, guides and best practices for Oracle Database administration.
Content is primarily in Spanish to contribute to the Hispanic Oracle community.


## Acerca de este repositorio
Repositorio personal de scripts y guías para administración de Oracle Database.
El contenido está orientado a la comunidad hispanohablante de Oracle.

## Autor
- **Nombre:** Jaime Sanchez
- **Rol:** DBA Oracle , Cloud and FinOps
- **Programa:** Oracle ACE Apprentice
- **Contacto:** jaime.sanchez.ocp@gmail.com


## Estándar de nomenclatura

Los scripts siguen la siguiente convención:
```
[prefijo]_[NNN]_[categoria]_[accion]_[detalle].sql
```

| Parte | Descripción | Ejemplo |
|---|---|---|
| `prefijo` | Área del script | `adm` |
| `NNN` | Correlativo global único | `001` |
| `categoria` | Tema específico | `storage` |
| `accion` | Qué hace el script | `monitor` |
| `detalle` | Sobre qué actúa | `storage_growth` |

### Prefijos disponibles

| Prefijo | Área |
|---|---|
| `adm` | Administration |

### Categorías disponibles

| Categoría | Descripción |
|---|---|
| `storage` | Gestión de almacenamiento |
| `backup` | Respaldo y recuperación |
| `security` | Seguridad y auditoría |
| `dataguard` | Alta disponibilidad |

### Ejemplo
`adm_001_storage_monitor_storage_growth.sql`


## Uso
Cada script contiene un encabezado con:
- Descripción
- Prerrequisitos
- Parámetros
- Uso
- Ejemplo de salidas

## 📦 Inventario de Scripts

| Script                 | Descripción                                      | Versión | Fecha creación | Última actualización |
|----------------------|--------------------------------------------------|--------|---------------- |----------------------|
| adm_001_storage_monitor_storage_growth.sql  | Reporte de crecimiento Storage  | 1.0   | 2026-03-30  | 2026-03-30  |
| adm_002_security_controlar_accesos.sql  | Controla acceesos de usuarios en el login  | 1.0  | 2026-04-04  | 2026-04-04  |