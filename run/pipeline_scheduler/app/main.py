from typing import Union

from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

from google import auth
from google.auth.transport import urllib3
from google.cloud import storage


class Job(BaseModel):
    url: str
    gcs_bucket: str
    gcs_pipeline: str

app = FastAPI()

@app.get("/")
def read_root():
    return {"Hello": "World"}

@app.post('/')
async def run_job(job: Job):
    storage_client = storage.Client()
    bucket = storage_client.bucket(job.gcs_bucket)
    blob = bucket.blob(job.gcs_pipeline)

    pipeline_job_description = blob.download_as_string()

    credentials, _ = auth.default()
    authorized_http = urllib3.AuthorizedHttp(credentials=credentials)
    response = authorized_http.request(
        url=job.url,
        method='POST',
        body=pipeline_job_description,
    )

    if response.status != 200:
        raise HTTPException(
            status_code=response.status,
            detail=response.data)

    return response.data

@app.get("/items/{item_id}")
def read_item(item_id: int, q: Union[str, None] = None):
    return {"item_id": item_id, "q": q}

