"""패치 서명(RSA-2048, PKCS#1 v1.5, SHA-256)과 판 기록 HMAC.
Godot 4의 Crypto.verify가 RSA만 받아서 ed25519 대신 RSA를 쓴다."""
import base64
import hashlib
import hmac
import os

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding, rsa

from . import config

_key = None


def private_key():
    global _key
    if _key is None:
        with open(config.PATCH_KEY_PATH, "rb") as f:
            _key = serialization.load_pem_private_key(f.read(), password=None)
    return _key


def generate_keypair(path: str) -> str:
    """개인키를 path에 쓰고 공개키 PEM을 돌려준다."""
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with open(path, "wb") as f:
        f.write(key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8, serialization.NoEncryption()))
    os.chmod(path, 0o600)
    return public_pem(key)


def public_pem(key=None) -> str:
    key = key or private_key()
    return key.public_key().public_bytes(serialization.Encoding.PEM, serialization.PublicFormat.SubjectPublicKeyInfo).decode()


def sign(payload: str) -> str:
    sig = private_key().sign(payload.encode(), padding.PKCS1v15(), hashes.SHA256())
    return base64.b64encode(sig).decode()


def verify(payload: str, sig: str, pub_pem: str) -> bool:
    pub = serialization.load_pem_public_key(pub_pem.encode())
    try:
        pub.verify(base64.b64decode(sig), payload.encode(), padding.PKCS1v15(), hashes.SHA256())
        return True
    except Exception:
        return False


def run_mac(body: bytes) -> str:
    return hmac.new(config.RUN_HMAC_KEY.encode(), body, hashlib.sha256).hexdigest()


def check_run_mac(body: bytes, mac: str) -> bool:
    if not config.RUN_HMAC_KEY:
        return True  # 키를 안 정했으면 검사하지 않음 (개발용)
    return hmac.compare_digest(run_mac(body), (mac or "").lower())


def ip_hash(ip: str) -> str:
    return hashlib.sha256((config.IP_SALT + ip).encode()).hexdigest()[:32]
