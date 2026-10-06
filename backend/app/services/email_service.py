import os
import smtplib
from email.message import EmailMessage

SMTP_HOST = os.getenv("SMTP_HOST", "smtp.gmail.com")
SMTP_PORT = int(os.getenv("SMTP_PORT", "587"))
SMTP_USERNAME = os.getenv("SMTP_USERNAME")
SMTP_PASSWORD = os.getenv("SMTP_PASSWORD")
SMTP_FROM = os.getenv("SMTP_FROM", SMTP_USERNAME)

def send_test_email(to_email: str, subject: str, body: str):
    if not SMTP_USERNAME or not SMTP_PASSWORD:
        raise ValueError("SMTP chưa được cấu hình")

    message = EmailMessage()
    message["Subject"] = "Kinderlog - Test Email"
    message["From"] = SMTP_FROM
    message["To"] = to_email
    message.set_content(
        "Đây là email test từ hệ thống Kinderlog. Nếu bạn nhận được email này, nghĩa là cấu hình SMTP đã thành công."
    )

    with smtplib.SMTP(SMTP_HOST, SMTP_PORT, timeout=20) as server:
        server.starttls()
        server.login(SMTP_USERNAME, SMTP_PASSWORD)
        server.send_message(message)