from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime


class ProjectSchema(BaseModel):
    id: int
    name: str
    description: Optional[str]
    is_active: Optional[bool]
    created_at: Optional[datetime]
    updated_at: Optional[datetime]

    class Config:
        from_attributes = True


class ProjectWithThemesSchema(ProjectSchema):
    themes: List['ThemeBaseSchema'] = []
    theme_count: int = 0
    monitored_user_count: int = 0


class ProjectListResponse(BaseModel):
    projects: List[ProjectWithThemesSchema]
    total: int


# Forward reference for circular import
from app.schemas.theme import ThemeBaseSchema
ProjectWithThemesSchema.model_rebuild()