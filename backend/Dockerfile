FROM python:3.12-slim

WORKDIR /app

RUN addgroup --system app && adduser --system --ingroup app app

COPY requirements.txt requirements-dev.txt ./
RUN pip install --no-cache-dir -r requirements-dev.txt

COPY . .

RUN chown -R app:app /app
USER app

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
