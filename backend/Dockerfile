FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

RUN addgroup --system appgroup \
    && adduser --system --ingroup appgroup appuser

COPY requirements.txt ./
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt

COPY . .

RUN chown -R appuser:appgroup /app && chmod +x /app/entrypoint.sh \
    && sed -i 's/\r//' /app/entrypoint.sh

USER appuser

EXPOSE 8080

CMD ["/bin/sh", "/app/entrypoint.sh"]