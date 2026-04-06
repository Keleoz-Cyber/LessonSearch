"""
测试 SMTP 连接脚本
"""
import smtplib
import os
from dotenv import load_dotenv

load_dotenv()

SMTP_HOST = os.getenv('SMTP_HOST')
SMTP_PORT = int(os.getenv('SMTP_PORT', '465'))
SMTP_USER = os.getenv('SMTP_USER')
SMTP_PASSWORD = os.getenv('SMTP_PASSWORD')

print(f"SMTP_HOST: {SMTP_HOST}")
print(f"SMTP_PORT: {SMTP_PORT}")
print(f"SMTP_USER: {SMTP_USER}")
print(f"SMTP_PASSWORD: {SMTP_PASSWORD[:4]}...{SMTP_PASSWORD[-4:] if SMTP_PASSWORD else 'None'}")

try:
    print("\n正在连接 SMTP 服务器...")
    with smtplib.SMTP_SSL(SMTP_HOST, SMTP_PORT) as server:
        print("连接成功！")
        print("正在登录...")
        server.login(SMTP_USER, SMTP_PASSWORD)
        print("登录成功！")
        print("\nSMTP 配置正常 ✓")
except Exception as e:
    print(f"\n错误: {e}")
    print("\n可能的问题:")
    print("1. SMTP_HOST 应该是 smtp.163.com")
    print("2. SMTP_PORT 应该是 465")
    print("3. SMTP_USER 格式应为 xxx@163.com")
    print("4. SMTP_PASSWORD 应为授权码（不是密码）")
    print("5. 163邮箱需要开启SMTP服务并获取授权码")