# Use Python 3.11 slim as base image
FROM python:3.11-slim

# Install Poetry
RUN pip install poetry

# Set working directory
WORKDIR /app

# Set environment variables
ENV PYTHONFAULTHANDLER=1 \
    PYTHONUNBUFFERED=1 \
    PYTHONHASHSEED=random \
    PIP_NO_CACHE_DIR=off \
    PIP_DISABLE_PIP_VERSION_CHECK=on \
    PYTHONDONTWRITEBYTECODE=1

# Install AWS CLI
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl \
    unzip \
    && curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm -rf awscliv2.zip aws \
    && apt-get purge -y --auto-remove curl unzip \
    && rm -rf /var/lib/apt/lists/*

# Copy the poetry project file
COPY pyproject.toml .

# Install dependencies without dev dependencies and without installing the current project itself
RUN poetry install --without dev --no-root

# Copy the application code (adjust path if necessary)
COPY src/country_extraction.py .

# Set the default command to run the app using Poetry
CMD ["poetry", "run", "python", "country_extraction.py"]
