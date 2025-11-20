from typing import List, Optional
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func
from app.models.project import Project
from app.models.theme import Theme
from app.models.monitored_user import MonitoredUser


class ProjectRepository:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def get_all_projects(self) -> List[Project]:
        """Get all projects"""
        query = select(Project).order_by(Project.id)
        result = await self.db.execute(query)
        return result.scalars().all()

    async def get_project_by_id(self, project_id: int) -> Optional[Project]:
        """Get a project by ID"""
        query = select(Project).filter(Project.id == project_id)
        result = await self.db.execute(query)
        return result.scalar_one_or_none()

    async def get_active_projects(self) -> List[Project]:
        """Get only active projects"""
        query = select(Project).filter(Project.is_active == True).order_by(Project.id)
        result = await self.db.execute(query)
        return result.scalars().all()

    async def get_project_stats(self, project_id: int) -> dict:
        """Get statistics for a project"""
        # Count themes
        theme_query = select(func.count(Theme.id)).filter(Theme.project_id == project_id)
        theme_count = await self.db.execute(theme_query)

        # Count monitored users
        user_query = select(func.count(MonitoredUser.id)).filter(MonitoredUser.project_id == project_id)
        user_count = await self.db.execute(user_query)

        return {
            "theme_count": theme_count.scalar() or 0,
            "monitored_user_count": user_count.scalar() or 0
        }