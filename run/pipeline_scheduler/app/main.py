from typing import Union

from fastapi import FastAPI
from pydantic import BaseModel


class Job(BaseModel):
    url: str
    gcs_pipeline: str

app = FastAPI()

@app.get("/")
def read_root():
    return {"Hello": "World"}

@app.post('/')
async def run_job(job: Job):
    return job


@app.get("/items/{item_id}")
def read_item(item_id: int, q: Union[str, None] = None):
    return {"item_id": item_id, "q": q}

