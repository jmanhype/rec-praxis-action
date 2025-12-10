# syntax=docker/dockerfile:1

# Stage 1: Build dependencies (cached layer)
FROM python:3.11-slim AS builder

# Install build dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        gcc \
        g++ \
        git \
    && rm -rf /var/lib/apt/lists/*

# Create virtual environment for better caching
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Copy only requirements first (better layer caching)
# This layer is cached unless rec-praxis-rlm version changes
RUN pip install --no-cache-dir --upgrade pip setuptools wheel && \
    pip install --no-cache-dir rec-praxis-rlm[all]==0.9.2

# Stage 2: Runtime image (minimal)
FROM python:3.11-slim

LABEL maintainer="jmanhype"
LABEL org.opencontainers.image.source="https://github.com/jmanhype/rec-praxis-action"
LABEL org.opencontainers.image.description="Automated code review, security audit, and dependency scanning"
LABEL org.opencontainers.image.version="1.2.0"

# Install runtime dependencies (git + Node.js for JS/TS scanning)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        git \
        curl \
        ca-certificates \
    && curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && npm install -g eslint typescript npm-audit-resolver \
    && rm -rf /var/lib/apt/lists/* \
    && apt-get clean

# Copy virtual environment from builder
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Set working directory
WORKDIR /github/workspace

# Copy entrypoint script (separate layer for quick iterations)
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Create memory directory with proper permissions
RUN mkdir -p /.rec-praxis-rlm && chmod 777 /.rec-praxis-rlm

# Note: GitHub Actions Docker containers run as root by default
# The workspace is mounted at runtime with appropriate permissions

ENTRYPOINT ["/entrypoint.sh"]
