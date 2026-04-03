# backend/core/storage.py
import asyncio
import io

from minio import Minio

from core.config import settings


def _get_client() -> Minio:
    return Minio(
        settings.minio_endpoint,
        access_key=settings.minio_root_user,
        secret_key=settings.minio_root_password,
        secure=False,
    )


def _sync_upload(bucket: str, key: str, data: bytes, content_type: str) -> str:
    client = _get_client()
    if not client.bucket_exists(bucket):
        client.make_bucket(bucket)
    client.put_object(
        bucket, key, io.BytesIO(data), length=len(data), content_type=content_type
    )
    return f"http://{settings.minio_endpoint}/{bucket}/{key}"


async def upload_file(
    bucket: str, key: str, data: bytes, content_type: str = "application/octet-stream"
) -> str:
    """Upload bytes to MinIO. Returns the object URL."""
    return await asyncio.to_thread(_sync_upload, bucket, key, data, content_type)
