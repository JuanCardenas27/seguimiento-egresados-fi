# Seguimiento de egresados de la Facultad de Ingeniería a partir de LinkedIn

Proceso **automatizado** para identificar en LinkedIn a los egresados de la Facultad de Ingeniería (Sede Bogotá), verificar su pertenencia, extraer y estandarizar su trayectoria profesional, controlar la calidad de los datos y consolidarlos en una base de datos relacional. Parte de un supuesto: **la única fuente es LinkedIn**, porque no se cuenta con el registro de graduados.

> Prueba técnica para la vinculación de estudiantes · Juan David Cárdenas Galvis · Ingeniería de Sistemas y Computación

![MariaDB](https://img.shields.io/badge/MariaDB-11.4_LTS-003545?logo=mariadb)
![Python](https://img.shields.io/badge/Python-3.12-3776AB?logo=python)
![Django](https://img.shields.io/badge/Django-5.2-092E20?logo=django)
![Docker](https://img.shields.io/badge/Docker-compose-2496ED?logo=docker)

## Por qué esta propuesta

- **Cubre a toda la población:** el *scraping* de perfiles públicos no depende de que cada egresado responda una encuesta.
- **Combina alcance y precisión:** el *scraping* aporta cobertura y actualización; la información que entregan los egresados aporta los datos más confiables. Ambos canales producen el mismo formato.
- **Es automática y reproducible:** un solo proceso programado descubre, verifica, estandariza y consolida, sin duplicar registros y conservando la fuente de cada dato.
- **Controla la calidad desde el origen:** rúbrica de pertenencia, validaciones en la base de datos e incidencias automáticas; la revisión humana queda para los casos dudosos.
- **Produce resultados comparables:** usa SNIES, CIIU, CIUO-08, DIVIPOLA e ISO 3166.
- **Protege los datos desde el diseño:** lista blanca de campos, purga a los 90 días y cifras agregadas.
- **Es económica y escalable:** software libre, un servidor y una API de búsqueda; otra facultad solo carga su catálogo de programas.
- **Está probada:** funciona de principio a fin con datos ficticios (20 pruebas de la base de datos y 25 pruebas unitarias).

## Entregables

| Requisito de la prueba | Dónde está |
|---|---|
| **3.1 Documento metodológico** | [`docs/Documento_Metodologico.docx`](docs/Documento_Metodologico.docx) (Word, normas APA) · [`docs/Documento_Metodologico.pdf`](docs/Documento_Metodologico.pdf) |
| **3.2 Diccionario de datos** | Documento, sección «Diccionario de datos» · [`db/01_esquema.sql`](db/01_esquema.sql) |
| **3.2 Estructura de almacenamiento y justificación** | Documento, sección «Estructura de almacenamiento» · [`db/01_esquema.sql`](db/01_esquema.sql) |
| **3.2 Identificación de registros** | Documento, sección «Identificación de registros» |
| **3.2 Estandarización** | Documento, sección «Estandarización» · [`db/02_catalogos.sql`](db/02_catalogos.sql) |
| **3.2 Control de calidad** | Documento, sección «Control de calidad» · [`db/03_vistas_procedimientos.sql`](db/03_vistas_procedimientos.sql) · [`db/04_pruebas_validacion.sql`](db/04_pruebas_validacion.sql) |
| **3.2 Datos de prueba** (10 casos ficticios) | [`app/etl/datos_ejemplo/`](app/etl/datos_ejemplo/) |
| **3.3 Repositorio en GitHub** | Este repositorio |

## Cómo funciona el proceso

1. **Descubrir.** Consultas por programa, en español e inglés (`site:linkedin.com/in "Universidad Nacional de Colombia" "Ingeniería Civil"`), a la API de un motor de búsqueda. Se normalizan las URL, se quitan los repetidos y se bloquean los perfiles de la lista de exclusión.
2. **Extraer.** Hay dos canales con el mismo formato de salida:
   - **Canal A (principal):** *web scraping* de la versión pública del perfil, sin iniciar sesión, a ritmo bajo y sin evadir controles. El repositorio incluye la primera versión del módulo (`conectores/scraping.py`); los perfiles de prueba simulan su salida.
   - **Canal B:** exportación de datos que entrega el propio egresado.

   Una lista blanca elimina los campos que no se necesitan, y una huella SHA-256 evita reprocesar los perfiles que no cambiaron.
3. **Verificar.** Una rúbrica de 0 a 100 evalúa institución, programa, condición de egresado, sede y coherencia. Con 80 puntos o más y un programa reconocido, el perfil se acepta. Entre 50 y 79 pasa a revisión manual. Con menos de 50, y en el caso de estudiantes o de otras sedes, se descarta y solo queda la huella.
4. **Estandarizar.** Se clasifican programa, nivel SNIES, CIIU Rev. 4 A.C., CIUO-08 A.C., nivel jerárquico, área, DIVIPOLA e ISO 3166-1 con diccionarios guardados en la base de datos.
5. **Consolidar.** Se hace un *upsert* por huellas. Las tablas tienen historial de versiones (`SYSTEM VERSIONING`).
6. **Controlar la calidad.** Se generan incidencias automáticas de información incompleta, ambigua, desactualizada, no verificable, posibles duplicados e inconsistencias.
7. **Publicar.** Vistas e indicadores agregados, en los que se ocultan los grupos de menos de cinco personas.

## Estructura del repositorio

```text
.
├── docs/
│   ├── Documento_Metodologico.docx   # Entregable 3.1 y 3.2 (APA)
│   └── Documento_Metodologico.pdf
├── db/                               # Se ejecutan en orden al crear la base de datos
│   ├── 01_esquema.sql                # Tablas, restricciones CHECK, triggers, evento de purga
│   ├── 02_catalogos.sql              # Catálogos estándar y diccionarios de homologación
│   ├── 03_vistas_procedimientos.sql  # Vistas, homologación, incidencias, fusión, supresión
│   ├── 04_pruebas_validacion.sql     # 20 pruebas automáticas de las reglas de la base
│   ├── 05_roles_usuarios.sh          # Roles con mínimo privilegio
│   ├── 06_lista_exclusion_prueba.sql # Titular ficticio que pidió no ser tratado
│   └── consultas/analisis.sql        # Consultas de los indicadores
├── app/
│   ├── etl/                          # Proceso automatizado (comando ejecutar_proceso)
│   │   ├── nucleo/                   # Normalización, fechas, geografía, verificación (rúbrica)
│   │   ├── conectores/               # Búsqueda, canal A (scraping), canal B (exportación), archivos de prueba
│   │   ├── datos_ejemplo/            # Perfiles y exportación ficticios
│   │   └── tests/                    # 25 pruebas unitarias
│   └── egresados/                    # API REST de solo lectura (Django REST Framework)
└── docker-compose.yml
```

## Cómo ejecutarlo

```bash
cp .env.example .env        # opcional: cambiar las contraseñas
docker compose up -d --build
```

La orquestación levanta tres servicios en orden:

| Servicio | Qué hace |
|---|---|
| `db` | Crea la base de datos y ejecuta los scripts de `db/`, incluidas las 20 pruebas de validación |
| `etl` | Ejecuta las pruebas unitarias y luego el proceso completo con los datos ficticios |
| `api` | Publica la API de consulta en http://127.0.0.1:8000 |

```bash
# Resultado de las pruebas de la base de datos
docker logs egresados-db 2>&1 | grep "pruebas superadas"

# Resumen de la ejecución del proceso (JSON)
docker logs egresados-etl

# Volver a ejecutarlo: es idempotente (no crea registros nuevos)
docker compose run --rm etl python manage.py ejecutar_proceso --canal archivo

# Consultas de análisis
docker exec -i egresados-db mariadb -uanalista -panalista_dev -t egresados_fi < db/consultas/analisis.sql
```

En producción, el comando `ejecutar_proceso` se programa con cron. El canal A se ejecuta con `--canal scraping`: `BuscadorHTTP` consulta la API de búsqueda y `ExtractorScraping` (`app/etl/conectores/scraping.py`) descarga y analiza la versión pública de cada perfil. Las exportaciones del canal B se cargan con `--etapas importar,procesar`.

### API de consulta

| Endpoint | Acceso | Descripción |
|---|---|---|
| `GET /api/indicadores/` | Público | Indicadores agregados; oculta los grupos de menos de cinco personas |
| `GET /api/egresados/?programa=3&cohorte=2019` | Autenticado | Egresados verificados |
| `GET /api/egresados/{id}/` | Autenticado | Trayectoria con la fuente de cada dato |
| `GET /api/incidencias/` · `GET /api/ejecuciones/` | Autenticado | Calidad y bitácora del proceso |
| `/admin/` | Autenticado | Administrador de Django (solo lectura) |

Credenciales de desarrollo: `admin` / `admin_dev`.

## Protección de datos

- El *scraping* (canal A) solo lee páginas públicas: no inicia sesión, no usa cuentas falsas y no evade controles como CAPTCHA o bloqueos.
- En el canal B, el egresado entrega sus datos con autorización expresa.
- Aplica minimización por lista blanca.
- El contenido de las capturas se purga a los 90 días.
- Se mantiene una lista de exclusión de titulares.
- Hay un procedimiento de supresión.
- Los roles siguen el principio de mínimo privilegio.

Todo se ajusta a la Ley 1581 de 2012 (detalle en el documento).

**Todos los datos del repositorio son ficticios.** No se recolectó información real de ningún egresado.
