BEGIN;

UPDATE catalog_version SET is_current = false;

INSERT INTO catalog_version (version_id, created_at, changelog, is_current)
VALUES ('v1_2026_02_18', now(), 'Initial catalog seed from Catalogos (1).pdf', true)
ON CONFLICT (version_id) DO UPDATE SET changelog = EXCLUDED.changelog, is_current = true;


INSERT INTO cat_projects (project_id, name, version_id, is_active, updated_at)
VALUES
('TMQ', 'Tren México Querétaro', 'v1_2026_02_18', true, now()),
('TAP', 'Tren AIFA Pachuca', 'v1_2026_02_18', true, now())
ON CONFLICT (project_id) DO UPDATE SET
name = EXCLUDED.name, version_id = EXCLUDED.version_id, is_active = EXCLUDED.is_active, updated_at = EXCLUDED.updated_at;

INSERT INTO cat_activities (activity_id, name, description, version_id, is_active, updated_at)
VALUES
('CAM', 'Caminamiento', 'Recorrido físico en campo para verificar DDV, accesos y afectaciones.', 'v1_2026_02_18', true, now()),
('REU', 'Reunión', 'Coordinación técnica, social o institucional.', 'v1_2026_02_18', true, now()),
('ASP', 'Asamblea Protocolizada', 'Acto formal agrario para aprobar acuerdos y Convenio de Ocupación Previa COP.', 'v1_2026_02_18', true, now()),
('CIN', 'Consulta Indígena', 'Proceso de participación conforme al Convenio 169.', 'v1_2026_02_18', true, now()),
('SOC', 'Socialización', 'Presentación y sensibilización comunitaria.', 'v1_2026_02_18', true, now()),
('AIN', 'Acompañamiento Institucional', 'Supervisión y documentación interinstitucional.', 'v1_2026_02_18', true, now())
ON CONFLICT (activity_id) DO UPDATE SET
name = EXCLUDED.name, description = EXCLUDED.description, version_id = EXCLUDED.version_id, is_active = EXCLUDED.is_active, updated_at = EXCLUDED.updated_at;

