# Use Ruby 3.2 alpine image for smaller size
FROM ruby:3.2-alpine

# Install system dependencies
RUN apk add --no-cache \
    build-base \
    git \
    ca-certificates \
    tzdata

# Set working directory
WORKDIR /app

# Copy Gemfile and Gemfile.lock
COPY Gemfile* ./

# Install Ruby dependencies
RUN bundle config set --local deployment 'true' && \
    bundle config set --local without 'development test' && \
    bundle install

# Copy application code
COPY . .

# Create user_tokens directory
RUN mkdir -p user_tokens

# Make the binary executable
RUN chmod +x bin/calendar-color-mcp

# Set environment
ENV RACK_ENV=production
ENV BUNDLE_DEPLOYMENT=true
ENV BUNDLE_WITHOUT=development:test

# Expose port (if needed for health checks)
EXPOSE 3000

# Create non-root user for security
RUN addgroup -g 1000 app && \
    adduser -D -s /bin/sh -u 1000 -G app app && \
    chown -R app:app /app

USER app

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD pgrep -f calendar-color-mcp || exit 1

# Default command
CMD ["./bin/calendar-color-mcp"]