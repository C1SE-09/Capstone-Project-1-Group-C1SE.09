from pydantic import BaseModel, Field


class login_request(BaseModel):
    username: str
    password: str
    device_id: str | None = None
    device_name: str | None = None

class login_response(BaseModel):
    access_token: str
    refresh_token: str
    session_id: str
    token_type: str
    role: str
    user_id: str | None = None
    teacher_id: str | None = None
    parent_id: str | None = None

class change_password_request(BaseModel):
    current_password: str = Field(..., min_length=1, max_length=128)
    new_password: str = Field(..., min_length=6, max_length=72)
    logout_other_devices: bool = True

class forgot_password_request(BaseModel):
    email: str

class verify_reset_code_request(BaseModel):
    email: str
    reset_code: str

class reset_password_request(BaseModel):
    email: str
    reset_code: str
    new_password: str

class refresh_token_request(BaseModel):
    session_id: str
    refresh_token: str