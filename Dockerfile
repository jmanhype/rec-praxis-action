FROM python:3.11-slim

LABEL maintainer="jmanhype"
LABEL org.opencontainers.image.source="https://github.com/jmanhype/rec-praxis-action"
LABEL org.opencontainers.image.description="Automated code review, security audit, and dependency scanning"

# Install git (required for changed files detection)
RUN apt-get update && \
    apt-get install -y --no-install-recommends git && \
    rm -rf /var/lib/apt/lists/*

# Install rec-praxis-rlm with all optional dependencies
RUN pip install --no-cache-dir rec-praxis-rlm[all]==0.4.2

# Copy entrypoint script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
