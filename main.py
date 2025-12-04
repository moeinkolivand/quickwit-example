import asyncio
import json
import time
import uuid
from contextlib import asynccontextmanager

from aiokafka import AIOKafkaProducer
from fastapi import FastAPI, APIRouter, Request
from faststream.kafka.fastapi import KafkaRouter
import os
from aiokafka.admin import NewTopic, AIOKafkaAdminClient
from aiokafka.errors import TopicAlreadyExistsError, KafkaConnectionError

bootstrap_raw = os.getenv("KAFKA_BOOTSTRAP", "kafka1:19092")
bootstrap_servers = [server.strip() for server in bootstrap_raw.split(",")]



api_router = APIRouter()
kafka_router = KafkaRouter(bootstrap_servers)

async def wait_for_kafka(max_retries: int = 30, retry_interval: float = 5.0) -> None:
    """Wait for Kafka cluster to be ready."""
    print(f"Waiting for Kafka at {bootstrap_servers}...")
    for attempt in range(max_retries):
        try:
            producer = AIOKafkaProducer(bootstrap_servers=bootstrap_servers)
            await producer.start()
            await producer.stop()
            print("Kafka is ready!")
            return
        except KafkaConnectionError:
            print(f"Attempt {attempt + 1}/{max_retries}: Kafka not ready, retrying in {retry_interval}s...")
            await asyncio.sleep(retry_interval)
    raise TimeoutError("Kafka cluster failed to become ready within timeout.")

async def create_kafka_topics():
    """Create Kafka topics if they don't exist."""
    try:
        admin_client = AIOKafkaAdminClient(bootstrap_servers=bootstrap_servers)
        await admin_client.start()
        topics = [
            NewTopic(name="api-logs", num_partitions=3, replication_factor=3),
            NewTopic(name="test-topic", num_partitions=3, replication_factor=3),
        ]
        await admin_client.create_topics(new_topics=topics, validate_only=False)
        print("Kafka topics created successfully.")
    except TopicAlreadyExistsError:
        print("Topics already exist.")
    except Exception as e:
        print(f"Failed to create topics: {e}")
    finally:
        await admin_client.close()

@asynccontextmanager
async def lifespan(app: FastAPI):
    await wait_for_kafka()
    await create_kafka_topics()
    await asyncio.sleep(3)
    yield


app = FastAPI(lifespan=lifespan)

@kafka_router.subscriber("test-topic")
async def consume(msg: str):
    print("Received:", msg)


@api_router.get("/")
async def root():
    return {"message": "Hello World"}

@api_router.get("/hello/{name}")
async def say_hello(name: str):
    return {"message": f"Hello {name}"}


@api_router.post("/log-test")
async def log_test(request: Request):
    start_time = time.time()

    # Simulate some processing
    await asyncio.sleep(0.05)

    log_entry = {
        "timestamp": time.time(),  # Quickwit will auto-convert to datetime
        "method": request.method,
        "path": request.url.path,
        "client_ip": request.client.host,
        "status_code": 200,
        "latency_ms": round((time.time() - start_time) * 1000, 2),
        "request_id": str(uuid.uuid4()),
        "request_body": "this is a test request body",
        "response_body": json.dumps({"message": "logged!"})
    }

    await kafka_router.broker.publish(
        json.dumps(log_entry, separators=(',', ':')),
        topic="api-logs"
    )

    return {"status": "logged", "request_id": log_entry["request_id"]}

app.include_router(api_router)
app.include_router(kafka_router)
