from fastapi import FastAPI, APIRouter
from faststream.kafka.fastapi import KafkaRouter
import os

bootstrap_raw = os.getenv("KAFKA_BOOTSTRAP", "kafka1:19092")
bootstrap_servers = bootstrap_raw.split(",")

app = FastAPI()
api_router = APIRouter()

kafka_router = KafkaRouter(bootstrap_servers)

@kafka_router.subscriber("test-topic")
async def consume(msg: str):
    print("Received:", msg)


@api_router.get("/")
async def root():
    await kafka_router.broker.publish("Hello from FastAPI Kafka!", topic="test-topic")
    return {"message": "Hello World"}

@api_router.get("/hello/{name}")
async def say_hello(name: str):
    return {"message": f"Hello {name}"}

app.include_router(api_router)
app.include_router(kafka_router)
