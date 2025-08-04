# Use a smaller base image
FROM python:3.10-slim

# Set working directory inside container
WORKDIR /app

# Copy only the requirements.txt first to leverage Docker cache
COPY requirements.txt .

# Install the required dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Now copy the rest of the application code
COPY . .

# Expose port 80 (update if your app uses a different port)
EXPOSE 80

# Define the command to run the application
CMD ["python", "app.py"]

