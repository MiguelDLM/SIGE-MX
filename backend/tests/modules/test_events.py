import uuid
import pytest
import pytest_asyncio
from httpx import AsyncClient
import sqlalchemy

from core.security import create_access_token, hash_password
from modules.users.models import Role, User, UserRole, UserStatus


@pytest_asyncio.fixture
async def admin_token(db_session):
    result = await db_session.execute(sqlalchemy.select(Role).where(Role.name == "directivo"))
    role = result.scalar_one_or_none()
    if not role:
        role = Role(name="directivo")
        db_session.add(role)
        await db_session.flush()
    result = await db_session.execute(sqlalchemy.select(User).where(User.email == "dir_events@test.com"))
    user = result.scalar_one_or_none()
    if not user:
        user = User(
            email="dir_events@test.com",
            password_hash=hash_password("pass"),
            nombre="Directivo",
            status=UserStatus.activo,
        )
        db_session.add(user)
        await db_session.flush()
        db_session.add(UserRole(user_id=user.id, role_id=role.id))
        await db_session.commit()
        await db_session.refresh(user)
    return create_access_token(str(user.id), ["directivo"])


@pytest_asyncio.fixture
async def docente_token(db_session):
    result = await db_session.execute(sqlalchemy.select(Role).where(Role.name == "docente"))
    role = result.scalar_one_or_none()
    if not role:
        role = Role(name="docente")
        db_session.add(role)
        await db_session.flush()
    result = await db_session.execute(sqlalchemy.select(User).where(User.email == "doc_events@test.com"))
    user = result.scalar_one_or_none()
    if not user:
        user = User(
            email="doc_events@test.com",
            password_hash=hash_password("pass"),
            nombre="Docente",
            status=UserStatus.activo,
        )
        db_session.add(user)
        await db_session.flush()
        db_session.add(UserRole(user_id=user.id, role_id=role.id))
        await db_session.commit()
        await db_session.refresh(user)
    return create_access_token(str(user.id), ["docente"])


@pytest.mark.asyncio
async def test_create_event(client: AsyncClient, admin_token):
    response = await client.post(
        "/api/v1/events/",
        json={
            "titulo": "Día del Maestro",
            "tipo": "cultural",
            "fecha_inicio": "2024-05-15T09:00:00",
        },
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 201
    data = response.json()["data"]
    assert data["titulo"] == "Día del Maestro"
    assert data["tipo"] == "cultural"


@pytest.mark.asyncio
async def test_list_events(client: AsyncClient, admin_token, docente_token):
    await client.post(
        "/api/v1/events/",
        json={"titulo": "Examen Final", "tipo": "academico", "fecha_inicio": "2024-11-20T08:00:00"},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    response = await client.get(
        "/api/v1/events/",
        headers={"Authorization": f"Bearer {docente_token}"},
    )
    assert response.status_code == 200
    assert isinstance(response.json()["data"], list)
    assert len(response.json()["data"]) >= 1


@pytest.mark.asyncio
async def test_update_event(client: AsyncClient, admin_token):
    create_resp = await client.post(
        "/api/v1/events/",
        json={"titulo": "Evento Original", "tipo": "deportivo", "fecha_inicio": "2024-06-01T10:00:00"},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    event_id = create_resp.json()["data"]["id"]
    response = await client.patch(
        f"/api/v1/events/{event_id}",
        json={"titulo": "Evento Actualizado"},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 200
    assert response.json()["data"]["titulo"] == "Evento Actualizado"


@pytest.mark.asyncio
async def test_delete_event(client: AsyncClient, admin_token):
    create_resp = await client.post(
        "/api/v1/events/",
        json={"titulo": "Evento a Borrar", "tipo": "administrativo", "fecha_inicio": "2024-07-01T10:00:00"},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    event_id = create_resp.json()["data"]["id"]
    response = await client.delete(
        f"/api/v1/events/{event_id}",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 204


@pytest.mark.asyncio
async def test_add_participants(client: AsyncClient, admin_token, docente_token):
    create_resp = await client.post(
        "/api/v1/events/",
        json={"titulo": "Evento Participantes", "tipo": "cultural", "fecha_inicio": "2024-08-10T09:00:00"},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    event_id = create_resp.json()["data"]["id"]

    import jwt
    import os
    payload = jwt.decode(docente_token, os.environ["JWT_SECRET_KEY"], algorithms=["HS256"])
    docente_user_id = payload["sub"]

    response = await client.post(
        f"/api/v1/events/{event_id}/participants",
        json={"user_ids": [docente_user_id]},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 201


@pytest.mark.asyncio
async def test_create_event_without_admin_role_returns_403(client: AsyncClient, docente_token):
    response = await client.post(
        "/api/v1/events/",
        json={"titulo": "No permitido", "tipo": "cultural", "fecha_inicio": "2024-09-01T09:00:00"},
        headers={"Authorization": f"Bearer {docente_token}"},
    )
    assert response.status_code == 403


@pytest.mark.asyncio
async def test_update_unknown_event_returns_404(client: AsyncClient, admin_token):
    response = await client.patch(
        f"/api/v1/events/{uuid.uuid4()}",
        json={"titulo": "No existe"},
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert response.status_code == 404