INSERT INTO cat_subcategories (subcategory_id, activity_id, name, description, version_id, is_active, updated_at)
VALUES
('CAM_DDV', 'CAM', 'Verificación de DDV', 'Revisión de límites del DDV en campo.', 'v1_2026_02_18', true, now()),
('CAM_MAR', 'CAM', 'Marcaje de afectaciones', 'Señalamiento físico de áreas afectadas.', 'v1_2026_02_18', true, now()),
('CAM_ACC', 'CAM', 'Revisión de accesos / BDT', 'Confirmación de caminos y bienes distintos a la tierra.', 'v1_2026_02_18', true, now()),
('CAM_SEG', 'CAM', 'Seguimiento técnico', 'Monitoreo y control de avances.', 'v1_2026_02_18', true, now()),
('REU_TEC', 'REU', 'Técnica / Interinstitucional', 'Coordinación entre dependencias.', 'v1_2026_02_18', true, now()),
('REU_EJI', 'REU', 'Ejidal / Comisariado', 'Diálogo con autoridades ejidales.', 'v1_2026_02_18', true, now()),
('REU_MUN', 'REU', 'Municipal / Estatal / Protección Civil', 'Vinculación con gobiernos locales.', 'v1_2026_02_18', true, now()),
('REU_SEG', 'REU', 'Seguimiento / Evaluación', 'Revisión de cumplimiento de acuerdos.', 'v1_2026_02_18', true, now()),
('REU_INF', 'REU', 'Informativa', 'Presentación de avances.', 'v1_2026_02_18', true, now()),
('REU_MES', 'REU', 'Mesa Técnica', 'Análisis puntual de temas técnicos/sociales.', 'v1_2026_02_18', true, now()),
('ASP_1AP', 'ASP', '1ª Asamblea Protocolizada (1AP)', 'Convocatoria inicial, presentación del proyecto.', 'v1_2026_02_18', true, now()),
('ASP_1AP_PER', 'ASP', '1ª Asamblea Protocolizada Permanente', 'Continúa otro día con quórum legal.', 'v1_2026_02_18', true, now()),
('ASP_2AP', 'ASP', '2ª Asamblea Protocolizada (2AP)', 'Con las personas que asistan se da el quórum legal.', 'v1_2026_02_18', true, now()),
('ASP_2AP_PER', 'ASP', '2ª Asamblea Protocolizada Permanente', 'Continúa otro día.', 'v1_2026_02_18', true, now()),
('ASP_INF', 'ASP', 'Asamblea Informativa', 'Sesión explicativa previa.', 'v1_2026_02_18', true, now()),
('CIN_INF', 'CIN', 'Etapa Informativa', 'Difusión del proyecto.', 'v1_2026_02_18', true, now()),
('CIN_CON', 'CIN', 'Etapa de Construcción de Acuerdos', 'Definición de compromisos.', 'v1_2026_02_18', true, now()),
('CIN_ACT', 'CIN', 'Etapa de Actos y Acuerdos', 'Firma de actas finales.', 'v1_2026_02_18', true, now()),
('SOC_PRE', 'SOC', 'Presentación Comunitaria', 'Exposición general.', 'v1_2026_02_18', true, now()),
('SOC_DIF', 'SOC', 'Difusión de Información', 'Entrega de materiales.', 'v1_2026_02_18', true, now()),
('SOC_ATN', 'SOC', 'Atención a Inquietudes', 'Gestión de dudas o quejas.', 'v1_2026_02_18', true, now()),
('AIN_TEC', 'AIN', 'Técnico', 'Supervisión de obras/trazos.', 'v1_2026_02_18', true, now()),
('AIN_SOC', 'AIN', 'Social', 'Seguimiento a compromisos.', 'v1_2026_02_18', true, now()),
('AIN_DOC', 'AIN', 'Documental', 'Registro y evidencias oficiales.', 'v1_2026_02_18', true, now())
ON CONFLICT (subcategory_id) DO UPDATE SET
activity_id = EXCLUDED.activity_id, name = EXCLUDED.name, description = EXCLUDED.description, version_id = EXCLUDED.version_id, is_active = EXCLUDED.is_active, updated_at = EXCLUDED.updated_at;

