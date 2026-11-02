FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
RUN apt-get update \
 && apt-get install -y --no-install-recommends gcc pkg-config default-libmysqlclient-dev \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
# las pruebas leen los diccionarios de db/
COPY --from=db . /db

EXPOSE 8000
# migrate solo crea las tablas internas de Django
CMD ["sh", "-c", "python manage.py migrate --noinput && (python manage.py createsuperuser --noinput || true) && python manage.py runserver 0.0.0.0:8000"]
