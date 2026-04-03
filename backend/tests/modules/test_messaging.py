import uuid
import pytest
import pytest_asyncio
from httpx import AsyncClient
import sqlalchemy

from core.security import create_access_token, hash_password
from modules.users.models import Role, User, UserRole, UserStatus


@pytest_asyncio.fixture
async def user_a(db_session):
    result = await db_session.execute(sqlalchemy.select(Role).where(Role.name == "docente"))
    role = result.scalar_one_or_none()
    if not role:
        role = Role(name="docente")
        db_session.add(role)
        await db_session.flush()
    u = User(
        email=f"msg_a_{uuid.uuid4().hex[:6]}@test.com",
        password_hash=hash_password("pass"),
        nombre="UserA",
        status=UserStatus.activo,
    )
    db_session.add(u)
    await db_session.flush()
    db_session.add(UserRole(user_id=u.id, role_id=role.id))
    await db_session.commit()
    await db_session.refresh(u)
    return u


@pytest_asyncio.fixture
async def user_b(db_session):
    result = await db_session.execute(sqlalchemy.select(Role).where(Role.name == "docente"))
    role = result.scalar_one_or_none()
    if not role:
        role = Role(name="docente")
        db_session.add(role)
        await db_session.flush()
    u = User(
        email=f"msg_b_{uuid.uuid4().hex[:6]}@test.com",
        password_hash=hash_password("pass"),
        nombre="UserB",
        status=UserStatus.activo,
    )
    db_session.add(u)
    await db_session.flush()
    db_session.add(UserRole(user_id=u.id, role_id=role.id))
    await db_session.commit()
    await db_session.refresh(u)
    return u


@pytest.mark.asyncio
async def test_send_message(client: AsyncClient, user_a, user_b):
    token_a = create_access_token(str(user_a.id), ["docente"])
    response = await client.post(
        "/api/v1/messages/",
        json={
            "content": "Hola equipo",
            "type": "directo",
            "recipient_ids": [str(user_b.id)],
        },
        headers={"Authorization": f"Bearer {token_a}"},
    )
    assert response.status_code == 201
    data = response.json()["data"]
    assert data["content"] == "Hola equipo"
    assert data["sender_id"] == str(user_a.id)


@pytest.mark.asyncio
async def test_send_message_multiple_recipients(client: AsyncClient, user_a, user_b):
    token_a = create_access_token(str(user_a.id), ["docente"])
    token_b = create_access_token(str(user_b.id), ["docente"])
    response = await client.post(
        "/api/v1/messages/",
        json={
            "content": "Mensaje grupal",
            "type": "grupo",
            "recipient_ids": [str(user_a.id), str(user_b.id)],
        },
        headers={"Authorization": f"Bearer {token_a}"},
    )
    assert response.status_code == 201
    msg_id = response.json()["data"]["id"]
    # Both users should see the message in their inbox
    inbox_b = await client.get(
        "/api/v1/messages/inbox",
        headers={"Authorization": f"Bearer {token_b}"},
    )
    assert any(m["id"] == msg_id for m in inbox_b.json()["data"])


@pytest.mark.asyncio
async def test_get_inbox(client: AsyncClient, user_a, user_b):
    token_a = create_access_token(str(user_a.id), ["docente"])
    token_b = create_access_token(str(user_b.id), ["docente"])
    await client.post(
        "/api/v1/messages/",
        json={"content": "Para inbox", "type": "directo", "recipient_ids": [str(user_b.id)]},
        headers={"Authorization": f"Bearer {token_a}"},
    )
    response = await client.get(
        "/api/v1/messages/inbox",
        headers={"Authorization": f"Bearer {token_b}"},
    )
    assert response.status_code == 200
    data = response.json()["data"]
    assert isinstance(data, list)
    assert len(data) >= 1
    assert data[0]["read"] is False


@pytest.mark.asyncio
async def test_get_sent(client: AsyncClient, user_a, user_b):
    token_a = create_access_token(str(user_a.id), ["docente"])
    await client.post(
        "/api/v1/messages/",
        json={"content": "Enviado", "type": "directo", "recipient_ids": [str(user_b.id)]},
        headers={"Authorization": f"Bearer {token_a}"},
    )
    response = await client.get(
        "/api/v1/messages/sent",
        headers={"Authorization": f"Bearer {token_a}"},
    )
    assert response.status_code == 200
    assert isinstance(response.json()["data"], list)
    assert len(response.json()["data"]) >= 1


@pytest.mark.asyncio
async def test_mark_message_as_read(client: AsyncClient, user_a, user_b):
    token_a = create_access_token(str(user_a.id), ["docente"])
    token_b = create_access_token(str(user_b.id), ["docente"])
    send_resp = await client.post(
        "/api/v1/messages/",
        json={"content": "Léeme", "type": "directo", "recipient_ids": [str(user_b.id)]},
        headers={"Authorization": f"Bearer {token_a}"},
    )
    msg_id = send_resp.json()["data"]["id"]
    response = await client.post(
        f"/api/v1/messages/{msg_id}/read",
        headers={"Authorization": f"Bearer {token_b}"},
    )
    assert response.status_code == 200
    assert response.json()["data"]["read"] is True


@pytest.mark.asyncio
async def test_send_without_auth_returns_403(client: AsyncClient, user_b):
    response = await client.post(
        "/api/v1/messages/",
        json={"content": "No auth", "type": "directo", "recipient_ids": [str(user_b.id)]},
    )
    assert response.status_code == 403