INSERT INTO cat_purposes (purpose_id, activity_id, subcategory_id, name, version_id, is_active, updated_at)
VALUES
('PRS_GEN_REU', 'REU', 'REU_INF', 'Presentación general del proyecto', 'v1_2026_02_18', true, now()),
('DOC_CONV_REU', 'REU', 'REU_INF', 'Entrega de documentación / Convocatorias', 'v1_2026_02_18', true, now()),
('SOC_CON_REU', 'REU', 'REU_SEG', 'Atención a inconformidades o conflictos', 'v1_2026_02_18', true, now()),
('CONC_FER_REU', 'REU', 'REU_TEC', 'Coordinación con concesionarios ferroviarios', 'v1_2026_02_18', true, now()),
('COOR_INST_REU', 'REU', 'REU_TEC', 'Coordinación institucional', 'v1_2026_02_18', true, now()),
('PLAN_ACT_REU', 'REU', 'REU_SEG', 'Planeación de nuevas actividades', 'v1_2026_02_18', true, now()),
('SEG_DOC_REU', 'REU', 'REU_SEG', 'Seguimiento administrativo / documental', 'v1_2026_02_18', true, now()),
('PRS_GEN_ASP', 'ASP', 'ASP_1AP', 'Presentación general del proyecto', 'v1_2026_02_18', true, now()),
('DOC_CONV_ASP', 'ASP', 'ASP_1AP', 'Entrega de documentación / Convocatorias', 'v1_2026_02_18', true, now()),
('COP_FIR_ASP', 'ASP', 'ASP_2AP', 'Obtención de anuencia o firma de COP', 'v1_2026_02_18', true, now()),
('AVAL_VAL_ASP', 'ASP', NULL, 'Validación o ajuste de avalúos', 'v1_2026_02_18', true, now()),
('AFEC_VER_CAM', 'CAM', 'CAM_DDV', 'Verificación de afectaciones', 'v1_2026_02_18', true, now()),
('DDV_MAR_CAM', 'CAM', 'CAM_MAR', 'Marcaje o actualización de DDV / trazo', 'v1_2026_02_18', true, now()),
('GAL_REV_CAM', 'CAM', NULL, 'Revisión técnica de gálibos / cruces', 'v1_2026_02_18', true, now()),
('ACC_ALT_CAM', 'CAM', 'CAM_ACC', 'Análisis de accesos y pasos alternos', 'v1_2026_02_18', true, now()),
('AMB_PAT_CAM', 'CAM', NULL, 'Atención ambiental o patrimonial', 'v1_2026_02_18', true, now()),
('IND_CONS_CIN', 'CIN', NULL, 'Atención a comunidades indígenas', 'v1_2026_02_18', true, now()),
('PRS_GEN_CIN', 'CIN', 'CIN_INF', 'Presentación general del proyecto', 'v1_2026_02_18', true, now()),
('DOC_CONV_CIN', 'CIN', 'CIN_INF', 'Entrega de documentación / Convocatorias', 'v1_2026_02_18', true, now()),
('SOC_CON_CIN', 'CIN', 'CIN_CON', 'Atención a inconformidades o conflictos', 'v1_2026_02_18', true, now()),
('PRS_GEN_SOC', 'SOC', 'SOC_PRE', 'Presentación general del proyecto', 'v1_2026_02_18', true, now()),
('AMB_PAT_SOC', 'SOC', NULL, 'Atención ambiental o patrimonial', 'v1_2026_02_18', true, now()),
('SOC_CON_SOC', 'SOC', 'SOC_ATN', 'Atención a inconformidades o conflictos', 'v1_2026_02_18', true, now()),
('SEG_DOC_AIN', 'AIN', 'AIN_DOC', 'Seguimiento administrativo / documental', 'v1_2026_02_18', true, now()),
('COOR_INST_AIN', 'AIN', NULL, 'Coordinación institucional', 'v1_2026_02_18', true, now()),
('AMB_PAT_AIN', 'AIN', NULL, 'Atención ambiental o patrimonial', 'v1_2026_02_18', true, now()),
('PLAN_ACT_AIN', 'AIN', NULL, 'Planeación de nuevas actividades', 'v1_2026_02_18', true, now())
ON CONFLICT (purpose_id) DO UPDATE SET
activity_id = EXCLUDED.activity_id, subcategory_id = EXCLUDED.subcategory_id, name = EXCLUDED.name, version_id = EXCLUDED.version_id, is_active = EXCLUDED.is_active, updated_at = EXCLUDED.updated_at;

