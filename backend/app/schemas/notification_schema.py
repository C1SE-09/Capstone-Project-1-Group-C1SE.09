from pydantic import BaseModel, Field


class DeviceTokenRequest(BaseModel):
    token: str = Field(min_length=1, max_length=512)
    device_type: str | None = Field(default=None, max_length=20)

class DeviceTokenResponse(BaseModel):
    message: str

class TestNotificationRequest(BaseModel):
    token: str = Field(min_length=1, max_length=512)
    title: str = Field(min_length=1, max_length=100)
    body: str = Field(min_length=1, max_length=500)