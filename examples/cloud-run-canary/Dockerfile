FROM python:3.12-slim

WORKDIR /app
COPY app.py .

ENV PORT=8080
EXPOSE 8080

# No pip install: the demo is stdlib-only on purpose.
USER 65532:65532
CMD ["python", "app.py"]