INSERT INTO cat_topics (topic_id, type, name, description, version_id, is_active, updated_at)
VALUES
('galibos_ferroviarios', 'Técnico', 'Gálibos ferroviarios', 'Revisión de alturas/ancho de estructuras', 'v1_2026_02_18', true, now()),
('accesos_y_pasos_vehiculares', 'Técnico', 'Accesos y pasos vehiculares', 'Conectividad vial', 'v1_2026_02_18', true, now()),
('caminos_de_servicio', 'Técnico', 'Caminos de servicio', 'Acceso y mantenimiento', 'v1_2026_02_18', true, now()),
('cruces_peatonales_puentes', 'Técnico', 'Cruces peatonales / puentes', 'Ubicación y diseño', 'v1_2026_02_18', true, now()),
('infraestructura_electrica_cfe', 'Técnico', 'Infraestructura eléctrica / CFE', 'Afectación de líneas', 'v1_2026_02_18', true, now()),
('hidraulica_conagua', 'Técnico', 'Hidráulica / CONAGUA', 'Drenaje y cauces', 'v1_2026_02_18', true, now()),
('infraestructura_ferroviaria_existente', 'Técnico', 'Infraestructura ferroviaria existente', 'Concesionarios y operación', 'v1_2026_02_18', true, now()),
('tenencia_de_la_tierra', 'Social/Agrario', 'Tenencia de la tierra', 'Propiedad/posesión', 'v1_2026_02_18', true, now()),
('avaluos_y_pagos', 'Social/Agrario', 'Avalúos y pagos', 'Valor m² y compensación', 'v1_2026_02_18', true, now()),
('asambleas_ejidales', 'Social/Agrario', 'Asambleas ejidales', 'COP/quórum/procedimiento', 'v1_2026_02_18', true, now()),
('inconformidades_comunitarias', 'Social/Agrario', 'Inconformidades comunitarias', 'Quejas y bloqueos', 'v1_2026_02_18', true, now()),
('arbolado_vegetacion', 'Ambiental', 'Arbolado / vegetación', 'Tala/reforestación', 'v1_2026_02_18', true, now()),
('fauna_local', 'Ambiental', 'Fauna local', 'Protección de animales', 'v1_2026_02_18', true, now()),
('cauces_y_cuerpos_de_agua', 'Ambiental', 'Cauces y cuerpos de agua', 'CONAGUA', 'v1_2026_02_18', true, now()),
('sitios_arqueologicos_inah', 'Patrimonial', 'Sitios arqueológicos / INAH', 'Protección patrimonial', 'v1_2026_02_18', true, now()),
('residuos_y_escombros', 'Ambiental', 'Residuos y escombros', 'Manejo de materiales', 'v1_2026_02_18', true, now()),
('coordinacion_interinstitucional', 'Administrativo', 'Coordinación interinstitucional', 'Alineación dependencias', 'v1_2026_02_18', true, now()),
('documentacion_pendiente', 'Administrativo', 'Documentación pendiente', 'Oficios y actas', 'v1_2026_02_18', true, now()),
('protocolos_de_seguridad', 'Administrativo', 'Protocolos de seguridad', 'Riesgos y restricciones', 'v1_2026_02_18', true, now()),
('consulta_previa', 'Indígena', 'Consulta previa', 'Derecho de participación', 'v1_2026_02_18', true, now()),
('lengua_y_traductores', 'Indígena', 'Lengua y traductores', 'Comprensión cultural', 'v1_2026_02_18', true, now()),
('actos_y_acuerdos_finales', 'Indígena', 'Actos y acuerdos finales', 'Firma final', 'v1_2026_02_18', true, now()),
('calcetines_oe', 'Técnico', 'Calcetines/OE', 'Estabilización taludes', 'v1_2026_02_18', true, now()),
('franja_de_proteccion', 'Técnico', 'Franja de protección', 'Límites de seguridad', 'v1_2026_02_18', true, now()),
('interferencias_inmobiliarias', 'Social/Agrario', 'Interferencias inmobiliarias', 'Viviendas afectadas', 'v1_2026_02_18', true, now()),
('gestion_catastral', 'Administrativo', 'Gestión catastral', 'Delimitación predial', 'v1_2026_02_18', true, now()),
('permisos_de_acceso', 'Social/Agrario', 'Permisos de acceso', 'Autorización para ingreso', 'v1_2026_02_18', true, now()),
('conflictos_ambientales', 'Ambiental', 'Conflictos ambientales', 'Llantas, basureros', 'v1_2026_02_18', true, now()),
('seguimiento_a_oficios', 'Administrativo', 'Seguimiento a oficios', 'Cumplimiento de acuerdos', 'v1_2026_02_18', true, now()),
('participacion_comunitaria', 'Social/Agrario', 'Participación comunitaria', 'Comités y vocerías', 'v1_2026_02_18', true, now()),
('viaductos_y_tuneles', 'Técnico', 'Viaductos y túneles', 'Ajustes estructurales', 'v1_2026_02_18', true, now()),
('ajustes_de_trazo', 'Administrativo', 'Ajustes de trazo', 'Cambios', 'v1_2026_02_18', true, now()),
('marcaje_en_campo', 'Técnico', 'Marcaje en campo', 'Señalización de BDT', 'v1_2026_02_18', true, now()),
('reubicaciones', 'Social/Agrario', 'Reubicaciones', 'Escuelas, cercos, bodegas', 'v1_2026_02_18', true, now()),
('actores_locales', NULL, 'Actores locales', NULL, 'v1_2026_02_18', true, now()),
('comunicacion_social', NULL, 'Comunicación social', NULL, 'v1_2026_02_18', true, now())
ON CONFLICT (topic_id) DO UPDATE SET
type = EXCLUDED.type, name = EXCLUDED.name, description = EXCLUDED.description, version_id = EXCLUDED.version_id, is_active = EXCLUDED.is_active, updated_at = EXCLUDED.updated_at;

