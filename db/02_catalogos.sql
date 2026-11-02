-- Catálogos (DANE, ISO 3166-1, SNIES) y diccionarios de homologación.
USE egresados_fi;

INSERT INTO cat_nivel_formacion (codigo, descripcion, orden) VALUES
 ('TECNOLOGICO',     'Técnico profesional / Tecnológico', 1),
 ('PREGRADO',        'Universitario (pregrado)',          2),
 ('ESPECIALIZACION', 'Especialización',                   3),
 ('MAESTRIA',        'Maestría',                          4),
 ('DOCTORADO',       'Doctorado',                         5),
 ('POSDOCTORADO',    'Estancia posdoctoral',              6);

-- Programas de la Facultad (falta completar el código SNIES)
INSERT INTO cat_programa (nombre, codigo_nivel) VALUES
 ('Ingeniería Agrícola',                     'PREGRADO'),
 ('Ingeniería Civil',                        'PREGRADO'),
 ('Ingeniería de Sistemas y Computación',    'PREGRADO'),
 ('Ingeniería Eléctrica',                    'PREGRADO'),
 ('Ingeniería Electrónica',                  'PREGRADO'),
 ('Ingeniería Industrial',                   'PREGRADO'),
 ('Ingeniería Mecánica',                     'PREGRADO'),
 ('Ingeniería Mecatrónica',                  'PREGRADO'),
 ('Ingeniería Química',                      'PREGRADO'),
 ('Maestría en Ingeniería - Ingeniería de Sistemas y Computación', 'MAESTRIA'),
 ('Maestría en Ingeniería - Ingeniería Industrial',                'MAESTRIA'),
 ('Doctorado en Ingeniería - Sistemas y Computación',              'DOCTORADO');

INSERT INTO cat_sector_ciiu (codigo_seccion, descripcion) VALUES
 ('A','Agricultura, ganadería, caza, silvicultura y pesca'),
 ('B','Explotación de minas y canteras'),
 ('C','Industrias manufactureras'),
 ('D','Suministro de electricidad, gas, vapor y aire acondicionado'),
 ('E','Distribución de agua; evacuación y tratamiento de aguas residuales, gestión de desechos y saneamiento ambiental'),
 ('F','Construcción'),
 ('G','Comercio al por mayor y al por menor; reparación de vehículos automotores y motocicletas'),
 ('H','Transporte y almacenamiento'),
 ('I','Alojamiento y servicios de comida'),
 ('J','Información y comunicaciones'),
 ('K','Actividades financieras y de seguros'),
 ('L','Actividades inmobiliarias'),
 ('M','Actividades profesionales, científicas y técnicas'),
 ('N','Actividades de servicios administrativos y de apoyo'),
 ('O','Administración pública y defensa; planes de seguridad social de afiliación obligatoria'),
 ('P','Educación'),
 ('Q','Actividades de atención de la salud humana y de asistencia social'),
 ('R','Actividades artísticas, de entretenimiento y recreación'),
 ('S','Otras actividades de servicios'),
 ('T','Actividades de los hogares individuales en calidad de empleadores'),
 ('U','Actividades de organizaciones y entidades extraterritoriales');

-- CIUO-08 A.C.: grupos más comunes en ingeniería
INSERT INTO cat_ocupacion_ciuo (codigo, descripcion, nivel, codigo_padre) VALUES
 ('0','Ocupaciones militares',1,NULL),
 ('1','Directores y gerentes',1,NULL),
 ('2','Profesionales científicos e intelectuales',1,NULL),
 ('3','Técnicos y profesionales del nivel medio',1,NULL),
 ('4','Personal de apoyo administrativo',1,NULL),
 ('5','Trabajadores de los servicios y vendedores de comercios y mercados',1,NULL),
 ('6','Agricultores y trabajadores calificados agropecuarios, forestales y pesqueros',1,NULL),
 ('7','Oficiales, operarios, artesanos y oficios relacionados',1,NULL),
 ('8','Operadores de instalaciones y máquinas y ensambladores',1,NULL),
 ('9','Ocupaciones elementales',1,NULL);

