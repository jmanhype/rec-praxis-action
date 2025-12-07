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
    pip install --no-cache-dir rec-praxis-rlm[all]==0.4.3

# Stage 2: Runtime image (minimal)
FROM python:3.11-slim

LABEL maintainer="jmanhype"
LABEL org.opencontainers.image.source="https://github.com/jmanhype/rec-praxis-action"
LABEL org.opencontainers.image.description="Automated code review, security audit, and dependency scanning"
LABEL org.opencontainers.image.version="1.1.0"

# Install only runtime dependencies (git for incremental scanning)
RUN apt-get update && \
    apt-get install -y --no-install-recommends git && \
    rm -rf /var/lib/apt/lists/* && \
    apt-get clean

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

# Non-root user for security
RUN useradd -m -u 1000 scanner && \
    chown -R scanner:scanner /github/workspace
USER scanner

ENTRYPOINT ["/entrypoint.sh"]
