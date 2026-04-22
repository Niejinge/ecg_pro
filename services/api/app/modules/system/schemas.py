from pydantic import BaseModel


class ServiceInfo(BaseModel):
    name: str
    env: str
    version: str
    api_prefix: str