INSERT INTO cat_ocupacion_ciuo (codigo, descripcion, nivel, codigo_padre) VALUES
 ('11','Miembros del poder ejecutivo y legislativo, directores de la administración pública y gerentes generales',2,'1'),
 ('12','Directores administrativos y comerciales',2,'1'),
 ('13','Directores y gerentes de producción y operaciones',2,'1'),
 ('21','Profesionales de las ciencias y de la ingeniería',2,'2'),
 ('23','Profesionales de la enseñanza',2,'2'),
 ('24','Especialistas en organización de la administración pública y de empresas',2,'2'),
 ('25','Profesionales de tecnología de la información y las comunicaciones',2,'2'),
 ('31','Profesionales de las ciencias y la ingeniería de nivel medio',2,'3'),
 ('35','Técnicos de la tecnología de la información y las comunicaciones',2,'3');

INSERT INTO cat_ocupacion_ciuo (codigo, descripcion, nivel, codigo_padre) VALUES
 ('1120','Directores generales y gerentes generales',4,'11'),
 ('1321','Directores de industrias manufactureras',4,'13'),
 ('1323','Directores de empresas de construcción',4,'13'),
 ('1330','Directores de servicios de tecnología de la información y las comunicaciones',4,'13'),
 ('2141','Ingenieros industriales y de producción',4,'21'),
 ('2142','Ingenieros civiles',4,'21'),
 ('2144','Ingenieros mecánicos',4,'21'),
 ('2145','Ingenieros químicos',4,'21'),
 ('2149','Ingenieros no clasificados en otros grupos primarios',4,'21'),
 ('2151','Ingenieros electricistas',4,'21'),
 ('2152','Ingenieros electrónicos',4,'21'),
 ('2310','Profesores de universidades y de la enseñanza superior',4,'23'),
 ('2421','Analistas de gestión y organización',4,'24'),
 ('2511','Analistas de sistemas',4,'25'),
 ('2512','Desarrolladores de software',4,'25'),
 ('2521','Diseñadores y administradores de bases de datos',4,'25'),
 ('2523','Profesionales en redes de computadores',4,'25');

INSERT INTO cat_nivel_cargo (codigo, descripcion, orden) VALUES
 ('PRACTICANTE',        'Practicante / pasante',                                  1),
 ('PROFESIONAL',        'Profesional / analista / ingeniero',                      2),
 ('PROFESIONAL_SENIOR', 'Profesional sénior / especialista / líder técnico',       3),
 ('COORDINACION',       'Coordinación / jefatura / líder de equipo',               4),
 ('GERENCIA',           'Gerencia / dirección de área',                            5),
 ('ALTA_DIRECCION',     'Alta dirección / fundador / presidencia',                 6);

INSERT INTO cat_area_desempeno (codigo, descripcion) VALUES
 ('DESARROLLO_SOFTWARE',   'Desarrollo de software'),
 ('DATOS_ANALITICA',       'Datos, analítica e inteligencia artificial'),
 ('INFRAESTRUCTURA_TI',    'Infraestructura, redes y operaciones de TI'),
 ('PROYECTOS',             'Gestión de proyectos'),
 ('PRODUCCION_OPERACIONES','Producción y operaciones'),
 ('CALIDAD',               'Calidad, normalización y mejora continua'),
 ('LOGISTICA',             'Logística y cadena de suministro'),
 ('MANTENIMIENTO',         'Mantenimiento'),
 ('DISENO_INGENIERIA',     'Diseño de ingeniería'),
 ('CONSTRUCCION_OBRA',     'Construcción e interventoría'),
 ('ENERGIA',               'Energía y sistemas de potencia'),
 ('AMBIENTAL',             'Gestión ambiental y sostenibilidad'),
 ('CONSULTORIA',           'Consultoría'),
 ('COMERCIAL_TECNICO',     'Comercial y ventas técnicas'),
 ('FINANZAS_RIESGO',       'Finanzas y riesgo'),
 ('INVESTIGACION_DOCENCIA','Investigación y docencia'),
 ('DIRECCION_GENERAL',     'Dirección general y emprendimiento'),
 ('OTRA',                  'Otra área');

