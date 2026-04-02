import pytest
from fastapi import HTTPException

from core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_password,
    verify_password,
)


def test_hash_password_returns_different_hash_each_time():
    h1 = hash_password("password123")
    h2 = hash_password("password123")
    assert h1 != h2  # Argon2 uses random salt


def test_verify_password_correct():
    h = hash_password("mi_contraseña")
    assert verify_password("mi_contraseña", h) is True


def test_verify_password_incorrect():
    h = hash_password("mi_contraseña")
    assert verify_password("incorrecta", h) is False


def test_create_access_token_contains_user_id_and_roles():
    token = create_access_token("user-abc", ["docente", "directivo"])
    payload = decode_token(token)
    assert payload["sub"] == "user-abc"
    assert payload["roles"] == ["docente", "directivo"]
    assert payload["type"] == "access"


def test_create_refresh_token_type_is_refresh():
    token = create_refresh_token("user-abc")
    payload = decode_token(token)
    assert payload["sub"] == "user-abc"
    assert payload["type"] == "refresh"
    assert "roles" not in payload


def test_decode_invalid_token_raises_401():
    with pytest.raises(HTTPException) as exc_info:
        decode_token("token.invalido.xxx")
    assert exc_info.value.status_code == 401
