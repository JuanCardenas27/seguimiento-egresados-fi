"""Parámetros del proceso automatizado (se pueden sobrescribir con variables de entorno)."""
import os

VERSION = "1.0.0"

# una consulta en español y otra en inglés por programa
PLANTILLAS_BUSQUEDA = (
    'site:linkedin.com/in "Universidad Nacional de Colombia" "{termino}"',
    'site:linkedin.com/in "National University of Colombia" "{termino_en}"',
)
NOMBRES_EN_INGLES = {
    "Ingeniería Agrícola": "Agricultural Engineering",
    "Ingeniería Civil": "Civil Engineering",
    "Ingeniería de Sistemas y Computación": "Systems and Computing Engineering",
    "Ingeniería Eléctrica": "Electrical Engineering",
    "Ingeniería Electrónica": "Electronic Engineering",
    "Ingeniería Industrial": "Industrial Engineering",
    "Ingeniería Mecánica": "Mechanical Engineering",
    "Ingeniería Mecatrónica": "Mechatronics Engineering",
    "Ingeniería Química": "Chemical Engineering",
}

# días para volver a capturar un perfil
DIAS_REFRESCO = int(os.environ.get("ETL_DIAS_REFRESCO", 90))
# máximo de perfiles por ejecución
LIMITE_EXTRACCION = int(os.environ.get("ETL_LIMITE_EXTRACCION", 500))
# días que se guarda el contenido de una captura
DIAS_RETENCION = int(os.environ.get("ETL_DIAS_RETENCION", 90))
# más viejo que esto se marca DESACTUALIZADO
MESES_VIGENCIA = int(os.environ.get("ETL_MESES_VIGENCIA", 12))
# fallos seguidos antes de marcarlo NO_DISPONIBLE
FALLOS_NO_DISPONIBLE = 2