INSERT INTO cat_tipo_organizacion (codigo, descripcion) VALUES
 ('PRIVADA',      'Empresa privada'),
 ('PUBLICA',      'Entidad pública'),
 ('MIXTA',        'Sociedad de economía mixta'),
 ('ACADEMIA',     'Institución de educación o centro de investigación'),
 ('ONG',          'Organización sin ánimo de lucro'),
 ('MULTILATERAL', 'Organismo internacional / multilateral'),
 ('PROPIA',       'Emprendimiento o trabajo independiente');

INSERT INTO cat_pais (codigo_iso2, nombre) VALUES
 ('AR','Argentina'),('BR','Brasil'),('CA','Canadá'),('CL','Chile'),
 ('CO','Colombia'),('DE','Alemania'),('ES','España'),('FR','Francia'),
 ('GB','Reino Unido'),('MX','México'),('NL','Países Bajos'),('PE','Perú'),
 ('US','Estados Unidos');

INSERT INTO cat_departamento (codigo_dane, nombre) VALUES
 ('05','Antioquia'),('08','Atlántico'),('11','Bogotá, D.C.'),('13','Bolívar'),
 ('25','Cundinamarca'),('50','Meta'),('68','Santander'),('76','Valle del Cauca');

INSERT INTO cat_municipio (codigo_dane, nombre, codigo_departamento) VALUES
 ('05001','Medellín','05'),('08001','Barranquilla','08'),('11001','Bogotá, D.C.','11'),
 ('13001','Cartagena de Indias','13'),('25175','Chía','25'),('50001','Villavicencio','50'),
 ('68001','Bucaramanga','68'),('76001','Cali','76');

INSERT INTO cat_canal (codigo, descripcion, nivel_confiabilidad) VALUES
 ('BUSCADOR_WEB',        'API de motor de búsqueda sobre perfiles públicos (solo descubrimiento)', 1),
 ('SCRAPING_PUBLICO',    'Web scraping propio de la versión pública del perfil (canal A)',        2),
 ('EXPORTACION_TITULAR', 'Archivo de exportación de LinkedIn entregado por el propio egresado',   3),
 ('ARCHIVO_PRUEBA',      'Archivo local con perfiles ficticios (pruebas del proceso)',            2);

INSERT INTO cat_tipo_incidencia (codigo, descripcion, severidad) VALUES
 ('INCOMPLETO',        'Faltan variables requeridas para el análisis',                       'MEDIA'),
 ('AMBIGUO',           'La pertenencia o la clasificación admite más de una lectura',        'MEDIA'),
 ('DESACTUALIZADO',    'La última captura supera el periodo de actualización definido',      'BAJA'),
 ('NO_VERIFICABLE',    'El perfil no permite confirmar el dato o dejó de estar disponible',   'ALTA'),
 ('DUPLICADO_POSIBLE', 'Dos registros podrían corresponder a la misma entidad',               'ALTA'),
 ('INCONSISTENTE',     'El dato contradice otro dato o una regla de negocio',                 'ALTA');

