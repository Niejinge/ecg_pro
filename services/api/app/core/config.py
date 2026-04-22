from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    app_name: str = "ECG Pro API"
    app_env: str = "development"
    app_host: str = "0.0.0.0"
    app_port: int = 8000
    app_debug: bool = True
    api_v1_prefix: str = "/api/v1"

    secret_key: str = "change-me"
    access_token_expire_minutes: int = 120

    database_url: str = (
        "postgresql+psycopg://ecg_user:ecg_pass@postgres:5432/ecg_pro"
    )
    storage_backend: str = "local"
    local_storage_path: str = "/app/storage"
    public_base_url: str = "http://localhost:8080"
    minio_bucket: str = "ecg-assets"

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )


@lru_cache
def get_settings() -> Settings:
    return Settings()

