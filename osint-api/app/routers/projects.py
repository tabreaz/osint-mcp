from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.database import get_db
from app.auth.api_key import verify_api_key

router = APIRouter(
    prefix="/projects",
    tags=["projects"],
    dependencies=[Depends(verify_api_key)]
)


@router.get("")
async def get_projects(
    db: AsyncSession = Depends(get_db)
):
    """Get list of all projects - placeholder endpoint"""
    return {
        "message": "Projects endpoint - to be implemented",
        "projects": []
    }