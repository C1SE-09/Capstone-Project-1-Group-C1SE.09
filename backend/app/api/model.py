from fastapi import APIRouter
from pydantic import BaseModel
from app.services.extraction_service import extract_from_transcript

router = APIRouter()

class ExtractionRequest(BaseModel):
    transcript : str

@router.post("/extraction")
def extraction (request: ExtractionRequest):
    return extract_from_transcript(request.transcript)
