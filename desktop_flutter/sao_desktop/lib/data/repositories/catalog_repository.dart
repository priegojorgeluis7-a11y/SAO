import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Catálogos DATA-DRIVEN compartidos entre app móvil y escritorio.
/// Carga desde JSON base (assets/catalogos.json) + items personalizados (archivo local).
class CatalogRepository {
  CatalogRepository();

  bool _ready = false;
  bool get isReady => _ready;

  CatalogData _data = CatalogData.mock();
  CatalogData get data => _data;

  /// Carga desde assets si existe (assets/catalogos.json).
  /// Si no existe, usa mock.
  Future<void> init() async {
    if (_ready) return;

    try {
      final raw = await rootBundle.loadString('assets/catalogos.json');
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _data = CatalogData.fromJson(map);
    } catch (_) {
      _data = CatalogData.mock();
    }

    _ready = true;
  }

  /// Obtiene lista de tipos de actividad
  List<CatItem> getActivityTypes() {
    return _data.activities;
  }

  /// Obtiene lista de municipios (simulado por ahora)
  List<String> getMunicipalities() {
    return [
      'Apaseo el Grande',
      'Celaya',
      'Pedro Escobedo',
      'Querétaro',
      'Tizayuca',
      'Temascalapa',
      'Zumpango',
    ];
  }

  /// Obtiene lista de estados
  List<String> getStates() {
    return [
      'Guanajuato',
      'Hidalgo',
      'Estado de México',
      'Querétaro',
    ];
  }
}

final catalogRepositoryProvider = Provider<CatalogRepository>((ref) {
  return CatalogRepository();
});

// Modelo de datos básico
class CatalogData {
  final List<CatItem> activities;
  final Map<String, List<CatItem>> subcategoriesByActivity;
  final Map<String, List<CatItem>> purposesBySubcategory;
  final List<CatItem> topics;

  CatalogData({
    required this.activities,
    required this.subcategoriesByActivity,
    required this.purposesBySubcategory,
    required this.topics,
  });

  factory CatalogData.fromJson(Map<String, dynamic> json) {
    return CatalogData(
      activities: (json['activities'] as List)
          .map((e) => CatItem.fromJson(e))
          .toList(),
      subcategoriesByActivity: (json['subcategoriesByActivity'] as Map<String, dynamic>)
          .map((key, value) => MapEntry(
              key, (value as List).map((e) => CatItem.fromJson(e)).toList())),
      purposesBySubcategory: (json['purposesBySubcategory'] as Map<String, dynamic>)
          .map((key, value) => MapEntry(
              key, (value as List).map((e) => CatItem.fromJson(e)).toList())),
      topics: (json['topics'] as List)
          .map((e) => CatItem.fromJson(e))
          .toList(),
    );
  }

