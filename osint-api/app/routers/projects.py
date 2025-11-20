from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from typing import Optional

from app.database import get_db
from app.auth.api_key import verify_api_key
from app.repositories.project_repository import ProjectRepository
from app.repositories.theme_repository import ThemeRepository
from app.schemas.project import ProjectWithThemesSchema, ProjectListResponse
from app.schemas.theme import ThemeBaseSchema

router = APIRouter(
    prefix="/projects",
    tags=["projects"],
    dependencies=[Depends(verify_api_key)]
)


@router.get("", response_model=ProjectListResponse)
async def get_projects(
    active_only: bool = False,
    db: AsyncSession = Depends(get_db)
):
    """Get list of all projects with their themes and statistics"""
    repo = ProjectRepository(db)
    theme_repo = ThemeRepository(db)

    if active_only:
        projects = await repo.get_active_projects()
    else:
        projects = await repo.get_all_projects()

    # Build response with themes and stats
    projects_with_data = []
    for project in projects:
        stats = await repo.get_project_stats(project.id)
        themes = await theme_repo.get_themes_by_project(project.id)

        project_data = ProjectWithThemesSchema(
            id=project.id,
            name=project.name,
            description=project.description,
            is_active=project.is_active,
            created_at=project.created_at,
            updated_at=project.updated_at,
            themes=[ThemeBaseSchema.model_validate(theme) for theme in themes],
            theme_count=stats["theme_count"],
            monitored_user_count=stats["monitored_user_count"]
        )
        projects_with_data.append(project_data)

    return ProjectListResponse(
        projects=projects_with_data,
        total=len(projects_with_data)
    )


@router.get("/{project_id}", response_model=ProjectWithThemesSchema)
async def get_project(
    project_id: int,
    db: AsyncSession = Depends(get_db)
):
    """Get a specific project with its themes"""
    repo = ProjectRepository(db)
    theme_repo = ThemeRepository(db)

    project = await repo.get_project_by_id(project_id)
    if not project:
        raise HTTPException(status_code=404, detail="Project not found")

    stats = await repo.get_project_stats(project_id)
    themes = await theme_repo.get_themes_by_project(project_id)

    return ProjectWithThemesSchema(
        id=project.id,
        name=project.name,
        description=project.description,
        is_active=project.is_active,
        created_at=project.created_at,
        updated_at=project.updated_at,
        themes=[ThemeBaseSchema.model_validate(theme) for theme in themes],
        theme_count=stats["theme_count"],
        monitored_user_count=stats["monitored_user_count"]
    )