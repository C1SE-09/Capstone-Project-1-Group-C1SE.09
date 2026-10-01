from pydantic import BaseModel


class login_request(BaseModel):
    username: str
    password: str

class login_response(BaseModel):
    access_token: str
    token_type: str
    role: str
    