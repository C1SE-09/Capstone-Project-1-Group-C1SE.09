from pydantic import BaseModel


class login_request(BaseModel):
    username: str
    password: str


class login_response(BaseModel):
    access_token: str
    token_type: str
    role: str
    user_id: str | None = None
    teacher_id: str | None = None
    parent_id: str | None = None

class change_password_request(BaseModel):
    current_password: str
    new_password: str

class forgot_password_request(BaseModel):
    email: str

class verify_reset_code_request(BaseModel):
    email: str
    reset_code: str

class reset_password_request(BaseModel):
    email: str
    reset_code: str
    new_password: str