INSERT INTO rel_activity_topics (activity_id, topic_id, version_id, is_active, updated_at)
VALUES
('CAM', 'galibos_ferroviarios', 'v1_2026_02_18', true, now()),
('CAM', 'accesos_y_pasos_vehiculares', 'v1_2026_02_18', true, now()),
('CAM', 'caminos_de_servicio', 'v1_2026_02_18', true, now()),
('CAM', 'cruces_peatonales_puentes', 'v1_2026_02_18', true, now()),
('CAM', 'infraestructura_electrica_cfe', 'v1_2026_02_18', true, now()),
('CAM', 'hidraulica_conagua', 'v1_2026_02_18', true, now()),
('CAM', 'infraestructura_ferroviaria_existente', 'v1_2026_02_18', true, now()),
('CAM', 'tenencia_de_la_tierra', 'v1_2026_02_18', true, now()),
('CAM', 'avaluos_y_pagos', 'v1_2026_02_18', true, now()),
('CAM', 'arbolado_vegetacion', 'v1_2026_02_18', true, now()),
('CAM', 'cauces_y_cuerpos_de_agua', 'v1_2026_02_18', true, now()),
('CAM', 'sitios_arqueologicos_inah', 'v1_2026_02_18', true, now()),
('CAM', 'residuos_y_escombros', 'v1_2026_02_18', true, now()),
('REU', 'galibos_ferroviarios', 'v1_2026_02_18', true, now()),
('REU', 'accesos_y_pasos_vehiculares', 'v1_2026_02_18', true, now()),
('REU', 'infraestructura_electrica_cfe', 'v1_2026_02_18', true, now()),
('REU', 'hidraulica_conagua', 'v1_2026_02_18', true, now()),
('REU', 'infraestructura_ferroviaria_existente', 'v1_2026_02_18', true, now()),
('REU', 'avaluos_y_pagos', 'v1_2026_02_18', true, now()),
('REU', 'asambleas_ejidales', 'v1_2026_02_18', true, now()),
('REU', 'inconformidades_comunitarias', 'v1_2026_02_18', true, now()),
('REU', 'reubicaciones', 'v1_2026_02_18', true, now()),
('REU', 'actores_locales', 'v1_2026_02_18', true, now()),
('REU', 'coordinacion_interinstitucional', 'v1_2026_02_18', true, now()),
('REU', 'documentacion_pendiente', 'v1_2026_02_18', true, now()),
('REU', 'protocolos_de_seguridad', 'v1_2026_02_18', true, now()),
('ASP', 'tenencia_de_la_tierra', 'v1_2026_02_18', true, now()),
('ASP', 'avaluos_y_pagos', 'v1_2026_02_18', true, now()),
('ASP', 'asambleas_ejidales', 'v1_2026_02_18', true, now()),
('ASP', 'inconformidades_comunitarias', 'v1_2026_02_18', true, now()),
('ASP', 'reubicaciones', 'v1_2026_02_18', true, now()),
('ASP', 'comunicacion_social', 'v1_2026_02_18', true, now()),
('CIN', 'consulta_previa', 'v1_2026_02_18', true, now()),
('CIN', 'lengua_y_traductores', 'v1_2026_02_18', true, now()),
('CIN', 'actos_y_acuerdos_finales', 'v1_2026_02_18', true, now()),
('CIN', 'inconformidades_comunitarias', 'v1_2026_02_18', true, now()),
('CIN', 'arbolado_vegetacion', 'v1_2026_02_18', true, now()),
('CIN', 'sitios_arqueologicos_inah', 'v1_2026_02_18', true, now()),
('SOC', 'inconformidades_comunitarias', 'v1_2026_02_18', true, now()),
('SOC', 'comunicacion_social', 'v1_2026_02_18', true, now()),
('SOC', 'arbolado_vegetacion', 'v1_2026_02_18', true, now()),
('SOC', 'fauna_local', 'v1_2026_02_18', true, now()),
('SOC', 'residuos_y_escombros', 'v1_2026_02_18', true, now()),
('AIN', 'coordinacion_interinstitucional', 'v1_2026_02_18', true, now()),
('AIN', 'documentacion_pendiente', 'v1_2026_02_18', true, now()),
('AIN', 'protocolos_de_seguridad', 'v1_2026_02_18', true, now()),
('AIN', 'coordinacion_interinstitucional', 'v1_2026_02_18', true, now()),
('AIN', 'documentacion_pendiente', 'v1_2026_02_18', true, now()),
('AIN', 'protocolos_de_seguridad', 'v1_2026_02_18', true, now()),
('AIN', 'seguimiento_a_oficios', 'v1_2026_02_18', true, now()),
('AIN', 'participacion_comunitaria', 'v1_2026_02_18', true, now())
ON CONFLICT (activity_id, topic_id) DO UPDATE SET
version_id = EXCLUDED.version_id, is_active = EXCLUDED.is_active, updated_at = EXCLUDED.updated_at;

