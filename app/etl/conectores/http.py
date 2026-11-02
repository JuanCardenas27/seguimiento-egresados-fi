"""Cliente de la API del motor de búsqueda (descubrimiento de perfiles)."""
import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request

from .base import Buscador, ResultadoBusqueda


def _solicitar(url: str, llave: str, intentos: int = 4, pausa: float = 1.0) -> dict:
    peticion = urllib.request.Request(url, headers={"Authorization": f"Bearer {llave}", "Accept": "application/json"})
    for intento in range(intentos):
        try:
            with urllib.request.urlopen(peticion, timeout=30) as resp:
                return json.loads(resp.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            if e.code != 429 and e.code < 500:
                raise
        except urllib.error.URLError:
            pass
        time.sleep(pausa * 2 ** intento)
    raise RuntimeError(f"Sin respuesta después de {intentos} intentos: {url}")


class BuscadorHTTP(Buscador):
    def __init__(self, traducir=lambda r: [ResultadoBusqueda(i["link"], i.get("title")) for i in r.get("items", [])],
                 pausa: float = 1.0):
        self.url = os.environ["BUSCADOR_URL"]
        self.llave = os.environ["BUSCADOR_LLAVE"]
        self.traducir = traducir
        self.pausa = pausa

    def buscar(self, consulta: str) -> list[ResultadoBusqueda]:
        time.sleep(self.pausa)
        url = self.url.format(consulta=urllib.parse.quote(consulta))
        return self.traducir(_solicitar(url, self.llave))