-- Homologación de cargos: por cada dimensión gana la regla de menor prioridad
INSERT INTO homologacion_cargo (patron, codigo_ciuo, codigo_nivel_cargo, codigo_area, prioridad) VALUES
 ('(?i)\\b(practicante|pasante|intern(ship)?|aprendiz)\\b',           NULL,  'PRACTICANTE',        NULL, 10),
 ('(?i)\\b(ceo|cto|fundador|cofundador|co-?founder|founder|presidente)\\b', '1120','ALTA_DIRECCION','DIRECCION_GENERAL', 10),
 ('(?i)\\bdirector[a]? de (obra|proyectos)\\b',                       '1323','GERENCIA',     'PROYECTOS', 15),
 ('(?i)\\b(gerente|director|directora|manager|head of)\\b',            NULL,  'GERENCIA',           NULL, 20),
 ('(?i)\\b(coordinador|coordinadora|jefe|jefa|team lead|l[ií]der de equipo)\\b', NULL, 'COORDINACION', NULL, 30),
 ('(?i)\\b(s[eé]nior|sr\\.?|especialista|principal|l[ií]der t[eé]cnico)\\b', NULL, 'PROFESIONAL_SENIOR', NULL, 40),
 ('(?i)\\b(ingenier[oa]|engineer|analista|analyst|desarrollador[a]?|developer|residente|profesional)\\b', NULL, 'PROFESIONAL', NULL, 90),
 ('(?i)\\b(datos|data|anal[ií]tica|machine learning|bi)\\b',          '2521', NULL, 'DATOS_ANALITICA', 20),
 ('(?i)\\b(desarrollador[a]?|developer|backend|frontend|full ?stack|software)\\b', '2512', NULL, 'DESARROLLO_SOFTWARE', 30),
 ('(?i)\\b(obra|estructural|interventor[ií]a|v[ií]as)\\b',             '2142', NULL, 'CONSTRUCCION_OBRA', 30),
 ('(?i)\\b(proyectos|project)\\b',                                      '2142', NULL, 'PROYECTOS', 60),
 ('(?i)\\b(procesos|process)\\b',                                       '2145', NULL, 'PRODUCCION_OPERACIONES', 40),
 ('(?i)\\b(gerente|director[a]?|jefe|jefa|manager|head) (de |of )?(operaciones|operations|producci[oó]n|planta)\\b', '1321', NULL, 'PRODUCCION_OPERACIONES', 15),
 ('(?i)\\b(operaciones|operations|producci[oó]n|planta)\\b',          NULL,  NULL, 'PRODUCCION_OPERACIONES', 50),
 ('(?i)\\b(log[ií]stic[ao]s?|supply chain|cadena de suministro|scm)\\b', '2141', NULL, 'LOGISTICA', 40),
 ('(?i)\\b(el[eé]ctric[oa]|potencia|subestaciones)\\b',               '2151', NULL, 'ENERGIA', 40),
 ('(?i)\\b(rob[oó]tica|mecatr[oó]nic[oa]|automatizaci[oó]n)\\b',     '2149', NULL, 'DISENO_INGENIERIA', 40),
 ('(?i)\\b(docente|profesor[a]?|investigador[a]?|professor|researcher)\\b', '2310', NULL, 'INVESTIGACION_DOCENCIA', 20);

-- Diccionarios del proceso

-- Institución. OTRA_SEDE excluye el perfil.
INSERT INTO regla_institucion (patron, resultado, prioridad) VALUES
 ('(?i)medell[ií]n|facultad de minas|manizales|palmira|sede caribe|orinoqu[ií]a|amazon[ií]a|tumaco|sede de la paz', 'OTRA_SEDE', 5),
 ('(?i)bogot[aá]',                                                         'SEDE_BOGOTA', 8),
 ('(?i)linkedin\\.com/school/universidad-nacional-de-colombia',            'UNAL_PAGINA', 10),
 ('(?i)universidad nacional de colombia|national university of colombia|\\bunal\\b', 'UNAL_NOMBRE', 20),
 ('(?i)^\\s*(universidad nacional|national university)\\s*$',              'UNAL_AMBIGUO', 30);

-- Nivel de formación a partir del título (gana la menor prioridad)
INSERT INTO regla_nivel_formacion (patron, codigo_nivel, prioridad) VALUES
 ('(?i)doctor|ph\\.? ?d',                                                  'DOCTORADO',       10),
 ('(?i)maestr[ií]a|mag[ií]ster|master|\\bm\\.? ?sc\\b|\\bmba\\b',         'MAESTRIA',        20),
 ('(?i)especiali',                                                         'ESPECIALIZACION', 30),
 ('(?i)tecn[oó]log|t[eé]cnico profesional',                               'TECNOLOGICO',     40),
 ('(?i)ingenier|engineer|pregrado|bachelor|licenciad|\\bb\\.? ?sc?\\b|undergraduate|profesional', 'PREGRADO', 50);

