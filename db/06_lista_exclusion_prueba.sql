-- Titular ficticio en la lista de exclusión: aparece en la búsqueda pero nunca se captura.
USE egresados_fi;

INSERT INTO lista_exclusion (hash_id_publico, motivo, radicado)
VALUES (SHA2('pedro-alvarez-fict', 256), 'OPOSICION', 'RAD-2026-0001');