INSERT INTO cat_results (result_id, name, category, severity_default, version_id, is_active, updated_at)
VALUES
('R01', 'Actividad realizada conforme al programa', 'Ejecución regular o exitosa', 'green', 'v1_2026_02_18', true, now()),
('R02', 'Asamblea con quórum legal y acuerdos aprobados', 'Ejecución regular o exitosa', 'green', 'v1_2026_02_18', true, now()),
('R04', 'Firma de acta informativa / COP', 'Ejecución regular o exitosa', 'green', 'v1_2026_02_18', true, now()),
('R05', 'Se obtienen anuencias / permisos', 'Ejecución regular o exitosa', 'green', 'v1_2026_02_18', true, now()),
('R06', 'Se ajusta superficie o valor de afectación', 'Reajustes o cambios técnicos', 'yellow', 'v1_2026_02_18', true, now()),
('R07', 'Nuevas afectaciones identificadas', 'Reajustes o cambios técnicos', 'yellow', 'v1_2026_02_18', true, now()),
('R08', 'Solicitud canalizada a dependencia', 'Reajustes o cambios técnicos', 'yellow', 'v1_2026_02_18', true, now()),
('R03', 'Sin quórum / segunda convocatoria programada', 'Casos sociales o administrativos', 'red', 'v1_2026_02_18', true, now()),
('R10', 'Proceso en revisión / sin acuerdo final', 'Casos sociales o administrativos', 'red', 'v1_2026_02_18', true, now()),
('R11', 'Sin acuerdos / reunión informativa únicamente', 'Casos sociales o administrativos', 'red', 'v1_2026_02_18', true, now()),
('R09', 'Se acuerda mantenimiento o intervención', 'Seguimiento y compromisos interinstitucionales', 'blue', 'v1_2026_02_18', true, now()),
('R12', 'Se programa nueva reunión o seguimiento', 'Seguimiento y compromisos interinstitucionales', 'blue', 'v1_2026_02_18', true, now())
ON CONFLICT (result_id) DO UPDATE SET
name = EXCLUDED.name, category = EXCLUDED.category, severity_default = EXCLUDED.severity_default, version_id = EXCLUDED.version_id, is_active = EXCLUDED.is_active, updated_at = EXCLUDED.updated_at;

