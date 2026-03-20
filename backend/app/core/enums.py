"""
Pure-Python enumerations shared across the application.

These are defined here (no SQLAlchemy dependency) so routers, services, and
schemas can import them without dragging in the ORM layer.  The model files
(app/models/*.py) import from here too, ensuring a single source of truth.
"""
import enum


class UserStatus(str, enum.Enum):
    ACTIVE = "active"
    INACTIVE = "inactive"
    LOCKED = "locked"


class CatalogStatus(str, enum.Enum):
    """Estados del ciclo de vida de un catálogo"""
    DRAFT = "draft"
    PUBLISHED = "published"
    DEPRECATED = "deprecated"


class EntityType(str, enum.Enum):
    """Tipos de entidades para formularios y workflows"""
    ACTIVITY = "activity"
    EVENT = "event"


class WidgetType(str, enum.Enum):
    """Tipos de widgets para formularios dinámicos"""
    TEXT = "text"
    NUMBER = "number"
    DATE = "date"
    TIME = "time"
    DATETIME = "datetime"
    TEXTAREA = "textarea"
    SELECT = "select"
    MULTISELECT = "multiselect"
    RADIO = "radio"
    CHECKBOX = "checkbox"
    GPS = "gps"
    SIGNATURE = "signature"
    FILE = "file"
    PHOTO = "photo"


class ProjectStatus(str, enum.Enum):
    ACTIVE = "active"
    ARCHIVED = "archived"
