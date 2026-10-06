import os
import smtplib
from email.message import EmailMessage

from app.config import settings

def send_test_email(to_email: str, subject: str, body: str):
    smtp_host = settings.smtp_host or os.getenv("SMTP_HOST", "smtp.gmail.com")
    smtp_port = int(settings.smtp_port or os.getenv("SMTP_PORT", "587"))
    smtp_username = settings.smtp_username or os.getenv("SMTP_USERNAME")
    smtp_password = settings.smtp_password or os.getenv("SMTP_PASSWORD")
    smtp_from = settings.smtp_from or os.getenv("SMTP_FROM") or smtp_username

    if not smtp_username or not smtp_password:
        raise ValueError("SMTP chưa được cấu hình. Vui lòng thiết lập SMTP_USERNAME và SMTP_PASSWORD trong file .env.")

    # Loại bỏ khoảng trắng thừa nếu người dùng copy app password dạng 'xxxx xxxx xxxx xxxx'
    clean_password = smtp_password.replace(" ", "").strip()

    message = EmailMessage()
    message["Subject"] = subject
    message["From"] = smtp_from
    message["To"] = to_email
    message.set_content(body)

    with smtplib.SMTP(smtp_host, smtp_port, timeout=20) as server:
        server.starttls()
        server.login(smtp_username, clean_password)
        server.send_message(message)