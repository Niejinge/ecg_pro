from fastapi import APIRouter

from app.modules.admin.router import router as admin_router
from app.modules.auth.router import router as auth_router
from app.modules.cases.router import admin_router as admin_cases_router
from app.modules.cases.router import public_router as public_cases_router
from app.modules.learning.router import router as learning_router
from app.modules.media.router import admin_router as admin_media_router
from app.modules.media.router import public_router as public_media_router
from app.modules.quizzes.router import admin_router as admin_quizzes_router
from app.modules.quizzes.router import public_router as public_quizzes_router
from app.modules.quizzes.router import user_router as user_quizzes_router
from app.modules.system.router import router as system_router
from app.modules.taxonomy.router import admin_router as admin_taxonomy_router
from app.modules.taxonomy.router import public_router as public_taxonomy_router

api_router = APIRouter()
api_router.include_router(system_router, prefix="/system")
api_router.include_router(auth_router, prefix="/auth")
api_router.include_router(admin_router, prefix="/admin")
api_router.include_router(public_cases_router, prefix="/public")
api_router.include_router(public_taxonomy_router, prefix="/public")
api_router.include_router(public_quizzes_router, prefix="/public")
api_router.include_router(public_media_router, prefix="/public")
api_router.include_router(admin_cases_router, prefix="/admin")
api_router.include_router(admin_taxonomy_router, prefix="/admin")
api_router.include_router(admin_quizzes_router, prefix="/admin")
api_router.include_router(admin_media_router, prefix="/admin")
api_router.include_router(learning_router, prefix="/user")
api_router.include_router(user_quizzes_router, prefix="/user")
