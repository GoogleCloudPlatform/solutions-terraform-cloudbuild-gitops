import uvicorn
import tensorflow as tf
from fastapi import Request, FastAPI
from fastapi.responses import JSONResponse

app = FastAPI(title="Sentiment Analysis")

model = tf.keras.models.load_model('../model')

@app.post('/')
async def predict(request: Request):
    body = await request.json()
    result = model(tf.constant(body))
    return result.numpy().tolist()

if __name__ == "__main__":
    uvicorn.run(app, debug=True)

