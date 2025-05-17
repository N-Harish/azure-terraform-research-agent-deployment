# Build stage
FROM python:3.11.12-alpine3.21 AS builder
WORKDIR /build

# Install build dependencies
RUN set -xe \
    && apk update \
    && apk add --no-cache build-base cmake apache-arrow-dev \
    && pip install --upgrade pip \
    && rm -rf /var/cache/apk/*

# Copy and install requirements
COPY requirements.txt ./
RUN pip install --no-cache-dir --prefer-binary pyarrow \
    && pip install --no-cache-dir -r requirements.txt

# Runtime stage
FROM python:3.11.12-alpine3.21
WORKDIR /app

# Install only runtime dependencies
RUN set -xe \
    && apk update \
    && apk add --no-cache apache-arrow-dev \
    && rm -rf /var/cache/apk/*

# Copy installed packages from builder
COPY --from=builder /usr/local/lib/python3.11/site-packages/ /usr/local/lib/python3.11/site-packages/
COPY --from=builder /usr/local/bin/ /usr/local/bin/

# Copy application code
COPY langchain_deep_research.py app.py ./
ARG GROQ_API_KEY
ENV GROQ_API_KEY=${GROQ_API_KEY}
ARG TAVILY_API_KEY
ENV TAVILY_API_KEY=${TAVILY_API_KEY}
EXPOSE 8051
CMD ["streamlit", "run", "app.py", "--server.port=8051", "--server.address=0.0.0.0"]