-- Programa a partir del título y el campo de estudio
INSERT INTO regla_programa (patron, id_programa, prioridad) VALUES
 ('(?i)agr[ií]cola|agricultural',                   1, 10),
 ('(?i)\\bcivil\\b',                                2, 10),
 ('(?i)sistemas|computaci[oó]n|computer|systems',   3, 20),
 ('(?i)el[eé]ctric[ao]|electrical',                 4, 10),
 ('(?i)electr[oó]nic|electronic',                   5, 10),
 ('(?i)industrial',                                 6, 10),
 ('(?i)mec[aá]nic[ao]|mechanical',                  7, 10),
 ('(?i)mecatr[oó]nic|mechatronic',                  8, 10),
 ('(?i)qu[ií]mic[ao]|chemical',                     9, 10),
 ('(?i)sistemas|computaci[oó]n|computer|systems',  10, 20),
 ('(?i)industrial',                                11, 10),
 ('(?i)sistemas|computaci[oó]n|computer|systems',  12, 20);

-- Industria de la página de empresa en LinkedIn -> sección CIIU Rev. 4 A.C.
INSERT INTO equivalencia_industria (industria_linkedin, codigo_seccion_ciiu) VALUES
 ('Software Development','J'), ('IT Services and IT Consulting','J'),
 ('Technology, Information and Internet','J'), ('Telecommunications','J'),
 ('Data Infrastructure and Analytics','J'), ('Desarrollo de software','J'),
 ('Servicios y consultoría de TI','J'),
 ('Financial Services','K'), ('Banking','K'), ('Insurance','K'),
 ('Civil Engineering','F'), ('Construction','F'),
 ('Government Administration','O'), ('Administración gubernamental','O'),
 ('Chemical Manufacturing','C'), ('Manufacturing','C'), ('Food and Beverage Manufacturing','C'),
 ('Automation Machinery Manufacturing','C'), ('Robot Manufacturing','C'),
 ('Oil and Gas','B'), ('Mining','B'),
 ('Utilities','D'), ('Electric Power Generation','D'), ('Renewable Energy Power Generation','D'),
 ('Environmental Services','E'),
 ('Retail','G'), ('Transportation, Logistics, Supply Chain and Storage','H'),
 ('Higher Education','P'), ('Research Services','M'), ('Engineering Services','M'),
 ('Business Consulting and Services','M'), ('Hospitals and Health Care','Q');

-- Tipo de empresa de LinkedIn -> naturaleza ("Public Company" es privada)
INSERT INTO equivalencia_tipo_empresa (tipo_linkedin, codigo_tipo) VALUES
 ('Public Company','PRIVADA'), ('Privately Held','PRIVADA'), ('Partnership','PRIVADA'),
 ('Government Agency','PUBLICA'), ('Nonprofit','ONG'), ('Educational','ACADEMIA'),
 ('Self-Employed','PROPIA'), ('Self-Owned','PROPIA');

-- Ubicaciones: texto normalizado -> país y municipio
INSERT INTO alias_ubicacion (texto_normalizado, codigo_pais, codigo_municipio) VALUES
 ('colombia','CO',NULL),
 ('bogota','CO','11001'), ('bogota d c','CO','11001'), ('bogota dc','CO','11001'),
 ('area metropolitana de bogota','CO','11001'), ('medellin','CO','05001'),
 ('barranquilla','CO','08001'), ('cartagena','CO','13001'), ('cartagena de indias','CO','13001'),
 ('chia','CO','25175'), ('villavicencio','CO','50001'), ('bucaramanga','CO','68001'),
 ('cali','CO','76001'), ('santiago de cali','CO','76001'),
 ('alemania','DE',NULL), ('germany','DE',NULL), ('deutschland','DE',NULL),
 ('estados unidos','US',NULL), ('united states','US',NULL), ('usa','US',NULL),
 ('espana','ES',NULL), ('spain','ES',NULL), ('mexico','MX',NULL), ('canada','CA',NULL),
 ('chile','CL',NULL), ('argentina','AR',NULL), ('brasil','BR',NULL), ('brazil','BR',NULL),
 ('peru','PE',NULL), ('francia','FR',NULL), ('france','FR',NULL),
 ('reino unido','GB',NULL), ('united kingdom','GB',NULL),
 ('paises bajos','NL',NULL), ('netherlands','NL',NULL);
