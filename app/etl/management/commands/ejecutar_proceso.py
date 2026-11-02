"""Ejecuta el proceso completo o por etapas.

python manage.py ejecutar_proceso --canal archivo
python manage.py ejecutar_proceso --canal scraping --etapas descubrir,extraer,procesar
python manage.py ejecutar_proceso --datos /ruta/cargas --etapas importar,procesar
"""
import json
from pathlib import Path

from django.core.management.base import BaseCommand, CommandError

from etl import config
from etl.conectores.archivo import BuscadorArchivo, ExtractorArchivo
from etl.conectores.exportacion import leer_exportacion
from etl.proceso import Proceso

DATOS_EJEMPLO = Path(__file__).resolve().parents[2] / "datos_ejemplo"
ETAPAS = ("descubrir", "extraer", "importar", "procesar")


class Command(BaseCommand):
    help = "Descubre, extrae, verifica y consolida perfiles de egresados."

    def add_arguments(self, parser):
        parser.add_argument("--canal", choices=["archivo", "scraping"], default="archivo")
        parser.add_argument("--etapas", default=",".join(ETAPAS),
                            help="Etapas separadas por coma: " + ", ".join(ETAPAS))
        parser.add_argument("--datos", type=Path, default=DATOS_EJEMPLO, help="Carpeta del canal archivo")
        parser.add_argument("--dias-refresco", type=int, default=config.DIAS_REFRESCO)
        parser.add_argument("--limite", type=int, default=config.LIMITE_EXTRACCION)
        parser.add_argument("--meses-vigencia", type=int, default=config.MESES_VIGENCIA)

    def handle(self, *args, **op):
        etapas = [e.strip() for e in op["etapas"].split(",") if e.strip()]
        if invalidas := set(etapas) - set(ETAPAS):
            raise CommandError(f"Etapas desconocidas: {', '.join(invalidas)}")

        if not {"descubrir", "extraer"} & set(etapas):
            # Solo canal B: no se necesitan el buscador ni el scraper
            buscador = extractor = None
        elif op["canal"] == "archivo":
            buscador = BuscadorArchivo(op["datos"] / "busqueda" / "resultados.json")
            extractor = ExtractorArchivo(op["datos"] / "perfiles")
        else:
            from etl.conectores.http import BuscadorHTTP
            from etl.conectores.scraping import ExtractorScraping
            try:
                extractor = ExtractorScraping()
            except ValueError as e:
                raise CommandError(str(e)) from e
            buscador = BuscadorHTTP()

        proceso = Proceso()
        parametros = {k: (str(v) if isinstance(v, Path) else v) for k, v in op.items()
                      if k in ("canal", "etapas", "datos", "dias_refresco", "limite", "meses_vigencia")}
        nombre_etapa = {"descubrir": "DESCUBRIMIENTO", "extraer": "EXTRACCION",
                        "importar": "IMPORTACION", "procesar": "PROCESAMIENTO"}
        canal = extractor.codigo_canal if extractor else ("EXPORTACION_TITULAR" if "importar" in etapas else None)
        proceso.iniciar("COMPLETA" if len(etapas) > 1 else nombre_etapa[etapas[0]], canal, parametros)
        try:
            if "descubrir" in etapas:
                proceso.descubrir(buscador)
            if "extraer" in etapas:
                proceso.extraer(extractor, op["dias_refresco"], op["limite"])
            if "importar" in etapas:
                carpeta = op["datos"] / "exportaciones"
                for sub in sorted(p for p in carpeta.iterdir() if p.is_dir()) if carpeta.exists() else []:
                    proceso.importar_exportacion(leer_exportacion(sub, sub.name), sub.name)
            if "procesar" in etapas:
                proceso.procesar(op["meses_vigencia"])
        except Exception:
            proceso.finalizar("FALLIDA")
            raise
        estado = proceso.finalizar()
        resumen = {"id_ejecucion": proceso.id_ejecucion, "estado": estado, **dict(sorted(proceso.contadores.items()))}
        self.stdout.write(json.dumps(resumen, ensure_ascii=False, indent=2))
