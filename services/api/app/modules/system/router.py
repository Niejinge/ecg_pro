from fastapi import APIRouter

from app.core.config import get_settings
from app.modules.system.schemas import ServiceInfo

router = APIRouter(tags=["system"])


@router.get("/info", response_model=ServiceInfo)
def get_service_info() -> ServiceInfo:
    settings = get_settings()
    return ServiceInfo(
        name=settings.app_name,
        env=settings.app_env,
        version="0.1.0",
        api_prefix=settings.api_v1_prefix,
    )

