from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from app.config import settings
from app.routers import tweets, themes, projects, analytics, monitored_users, topics, topic_analytics


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    print("Starting OSINT Monitoring API...")
    yield
    # Shutdown
    print("Shutting down OSINT Monitoring API...")


# Create FastAPI app
app = FastAPI(
    title=settings.API_TITLE,
    version=settings.API_VERSION,
    description=settings.API_DESCRIPTION,
    lifespan=lifespan
)

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Health check endpoint (no authentication required)
@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "service": settings.API_TITLE,
        "version": settings.API_VERSION
    }

# Include routers
app.include_router(tweets.router, prefix="/api/v1")
app.include_router(themes.router, prefix="/api/v1")
app.include_router(projects.router, prefix="/api/v1")
app.include_router(analytics.router, prefix="/api/v1")
app.include_router(monitored_users.router, prefix="/api/v1")
app.include_router(topics.router, prefix="/api/v1")  # Refined topics with recommendations
app.include_router(topic_analytics.router, prefix="/api/v1")  # Topic analytics (author expertise, evolution)

# Root endpoint
@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "message": f"Welcome to {settings.API_TITLE}",
        "version": settings.API_VERSION,
        "docs": "/docs",
        "health": "/health"
    }