INSERT INTO cat_attendees (attendee_id, type, name, description, version_id, is_active, updated_at)
VALUES
('AST1', 'Dependencia', 'ARTF', 'Agencia Reguladora del Transporte Ferroviario', 'v1_2026_02_18', true, now()),
('AST2', 'Dependencia', 'SEDATU', 'Secretaría de Desarrollo Agrario', 'v1_2026_02_18', true, now()),
('AST3', 'Dependencia', 'Defensa (SEDENA)', 'Secretaría de la Defensa Nacional', 'v1_2026_02_18', true, now()),
('AST4', 'Dependencia', 'RAN', 'Registro Agrario Nacional', 'v1_2026_02_18', true, now()),
('AST5', 'Dependencia', 'PA', 'Procuraduría Agraria', 'v1_2026_02_18', true, now()),
('AST6', 'Dependencia', 'INDAABIN', 'Instituto de Administración y Avalúos de Bienes Nacionales', 'v1_2026_02_18', true, now()),
('AST7', 'Dependencia', 'FIFONAFE', 'Fideicomiso Fondo Nacional de Fomento Ejidal', 'v1_2026_02_18', true, now()),
('AST8', 'Dependencia', 'INAH', 'Antropología e Historia', 'v1_2026_02_18', true, now()),
('AST9', 'Dependencia', 'INPI', 'Pueblos Indígenas', 'v1_2026_02_18', true, now()),
('AST10', 'Dependencia', 'CONAGUA', 'Comisión Nacional del Agua', 'v1_2026_02_18', true, now()),
('AST11', 'Concesionario', 'Kansas', 'Concesionario ferroviario', 'v1_2026_02_18', true, now()),
('AST12', 'Concesionario', 'Ferromex', 'Concesionario ferroviario', 'v1_2026_02_18', true, now()),
('AST13', 'Autoridad', 'Gobierno Municipal', 'Ayuntamientos', 'v1_2026_02_18', true, now()),
('AST14', 'Autoridad', 'Gobierno Estatal', 'Gobiernos estatales', 'v1_2026_02_18', true, now()),
('AST15', 'Social', 'Comisariado Ejidal', 'Representación ejidal', 'v1_2026_02_18', true, now()),
('AST16', 'Seguridad', 'Guardia Nacional', 'Seguridad en campo', 'v1_2026_02_18', true, now()),
('AST17', 'Equipo', 'Vinculación SICT', 'Coordinación social y gestiones', 'v1_2026_02_18', true, now())
ON CONFLICT (attendee_id) DO UPDATE SET
type = EXCLUDED.type, name = EXCLUDED.name, description = EXCLUDED.description, version_id = EXCLUDED.version_id, is_active = EXCLUDED.is_active, updated_at = EXCLUDED.updated_at;

INSERT INTO proj_catalog_override (project_id, entity_type, entity_id, is_enabled, display_name_override, sort_order_override, color_override, severity_override, rules_json, version_id, is_active, updated_at)
VALUES
('TMQ', 'result', 'R08', true, NULL, NULL, NULL, 'red', '{''kpi'': {''sla_days'': 7, ''requires_followup'': True}}', 'v1_2026_02_18', true, now()),
('TAP', 'purpose', 'GAL_REV_CAM', false, NULL, NULL, NULL, NULL, NULL, 'v1_2026_02_18', true, now())
ON CONFLICT (project_id, entity_type, entity_id) DO UPDATE SET
is_enabled = EXCLUDED.is_enabled, display_name_override = EXCLUDED.display_name_override, sort_order_override = EXCLUDED.sort_order_override, color_override = EXCLUDED.color_override, severity_override = EXCLUDED.severity_override, rules_json = EXCLUDED.rules_json, version_id = EXCLUDED.version_id, is_active = EXCLUDED.is_active, updated_at = EXCLUDED.updated_at;

COMMIT;
