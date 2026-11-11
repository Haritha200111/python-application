
from fastapi import FastAPI

app = FastAPI(
    title="Python CI/CD Demo APIs.",
    description="A small FastAPI application deployed through Jenkins.",
    version="1.0.0",
)


@app.get("/")
def read_root():
    print("Root endpoint accessed")
    return {"message": "Hello from the Python API!", "status": "running"}


@app.get("/health")
def health_check():
    print("Health endpoint accessed")
    return {"status": "healthy"}
