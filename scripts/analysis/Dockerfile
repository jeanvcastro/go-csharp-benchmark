FROM python:3.11-slim

# Set environment variables for unbuffered output
ENV PYTHONUNBUFFERED=1
ENV PYTHONIOENCODING=utf-8

WORKDIR /app

# Copy requirements first for better caching
COPY requirements.txt /app/

# Install required Python packages
RUN pip install --no-cache-dir -r requirements.txt

# Copy the analysis script
COPY analyze-results.py /app/

# Create volume mount points
VOLUME ["/results", "/reports"]

# Set the entrypoint
ENTRYPOINT ["python3", "-u", "analyze-results.py"]
CMD ["/results"]