  factory CatalogData.mock() {
    return CatalogData.fromJson({
      'activities': [
        {'id': 'CAM', 'name': 'Caminamiento'},
        {'id': 'REU', 'name': 'Reunión'},
        {'id': 'ASP', 'name': 'Asamblea Protocolizada'},
        {'id': 'CIN', 'name': 'Consulta Indígena'},
        {'id': 'SOC', 'name': 'Socialización'},
        {'id': 'AIN', 'name': 'Acompañamiento Institucional'},
      ],
      'subcategoriesByActivity': {
        'CAM': [
          {'id': 'CAM_DDV', 'name': 'Verificación de DDV'},
          {'id': 'CAM_MAR', 'name': 'Marcaje de afectaciones'},
          {'id': 'CAM_ACC', 'name': 'Revisión de accesos / BDT'},
          {'id': 'CAM_SEG', 'name': 'Seguimiento técnico'},
        ],
        'REU': [
          {'id': 'REU_TEC', 'name': 'Técnica / Interinstitucional'},
          {'id': 'REU_EJI', 'name': 'Ejidal / Comisariado'},
          {'id': 'REU_MUN', 'name': 'Municipal / Estatal / Protección Civil'},
          {'id': 'REU_SEG', 'name': 'Seguimiento / Evaluación'},
          {'id': 'REU_INF', 'name': 'Informativa'},
          {'id': 'REU_MES', 'name': 'Mesa Técnica'},
        ],
        'ASP': [
          {'id': 'ASP_1AP', 'name': '1ª Asamblea Protocolizada (1AP)'},
          {'id': 'ASP_1AP_PER', 'name': '1ª Asamblea Protocolizada Permanente'},
          {'id': 'ASP_2AP', 'name': '2ª Asamblea Protocolizada (2AP)'},
          {'id': 'ASP_2AP_PER', 'name': '2ª Asamblea Protocolizada Permanente'},
          {'id': 'ASP_INF', 'name': 'Asamblea Informativa'},
        ],
        'CIN': [
          {'id': 'CIN_INF', 'name': 'Etapa Informativa'},
          {'id': 'CIN_CON', 'name': 'Etapa de Construcción de Acuerdos'},
          {'id': 'CIN_ACT', 'name': 'Etapa de Actos y Acuerdos'},
        ],
        'SOC': [
          {'id': 'SOC_PRE', 'name': 'Presentación Comunitaria'},
          {'id': 'SOC_DIF', 'name': 'Difusión de Información'},
          {'id': 'SOC_ATN', 'name': 'Atención a Inquietudes'},
        ],
        'AIN': [
          {'id': 'AIN_TEC', 'name': 'Técnico'},
          {'id': 'AIN_SOC', 'name': 'Social'},
          {'id': 'AIN_DOC', 'name': 'Documental'},
        ],
      },
      'purposesBySubcategory': {
        'CAM_DDV': [
          {'id': 'AFEC_VER_CAM', 'name': 'Verificación de afectaciones'},
        ],
        'CAM_MAR': [
          {'id': 'DDV_MAR_CAM', 'name': 'Marcaje o actualización de DDV / trazo'},
        ],
        'CAM_ACC': [
          {'id': 'ACC_ALT_CAM', 'name': 'Análisis de accesos y pasos alternos'},
        ],
        'REU_INF': [
          {'id': 'PRS_GEN_REU', 'name': 'Presentación general del proyecto'},
          {'id': 'DOC_CONV_REU', 'name': 'Entrega de documentación / Convocatorias'},
        ],
        'REU_TEC': [
          {'id': 'CONC_FER_REU', 'name': 'Coordinación con concesionarios ferroviarios'},
          {'id': 'COOR_INST_REU', 'name': 'Coordinación institucional'},
        ],
        'REU_SEG': [
          {'id': 'SOC_CON_REU', 'name': 'Atención a inconformidades o conflictos'},
          {'id': 'PLAN_ACT_REU', 'name': 'Planeación de nuevas actividades'},
          {'id': 'SEG_DOC_REU', 'name': 'Seguimiento administrativo / documental'},
        ],
        'ASP_1AP': [
          {'id': 'PRS_GEN_ASP', 'name': 'Presentación general del proyecto'},
          {'id': 'DOC_CONV_ASP', 'name': 'Entrega de documentación / Convocatorias'},
        ],
        'ASP_2AP': [
          {'id': 'COP_FIR_ASP', 'name': 'Obtención de anuencia o firma de COP'},
        ],
        'CIN_INF': [
          {'id': 'PRS_GEN_CIN', 'name': 'Presentación general del proyecto'},
          {'id': 'DOC_CONV_CIN', 'name': 'Entrega de documentación / Convocatorias'},
        ],
        'CIN_CON': [
          {'id': 'SOC_CON_CIN', 'name': 'Atención a inconformidades o conflictos'},
        ],
        'SOC_PRE': [
          {'id': 'PRS_GEN_SOC', 'name': 'Presentación general del proyecto'},
        ],
        'SOC_ATN': [
          {'id': 'SOC_CON_SOC', 'name': 'Atención a inconformidades o conflictos'},
        ],
        'AIN_DOC': [
          {'id': 'SEG_DOC_AIN', 'name': 'Seguimiento administrativo / documental'},
        ],
      },
      'topics': [
        {'id': 'galibos_ferroviarios', 'name': 'Gálibos ferroviarios'},
        {'id': 'accesos_y_pasos_vehiculares', 'name': 'Accesos y pasos vehiculares'},
        {'id': 'infraestructura_electrica_cfe', 'name': 'Infraestructura eléctrica / CFE'},
        {'id': 'hidraulica_conagua', 'name': 'Hidráulica / CONAGUA'},
        {'id': 'tenencia_de_la_tierra', 'name': 'Tenencia de la tierra'},
        {'id': 'avaluos_y_pagos', 'name': 'Avalúos y pagos'},
        {'id': 'asambleas_ejidales', 'name': 'Asambleas ejidales'},
        {'id': 'inconformidades_comunitarias', 'name': 'Inconformidades comunitarias'},
        {'id': 'arbolado_vegetacion', 'name': 'Arbolado / vegetación'},
        {'id': 'fauna_local', 'name': 'Fauna local'},
        {'id': 'sitios_arqueologicos_inah', 'name': 'Sitios arqueológicos / INAH'},
        {'id': 'coordinacion_interinstitucional', 'name': 'Coordinación interinstitucional'},
        {'id': 'documentacion_pendiente', 'name': 'Documentación pendiente'},
        {'id': 'consulta_previa', 'name': 'Consulta previa'},
        {'id': 'lengua_y_traductores', 'name': 'Lengua y traductores'},
        {'id': 'actos_y_acuerdos_finales', 'name': 'Actos y acuerdos finales'},
      ],
    });
  }
}

class CatItem {
  final String id;
  final String name;
  final IconData? icon;

  CatItem({
    required this.id,
    required this.name,
    this.icon,
  });

  factory CatItem.fromJson(Map<String, dynamic> json) {
    return CatItem(
      id: json['id'],
      name: json['name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}