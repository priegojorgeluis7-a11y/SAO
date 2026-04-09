from datetime import datetime, timezone
from uuid import uuid4

from app.api.v1.sync import _sync_error_guidance
from app.schemas.activity import (
    ActivityDTO,
    build_canonical_flow_projection,
    infer_next_action,
    infer_operational_state,
    infer_review_state,
    infer_sync_state,
)


def test_infer_review_state_maps_canonical_review_decisions():
    assert infer_review_state('PENDIENTE', 'APPROVE') == 'APPROVED'
    assert infer_review_state('PENDIENTE', 'APPROVE_EXCEPTION') == 'APPROVED'
    assert infer_review_state('PENDIENTE', 'REJECT') == 'REJECTED'
    assert infer_review_state('PENDIENTE', 'CHANGES_REQUIRED') == 'CHANGES_REQUIRED'
    assert infer_review_state('PENDIENTE', 'REQUEST_CHANGES') == 'CHANGES_REQUIRED'


def test_infer_review_state_falls_back_from_execution_state():
    assert infer_review_state('REVISION_PENDIENTE', None) == 'PENDING_REVIEW'
    assert infer_review_state('COMPLETADA', None) == 'PENDING_REVIEW'
    assert infer_review_state('EN_CURSO', None) == 'NOT_APPLICABLE'


def test_infer_operational_state_maps_execution_states():
    assert infer_operational_state('PENDIENTE') == 'PENDIENTE'
    assert infer_operational_state('EN_CURSO') == 'EN_CURSO'
    assert infer_operational_state('REVISION_PENDIENTE') == 'POR_COMPLETAR'
    assert infer_operational_state('COMPLETADA') == 'POR_COMPLETAR'
    assert infer_operational_state('CANCELED') == 'CANCELADA'
    assert infer_operational_state('UNKNOWN') == 'PENDIENTE'


def test_infer_next_action_respects_review_sync_and_operational_priority():
    assert infer_next_action('PENDIENTE', 'SYNCED', 'NOT_APPLICABLE') == 'INICIAR_ACTIVIDAD'
    assert infer_next_action('EN_CURSO', 'SYNCED', 'NOT_APPLICABLE') == 'TERMINAR_ACTIVIDAD'
    assert infer_next_action('POR_COMPLETAR', 'SYNCED', 'NOT_APPLICABLE') == 'COMPLETAR_WIZARD'
    assert infer_next_action('POR_COMPLETAR', 'SYNCED', 'PENDING_REVIEW') == 'ESPERAR_DECISION_COORDINACION'
    assert infer_next_action('POR_COMPLETAR', 'SYNCED', 'CHANGES_REQUIRED') == 'CORREGIR_Y_REENVIAR'
    assert infer_next_action('PENDIENTE', 'SYNC_ERROR', 'NOT_APPLICABLE') == 'REVISAR_ERROR_SYNC'
    assert infer_next_action('PENDIENTE', 'READY_TO_SYNC', 'NOT_APPLICABLE') == 'SINCRONIZAR_PENDIENTE'
    assert infer_next_action('CANCELADA', 'SYNCED', 'NOT_APPLICABLE') == 'CERRADA_CANCELADA'


def test_infer_sync_state_respects_explicit_and_heuristics():
    assert infer_sync_state('SYNC_ERROR') == 'SYNC_ERROR'
    assert infer_sync_state(None, has_sync_error=True) == 'SYNC_ERROR'
    assert infer_sync_state(None, sync_in_progress=True) == 'SYNC_IN_PROGRESS'
    assert infer_sync_state(None, has_local_changes=True) == 'READY_TO_SYNC'
    assert infer_sync_state('queued') == 'READY_TO_SYNC'
    assert infer_sync_state('unknown-state') == 'SYNCED'


def test_build_canonical_projection_prioritizes_review_and_sync_error_actions():
    projection = build_canonical_flow_projection(
        execution_state='REVISION_PENDIENTE',
        review_decision='CHANGES_REQUIRED',
        sync_state='SYNC_ERROR',
    )

    assert projection['operational_state'] == 'POR_COMPLETAR'
    assert projection['sync_state'] == 'SYNC_ERROR'
    assert projection['review_state'] == 'CHANGES_REQUIRED'
    assert projection['next_action'] == 'CORREGIR_Y_REENVIAR'


def test_activity_dto_hydrates_canonical_projection_from_execution_and_review():
    dto = ActivityDTO(
        uuid=uuid4(),
        project_id='TMQ',
        pk_start=142000,
        execution_state='REVISION_PENDIENTE',
        review_decision=None,
        created_by_user_id=uuid4(),
        catalog_version_id=uuid4(),
        activity_type_code='INSP_CIVIL',
        title='Actividad de prueba',
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc),
        sync_version=3,
    )

    assert dto.operational_state == 'POR_COMPLETAR'
    assert dto.sync_state == 'SYNCED'
    assert dto.review_state == 'PENDING_REVIEW'
    assert dto.next_action == 'ESPERAR_DECISION_COORDINACION'


def test_activity_dto_preserves_sync_error_for_next_action():
    dto = ActivityDTO(
        uuid=uuid4(),
        project_id='TMQ',
        pk_start=142000,
        execution_state='PENDIENTE',
        review_decision=None,
        created_by_user_id=uuid4(),
        catalog_version_id=uuid4(),
        activity_type_code='INSP_CIVIL',
        title='Actividad de prueba',
        created_at=datetime.now(timezone.utc),
        updated_at=datetime.now(timezone.utc),
        sync_state='SYNC_ERROR',
        sync_version=4,
    )

    assert dto.operational_state == 'PENDIENTE'
    assert dto.sync_state == 'SYNC_ERROR'
    assert dto.review_state == 'NOT_APPLICABLE'
    assert dto.next_action == 'REVISAR_ERROR_SYNC'


def test_sync_error_guidance_maps_conflict_and_server_errors():
    assert _sync_error_guidance(result_status='CONFLICT', error_code=None) == (
        False,
        'PULL_AND_RESOLVE_CONFLICT',
    )
    assert _sync_error_guidance(result_status='INVALID', error_code='SERVER_ERROR') == (
        True,
        'RETRY_AUTOMATIC',
    )


def test_sync_error_guidance_maps_catalog_and_project_validation_errors():
    assert _sync_error_guidance(
        result_status='INVALID',
        error_code='PROJECT_ID_MISMATCH',
    ) == (False, 'FIX_PROJECT_CONTEXT')
    assert _sync_error_guidance(
        result_status='INVALID',
        error_code='CATALOG_VERSION_NOT_FOUND',
    ) == (False, 'REFRESH_CATALOG_AND_RETRY')
    assert _sync_error_guidance(
        result_status='INVALID',
        error_code='ACTIVITY_TYPE_NOT_IN_CATALOG_VERSION',
    ) == (False, 'REFRESH_CATALOG_AND_RETRY')
    assert _sync_error_guidance(result_status='INVALID', error_code=None) == (
        False,
        'REVIEW_PAYLOAD',
    )


def test_sync_error_guidance_returns_none_for_success_statuses():
    assert _sync_error_guidance(result_status='CREATED', error_code=None) == (None, None)
    assert _sync_error_guidance(result_status='UPDATED', error_code=None) == (None, None)
    assert _sync_error_guidance(result_status='UNCHANGED', error_code=None) == (None, None)