from app.core.permission_catalog import DEFAULT_ROLE_PERMISSION_CODES


def test_default_role_permission_codes_match_expected_matrix() -> None:
    expected = {
        "ADMIN": {
            "Ver actividades",
            "Crear actividades",
            "Editar actividades",
            "Eliminar actividades",
            "Aprobar actividades",
            "Rechazar actividades",
            "Crear eventos",
            "Editar eventos",
            "Ver eventos",
            "Ver catálogo",
            "Editar catálogo",
            "Publicar catálogo",
            "Crear usuarios",
            "Editar usuarios",
            "Ver usuarios",
            "Ver reportes",
            "Exportar reportes",
            "Administrar asignaciones",
            "Administrar proyectos",
            "Aprobar excepciones de flujo",
        },
        "COORD": {
            "Ver actividades",
            "Crear actividades",
            "Editar actividades",
            "Eliminar actividades",
            "Aprobar actividades",
            "Rechazar actividades",
            "Crear eventos",
            "Editar eventos",
            "Ver eventos",
            "Ver catálogo",
            "Editar catálogo",
            "Ver usuarios",
            "Ver reportes",
            "Exportar reportes",
            "Administrar asignaciones",
        },
        "SUPERVISOR": {
            "Ver actividades",
            "Crear actividades",
            "Editar actividades",
            "Aprobar actividades",
            "Rechazar actividades",
            "Crear eventos",
            "Editar eventos",
            "Ver eventos",
            "Ver catálogo",
            "Editar catálogo",
            "Publicar catálogo",
            "Ver reportes",
            "Exportar reportes",
            "Administrar asignaciones",
            "Administrar proyectos",
        },
        "OPERATIVO": {
            "Ver actividades",
            "Crear actividades",
            "Editar actividades",
            "Crear eventos",
            "Ver eventos",
            "Ver catálogo",
        },
        "LECTOR": {
            "Ver actividades",
            "Ver eventos",
            "Ver catálogo",
            "Ver usuarios",
            "Ver reportes",
        },
    }

    actual = {
        role: set(permission_codes)
        for role, permission_codes in DEFAULT_ROLE_PERMISSION_CODES.items()
    }

    assert actual == expected
