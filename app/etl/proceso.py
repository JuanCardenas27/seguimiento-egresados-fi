"""Proceso automatizado: descubrir, extraer y procesar."""
import json
import logging
from collections import Counter
from datetime import date, datetime, timedelta

from django.db import connections, transaction

from . import config
from .conectores.base import (Buscador, Extractor, FuenteBloqueada, PerfilCapturado, PerfilNoDisponible,
                              PerfilRestringido)
from .nucleo import fechas, geografia, organizaciones, vinculo
from .nucleo.perfil import hash_contenido, minimizar, serializar
from .nucleo.texto import huella, id_empresa_desde_url, id_publico_desde_url, sha256
from .nucleo.verificacion import Reglas, evaluar

log = logging.getLogger("etl")
ALIAS_BD = "egresados"


class Proceso:
    def __init__(self, hoy: date | None = None):
        self.conexion = connections[ALIAS_BD]
        self.hoy = hoy or date.today()
        self.contadores = Counter()
        self.id_ejecucion = None
        self._reglas = None

    def _q(self, sql, params=(), uno=False):
        with self.conexion.cursor() as cur:
            cur.execute(sql, params)
            if cur.description is None:
                return cur.lastrowid
            columnas = [c[0] for c in cur.description]
            filas = [dict(zip(columnas, f)) for f in cur.fetchall()]
        return (filas[0] if filas else None) if uno else filas

    def _incidencia(self, tipo, entidad, id_registro, id_egresado, descripcion, clave=""):
        """Registra la incidencia; si ya existía resuelta y el problema reaparece, la reabre."""
        self._q("""INSERT INTO incidencia_calidad (codigo_tipo, entidad, id_registro, clave, id_egresado, descripcion)
                   VALUES (%s, %s, %s, %s, %s, %s)
                   ON DUPLICATE KEY UPDATE descripcion = VALUES(descripcion), id_egresado = VALUES(id_egresado),
                          detectada_en = IF(estado = 'RESUELTA', CURRENT_TIMESTAMP, detectada_en),
                          resuelta_en  = IF(estado = 'RESUELTA', NULL, resuelta_en),
                          resuelta_por = IF(estado = 'RESUELTA', NULL, resuelta_por),
                          estado       = IF(estado = 'RESUELTA', 'ABIERTA', estado)""",
                (tipo, entidad, id_registro, clave, id_egresado, descripcion[:500]))

    def iniciar(self, etapa: str, canal: str | None, parametros: dict):
        self.id_ejecucion = self._q(
            """INSERT INTO ejecucion (etapa, codigo_canal, version_proceso, parametros)
               VALUES (%s, %s, %s, %s)""", (etapa, canal, config.VERSION, json.dumps(parametros)))
        return self.id_ejecucion

    def finalizar(self, estado: str | None = None):
        c = self.contadores
        estado = estado or ("PARCIAL" if c["errores"] else "EXITOSA")
        self._q("""UPDATE ejecucion SET finalizada_en = NOW(), estado = %s, registros_leidos = %s,
                          registros_nuevos = %s, registros_sin_cambio = %s, registros_descartados = %s, errores = %s
                    WHERE id_ejecucion = %s""",
                (estado, c["leidos"], c["nuevos"], c["sin_cambio"], c["descartados"], c["errores"], self.id_ejecucion))
        return estado

    @property
    def reglas(self) -> Reglas:
        if self._reglas is None:
            inst = self._q("SELECT patron, resultado, prioridad FROM regla_institucion")
            niv = self._q("SELECT patron, codigo_nivel AS resultado, prioridad FROM regla_nivel_formacion")
            prog = self._q("""SELECT r.patron, CONCAT(r.id_programa, ':', p.codigo_nivel) AS resultado, r.prioridad
                                FROM regla_programa r JOIN cat_programa p ON p.id_programa = r.id_programa""")
            filas = lambda rs: [(r["patron"], r["resultado"], r["prioridad"]) for r in rs]  # noqa: E731
            self._reglas = Reglas(
                institucion=Reglas.compilar(filas(inst)),
                nivel=Reglas.compilar(filas(niv)),
                programa=Reglas.compilar(filas(prog), lambda v: (int(v.split(":")[0]), v.split(":")[1])),
            )
            self.alias_ubicacion = {r["texto_normalizado"]: (r["codigo_pais"], r["codigo_municipio"])
                                    for r in self._q("SELECT * FROM alias_ubicacion")}
            self.industria = {r["industria_linkedin"].lower(): r["codigo_seccion_ciiu"]
                              for r in self._q("SELECT * FROM equivalencia_industria")}
            self.tipo_empresa = {r["tipo_linkedin"].lower(): r["codigo_tipo"]
                                 for r in self._q("SELECT * FROM equivalencia_tipo_empresa")}
            self.org_por_base = {organizaciones.nombre_base(r["nombre_normalizado"]): r["id_organizacion"]
                                 for r in self._q("SELECT id_organizacion, nombre_normalizado FROM organizacion")}
        return self._reglas

    def _excluidos(self) -> set[str]:
        return {r["hash_id_publico"] for r in self._q("SELECT hash_id_publico FROM lista_exclusion")}

    # 1. Descubrir
    def descubrir(self, buscador: Buscador) -> Counter:
        excluidos = self._excluidos()
        programas = self._q("SELECT nombre FROM cat_programa WHERE codigo_nivel = 'PREGRADO' ORDER BY id_programa")
        consultas = [plantilla.format(termino=p["nombre"], termino_en=config.NOMBRES_EN_INGLES.get(p["nombre"], p["nombre"]))
                     for p in programas for plantilla in config.PLANTILLAS_BUSQUEDA]
        for consulta in consultas:
            for resultado in buscador.buscar(consulta):
                self.contadores["leidos"] += 1
                id_pub = id_publico_desde_url(resultado.url)
                if id_pub is None:  # publicaciones, empresas, grupos...
                    self.contadores["ignorados_no_perfil"] += 1
                    continue
                h = sha256(id_pub)
                excluido = h in excluidos
                nuevo = self._q(
                    """INSERT IGNORE INTO candidato (hash_id_publico, id_publico_linkedin, consulta_origen,
                                                     id_ejecucion, estado, motivo_estado)
                       VALUES (%s, %s, %s, %s, %s, %s)""",
                    (h, None if excluido else id_pub, consulta[:300], self.id_ejecucion,
                     "EXCLUIDO" if excluido else "PENDIENTE", "LISTA_EXCLUSION" if excluido else None))
                # INSERT IGNORE devuelve 0 cuando el perfil ya era conocido
                self.contadores["candidatos_nuevos" if nuevo else "candidatos_conocidos"] += 1
                if excluido:
                    self.contadores["bloqueados_lista_exclusion"] += 1
        return self.contadores

    # 2. Extraer
    def extraer(self, extractor: Extractor, dias_refresco=config.DIAS_REFRESCO,
                limite=config.LIMITE_EXTRACCION) -> Counter:
        excluidos = self._excluidos()
        pendientes = self._q(
            """SELECT id_candidato, id_publico_linkedin, hash_id_publico, intentos_fallidos
                 FROM candidato
                WHERE id_publico_linkedin IS NOT NULL
                  -- los perfiles del canal consentido se actualizan con una nueva exportación
                  AND COALESCE(consulta_origen, '') <> 'EXPORTACION_TITULAR'
                  -- una cuenta fusionada en otro registro ya no se consulta
                  AND NOT EXISTS (SELECT 1 FROM egresado e WHERE e.id_candidato = candidato.id_candidato
                                     AND e.estado_registro = 'FUSIONADO')
                  AND (estado = 'PENDIENTE'
                       OR (estado IN ('EXTRAIDO', 'NO_DISPONIBLE')
                           AND ultimo_intento_en < NOW() - INTERVAL %s DAY))
                ORDER BY ultimo_intento_en IS NOT NULL, ultimo_intento_en
                LIMIT %s""", (dias_refresco, limite))
        # perfiles con muro: solo cuentan como no disponibles si la fuente no resulta bloqueada
        restringidos = []
        for cand in pendientes:
            self.contadores["leidos"] += 1
            if cand["hash_id_publico"] in excluidos:
                self._excluir_candidato(cand["id_candidato"], "LISTA_EXCLUSION")
                continue
            try:
                capturado = extractor.obtener(cand["id_publico_linkedin"])
            except PerfilRestringido:
                restringidos.append(cand)
                continue
            except PerfilNoDisponible:
                self._no_disponible(cand)
                continue
            except FuenteBloqueada:
                # se reintenta en la siguiente ejecución; los muros previos eran parte del bloqueo
                log.warning("Fuente bloqueada; extracción detenida en %s", cand["id_publico_linkedin"])
                self.contadores["errores"] += 1
                self.contadores["extraccion_detenida_por_bloqueo"] += 1
                restringidos.clear()
                break
            except Exception as e:  # sigue con el siguiente
                log.exception("Error extrayendo %s", cand["id_publico_linkedin"])
                self.contadores["errores"] += 1
                self._q("UPDATE candidato SET ultimo_intento_en = NOW() WHERE id_candidato = %s",
                        (cand["id_candidato"],))
                continue
            self._guardar_captura(cand, capturado, extractor.codigo_canal)
        for cand in restringidos:
            self._no_disponible(cand)
        return self.contadores

    def importar_exportacion(self, capturado: PerfilCapturado, id_publico: str) -> Counter:
        """Canal consentido: la exportación entregada por el egresado."""
        self.contadores["leidos"] += 1
        h = sha256(id_publico)
        if h in self._excluidos():
            self.contadores["descartados"] += 1
            return self.contadores
        self._q("""INSERT IGNORE INTO candidato (hash_id_publico, id_publico_linkedin, consulta_origen, id_ejecucion)
                   VALUES (%s, %s, 'EXPORTACION_TITULAR', %s)""", (h, id_publico, self.id_ejecucion))
        cand = self._q("SELECT id_candidato, id_publico_linkedin, hash_id_publico, intentos_fallidos "
                       "FROM candidato WHERE hash_id_publico = %s", (h,), uno=True)
        if cand["id_publico_linkedin"] is None:  # descartado o excluido antes
            self._q("UPDATE candidato SET id_publico_linkedin = %s, estado = 'PENDIENTE', motivo_estado = NULL "
                    "WHERE id_candidato = %s", (id_publico, cand["id_candidato"]))
            cand["id_publico_linkedin"] = id_publico
        self._guardar_captura(cand, capturado, "EXPORTACION_TITULAR")
        return self.contadores

    def _guardar_captura(self, cand: dict, capturado: PerfilCapturado, canal: str):
        perfil = minimizar(capturado.crudo)
        perfil["id_publico"] = cand["id_publico_linkedin"]
        h = hash_contenido(perfil)
        previa = self._q("""SELECT hash_contenido FROM captura WHERE id_candidato = %s
                             ORDER BY capturada_en DESC, id_captura DESC LIMIT 1""", (cand["id_candidato"],), uno=True)
        if previa is None:
            resultado = "NUEVO"
        elif previa["hash_contenido"] == h:
            resultado = "SIN_CAMBIOS"
        else:
            resultado = "CON_CAMBIOS"
        expira = capturado.capturado_en.date() + timedelta(days=config.DIAS_RETENCION)
        with transaction.atomic(using=ALIAS_BD):
            id_captura = self._q(
                """INSERT INTO captura (id_candidato, id_ejecucion, codigo_canal, capturada_en, hash_contenido,
                                        contenido, expira_en, resultado, procesada)
                   VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)""",
                (cand["id_candidato"], self.id_ejecucion, canal, capturado.capturado_en, h,
                 None if resultado == "SIN_CAMBIOS" else serializar(perfil), expira, resultado,
                 resultado == "SIN_CAMBIOS"))
            self._q("""UPDATE candidato SET estado = 'EXTRAIDO', motivo_estado = NULL, ultimo_intento_en = NOW(),
                              intentos_fallidos = 0 WHERE id_candidato = %s""", (cand["id_candidato"],))
            if resultado == "SIN_CAMBIOS":
                self._q("""UPDATE egresado SET ultima_captura_en = GREATEST(ultima_captura_en, %s),
                                  id_ultima_captura = %s, estado_registro = IF(estado_registro = 'NO_DISPONIBLE',
                                  'ACTIVO', estado_registro)
                            WHERE id_candidato = %s""", (capturado.capturado_en, id_captura, cand["id_candidato"]))
        self.contadores["nuevos" if resultado != "SIN_CAMBIOS" else "sin_cambio"] += 1

    def _no_disponible(self, cand: dict):
        fallos = cand["intentos_fallidos"] + 1
        estado = "NO_DISPONIBLE" if fallos >= config.FALLOS_NO_DISPONIBLE else None
        self._q("""UPDATE candidato SET intentos_fallidos = %s, ultimo_intento_en = NOW(),
                          estado = COALESCE(%s, estado), motivo_estado = COALESCE(%s, motivo_estado)
                    WHERE id_candidato = %s""",
                (fallos, estado, "PERFIL_NO_DISPONIBLE" if estado else None, cand["id_candidato"]))
        if estado:
            self._q("UPDATE egresado SET estado_registro = 'NO_DISPONIBLE' WHERE id_candidato = %s "
                    "AND estado_registro = 'ACTIVO'", (cand["id_candidato"],))
        self.contadores["no_disponibles"] += 1

    def _excluir_candidato(self, id_candidato: int, motivo: str):
        self._q("""UPDATE candidato SET id_publico_linkedin = NULL, estado = 'EXCLUIDO', motivo_estado = %s
                    WHERE id_candidato = %s""", (motivo, id_candidato))
        self.contadores["descartados"] += 1

    # 3. Procesar
    def procesar(self, meses_vigencia=config.MESES_VIGENCIA) -> Counter:
        capturas = self._q(
            """SELECT k.id_captura, k.id_candidato, k.capturada_en, k.contenido, c.consulta_origen
                 FROM captura k JOIN candidato c ON c.id_candidato = k.id_candidato
                WHERE NOT k.procesada AND k.contenido IS NOT NULL
                ORDER BY k.capturada_en, k.id_captura""")
        for k in capturas:
            try:
                with transaction.atomic(using=ALIAS_BD):
                    self._procesar_captura(k)
            except Exception:
                log.exception("Error procesando la captura %s", k["id_captura"])
                self.contadores["errores"] += 1
                # la transacción se revirtió: las cachés pueden apuntar a organizaciones que ya no existen
                self._reglas = None
        with self.conexion.cursor() as cur:
            cur.execute("CALL sp_homologar_cargos()")
            fila = cur.fetchone()
            self.contadores["homologadas_completas"] = int(fila[1] or 0)
            self.contadores["pendientes_revision_manual"] = int(fila[2] or 0)
            while cur.nextset():
                pass
            cur.execute("CALL sp_detectar_incidencias(%s)", (meses_vigencia,))
            while cur.nextset():
                pass
        return self.contadores

    def _procesar_captura(self, k: dict):
        perfil = json.loads(k["contenido"])
        res = evaluar(perfil, self.reglas, self.hoy, k.get("consulta_origen"))
        existente = self._q("SELECT * FROM egresado WHERE id_candidato = %s", (k["id_candidato"],), uno=True)
        if existente and existente["estado_registro"] == "FUSIONADO":
            # sus datos ya se unieron a otro registro, que se actualiza con su propia cuenta
            self._q("UPDATE captura SET procesada = TRUE WHERE id_captura = %s", (k["id_captura"],))
            self.contadores["capturas_de_registros_fusionados"] += 1
            return
        if res.decision in ("DESCARTADO", "EXCLUIDO") and existente is None:
            # no es egresado: solo se guarda la huella
            self._q("""UPDATE candidato SET id_publico_linkedin = NULL, estado = 'DESCARTADO', motivo_estado = %s
                        WHERE id_candidato = %s""", (res.motivo, k["id_candidato"]))
            self._q("UPDATE captura SET contenido = NULL, resultado = 'DESCARTADO', procesada = TRUE "
                    "WHERE id_candidato = %s", (k["id_candidato"],))
            self.contadores["descartados"] += 1
            self.contadores[f"descartados_{res.motivo.lower()}"] += 1
            return
        if res.decision in ("DESCARTADO", "EXCLUIDO"):
            # ya estaba consolidado, queda para revisión manual
            self._incidencia("AMBIGUO", "egresado", existente["id_egresado"], existente["id_egresado"],
                             f"La última captura ya no confirma la pertenencia ({res.motivo})",
                             clave="PERTENENCIA_NO_CONFIRMADA")
            self._q("UPDATE captura SET procesada = TRUE WHERE id_captura = %s", (k["id_captura"],))
            return

        id_egresado = self._consolidar_egresado(k, perfil, res, existente)
        self._consolidar_formacion(id_egresado, k["id_captura"], k["id_candidato"], perfil, res)
        self._consolidar_experiencia(id_egresado, k["id_captura"], k["id_candidato"], perfil)
        self._q("UPDATE captura SET procesada = TRUE WHERE id_captura = %s", (k["id_captura"],))
        self.contadores["aceptados" if res.decision == "ACEPTADO" else "por_revisar"] += 1

    def _consolidar_egresado(self, k, perfil, res, existente) -> int:
        _ = self.reglas
        ubic = geografia.resolver(perfil.get("ubicacion"), self.alias_ubicacion)
        urn = perfil.get("urn")
        if existente is None and urn:
            # mismo URN con otra URL: cambió su id público
            existente = self._q("SELECT * FROM egresado WHERE urn_linkedin = %s", (urn,), uno=True)
            if existente:
                self._q("""UPDATE candidato SET estado = 'NO_DISPONIBLE', motivo_estado = 'ID_PUBLICO_CAMBIADO'
                            WHERE id_candidato = %s""", (existente["id_candidato"],))
        datos = {
            "id_candidato": k["id_candidato"], "id_publico_linkedin": perfil["id_publico"], "urn_linkedin": urn,
            "nombres": (perfil.get("nombres") or perfil["id_publico"])[:100],
            "apellidos": (perfil.get("apellidos") or None),
            "codigo_pais_residencia": ubic.codigo_pais, "codigo_municipio_residencia": ubic.codigo_municipio,
            "puntaje_pertenencia": res.puntaje, "criterios_pertenencia": json.dumps(res.criterios),
            "id_ultima_captura": k["id_captura"],
        }
        if existente is None:
            datos.update(estado_verificacion=res.decision, primera_captura_en=k["capturada_en"],
                         ultima_captura_en=k["capturada_en"])
            columnas = ", ".join(datos)
            return self._q(f"INSERT INTO egresado ({columnas}) VALUES ({', '.join(['%s'] * len(datos))})",
                           tuple(datos.values()))
        if existente["metodo_verificacion"] == "AUTOMATICO":
            datos["estado_verificacion"] = res.decision
        asignaciones = ", ".join(f"{c} = %s" for c in datos)
        self._q(f"""UPDATE egresado SET {asignaciones},
                           ultima_captura_en = GREATEST(ultima_captura_en, %s),
                           estado_registro = IF(estado_registro = 'NO_DISPONIBLE', 'ACTIVO', estado_registro)
                     WHERE id_egresado = %s""",
                (*datos.values(), k["capturada_en"], existente["id_egresado"]))
        return existente["id_egresado"]

    def _consolidar_formacion(self, id_egresado, id_captura, id_candidato, perfil, res):
        vistas = []
        for edu, ev in zip(perfil["educacion"], res.formaciones):
            inicio, fin = fechas.anio(edu.get("inicio")), fechas.anio(edu.get("fin"))
            en_curso = bool(fin and fin > self.hoy.year)
            es_facultad = ev.es_unal and ev.id_programa is not None and ev.exclusion != "OTRA_SEDE"
            h = huella(edu.get("institucion"), edu.get("titulo"), edu.get("campo"), inicio)
            vistas.append(h)
            self._q("""INSERT INTO formacion (id_egresado, id_captura, huella, institucion_original, titulo_original,
                                              campo_original, es_facultad, id_programa, codigo_nivel, anio_inicio,
                                              anio_fin, en_curso, vigente_en_fuente)
                       VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, TRUE)
                       ON DUPLICATE KEY UPDATE id_captura = VALUES(id_captura), es_facultad = VALUES(es_facultad),
                              id_programa = VALUES(id_programa), codigo_nivel = VALUES(codigo_nivel),
                              anio_fin = VALUES(anio_fin), en_curso = VALUES(en_curso), vigente_en_fuente = TRUE""",
                    (id_egresado, id_captura, h, edu["institucion"][:200], (edu.get("titulo") or None),
                     (edu.get("campo") or None), es_facultad, ev.id_programa if es_facultad else None,
                     ev.codigo_nivel, inicio, None if en_curso else fin, en_curso))
        self._marcar_no_vigentes("formacion", id_egresado, id_candidato, vistas)

    def _consolidar_experiencia(self, id_egresado, id_captura, id_candidato, perfil):
        vistas = []
        claves_incidencia = []  # una incidencia por experiencia, no una por egresado
        for x in perfil["experiencia"]:
            inicio = fechas.interpretar(x.get("inicio"))
            fin = fechas.interpretar(x.get("fin"))
            descripcion = f'"{x["cargo"]}" en {x["empresa"]}'
            clave = "EXP:" + huella(x["empresa"], x["cargo"], x.get("inicio"))
            if inicio is None:
                claves_incidencia.append(clave)
                self._incidencia("INCOMPLETO", "egresado", id_egresado, id_egresado,
                                 f"Experiencia sin fecha de inicio reconocible: {descripcion}", clave)
                continue
            if inicio.fecha > self.hoy or (fin and (fin.fecha < inicio.fecha or fin.fecha > self.hoy)):
                claves_incidencia.append(clave)
                self._incidencia("INCONSISTENTE", "egresado", id_egresado, id_egresado,
                                 f"Fechas inválidas en la experiencia {descripcion}", clave)
                continue
            id_org = self._organizacion(x)
            ubic = geografia.resolver(x.get("ubicacion"), self.alias_ubicacion)
            h = huella(id_org, x["cargo"], inicio.fecha.isoformat())
            vistas.append(h)
            self._q("""INSERT INTO experiencia_laboral (id_egresado, id_organizacion, id_captura, huella, cargo_original,
                              tipo_vinculo, modalidad, fecha_inicio, precision_inicio, fecha_fin, precision_fin, es_actual,
                              ubicacion_original, codigo_pais, codigo_municipio, ciudad_extranjera, vigente_en_fuente)
                       VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, TRUE)
                       ON DUPLICATE KEY UPDATE id_captura = VALUES(id_captura), tipo_vinculo = VALUES(tipo_vinculo),
                              modalidad = VALUES(modalidad), fecha_fin = VALUES(fecha_fin),
                              precision_fin = VALUES(precision_fin), es_actual = VALUES(es_actual),
                              ubicacion_original = VALUES(ubicacion_original), codigo_pais = VALUES(codigo_pais),
                              codigo_municipio = VALUES(codigo_municipio),
                              ciudad_extranjera = VALUES(ciudad_extranjera), vigente_en_fuente = TRUE""",
                    (id_egresado, id_org, id_captura, h, x["cargo"][:200],
                     vinculo.tipo_vinculo(x.get("tipo_empleo"), x["cargo"]), vinculo.modalidad(x.get("modalidad")),
                     inicio.fecha, inicio.precision, fin.fecha if fin else None, fin.precision if fin else None,
                     fin is None and fechas.es_actual(x.get("fin")), (x.get("ubicacion") or None),
                     ubic.codigo_pais, ubic.codigo_municipio, ubic.ciudad_extranjera))
        self._marcar_no_vigentes("experiencia_laboral", id_egresado, id_candidato, vistas)
        # las experiencias corregidas en el perfil cierran su incidencia
        filtro = f"AND clave NOT IN ({', '.join(['%s'] * len(claves_incidencia))})" if claves_incidencia else ""
        self._q(f"""UPDATE incidencia_calidad
                       SET estado = 'RESUELTA', resuelta_en = CURRENT_TIMESTAMP, resuelta_por = 'sistema'
                     WHERE entidad = 'egresado' AND id_registro = %s AND estado = 'ABIERTA'
                       AND codigo_tipo IN ('INCOMPLETO', 'INCONSISTENTE') AND clave LIKE 'EXP:%%' {filtro}""",
                (id_egresado, *claves_incidencia))

    def _marcar_no_vigentes(self, tabla, id_egresado, id_candidato, huellas):
        """Lo que ya no aparece en el perfil no se borra: queda fuera del análisis y en el historial.

        Solo se revisan las filas que provienen de capturas de este mismo perfil: las que llegaron
        por la fusión de otra cuenta no dependen de lo que publique esta."""
        filtro = f"AND huella NOT IN ({', '.join(['%s'] * len(huellas))})" if huellas else ""
        self._q(f"""UPDATE {tabla} SET vigente_en_fuente = FALSE
                     WHERE id_egresado = %s AND vigente_en_fuente {filtro}
                       AND id_captura IN (SELECT id_captura FROM captura WHERE id_candidato = %s)""",
                (id_egresado, *huellas, id_candidato))

    def _organizacion(self, x: dict) -> int:
        _ = self.reglas
        nombre = x["empresa"]
        id_linkedin = id_empresa_desde_url(x.get("url_empresa"))
        ciiu = self.industria.get((x.get("industria_empresa") or "").lower())
        tipo = self.tipo_empresa.get((x.get("tipo_empresa") or "").lower())
        alias = organizaciones.clave_alias(nombre)
        org = None
        if id_linkedin:
            org = self._q("SELECT id_organizacion FROM organizacion WHERE id_linkedin_empresa = %s",
                          (id_linkedin,), uno=True)
        if org is None:
            org = self._q("SELECT id_organizacion FROM organizacion_alias WHERE alias = %s", (alias,), uno=True)
        if org is None and organizaciones.nombre_base(nombre) in self.org_por_base:
            org = {"id_organizacion": self.org_por_base[organizaciones.nombre_base(nombre)]}
        if org is None:
            id_org = self._q("""INSERT INTO organizacion (nombre_normalizado, id_linkedin_empresa, industria_linkedin,
                                                          codigo_seccion_ciiu, codigo_tipo)
                                VALUES (%s, %s, %s, %s, %s)""",
                             (organizaciones.nombre_canonico(nombre)[:200], id_linkedin,
                              x.get("industria_empresa"), ciiu, tipo))
            self.org_por_base[organizaciones.nombre_base(nombre)] = id_org
        else:
            id_org = org["id_organizacion"]
            # solo completa lo que falte
            self._q("""UPDATE organizacion SET
                          id_linkedin_empresa = COALESCE(id_linkedin_empresa, %s),
                          industria_linkedin  = COALESCE(industria_linkedin, %s),
                          codigo_seccion_ciiu = COALESCE(codigo_seccion_ciiu, %s),
                          codigo_tipo         = COALESCE(codigo_tipo, %s)
                        WHERE id_organizacion = %s""", (id_linkedin, x.get("industria_empresa"), ciiu, tipo, id_org))
        self._q("INSERT IGNORE INTO organizacion_alias (alias, id_organizacion) VALUES (%s, %s)", (alias[:200], id_org))
        return id_org
