from fastapi import APIRouter

from app.modules.admin.router import router as admin_router
from app.modules.auth.router import router as auth_router
from app.modules.cases.router import router as cases_router
from app.modules.system.router import router as system_router

api_router = APIRouter()
api_router.include_router(system_router, prefix="/system")
api_router.include_router(auth_router, prefix="/auth")
api_router.include_router(cases_router, prefix="/public")
api_router.include_router(admin_router, prefix="/admin")
