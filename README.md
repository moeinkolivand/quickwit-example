# Quickwit Log Analytics with FastAPI, FastStream & Kafka

A comprehensive example demonstrating real-time log ingestion and analytics using Quickwit, FastAPI, FastStream, and Apache Kafka. This project showcases a production-ready architecture for distributed logging with a 3-node Kafka cluster and Quickwit as the search and analytics engine.

## 📖 Overview

This project implements a modern logging pipeline that:
- Captures API request logs from a FastAPI application
- Uses FastStream for elegant Kafka integration with async/await support
- Streams logs through a highly available Kafka cluster (3 brokers)
- Indexes logs in Quickwit for fast full-text search and analytics
- Provides real-time monitoring capabilities

**Read the full guide**: [Quickwit: A Comprehensive Guide](https://medium.com/@moeinkolivand97/quickwit-a-comprehensive-guide-84cfd775e790)

## 🏗️ Architecture

```
FastAPI Application
       ↓
   Kafka Cluster (3 nodes)
       ↓
    Quickwit
       ↓
   Search & Analytics
```

### Components

- **FastAPI**: High-performance Python web framework serving the API
- **FastStream**: Modern Python framework for building async services with Kafka integration
- **Kafka Cluster**: 3-node KRaft cluster for reliable message streaming
- **Quickwit**: Fast search and analytics engine for log data
- **Kafka UI**: Web interface for monitoring Kafka topics and messages

## 🚀 Quick Start

### Prerequisites

- Docker and Docker Compose
- Python 3.11+ (for local development)
- 8GB+ RAM recommended for running the full stack

### Running the Stack

1. **Clone the repository**
   ```bash
   git clone https://github.com/moeinkolivand/quickwit-example
   cd quickwit-example
   ```

2. **Start all services**
   ```bash
   docker-compose up -d
   ```

3. **Wait for initialization** (30-60 seconds)
   
   The `quickwit-init` service will automatically:
   - Wait for Kafka and Quickwit to be ready
   - Create the `api-logs` index
   - Configure the Kafka source for log ingestion

4. **Verify services are running**
   ```bash
   docker-compose ps
   ```

## 📡 Endpoints & Services

| Service | URL | Description |
|---------|-----|-------------|
| FastAPI | http://localhost:8000 | Main API application |
| FastAPI Docs | http://localhost:8000/docs | Interactive API documentation |
| Quickwit UI | http://localhost:7280 | Search and analytics interface |
| Kafka UI | http://localhost:8080 | Kafka cluster monitoring |

### API Endpoints

- `GET /` - Health check endpoint
- `GET /hello/{name}` - Simple greeting endpoint
- `POST /log-test` - Test endpoint that generates and logs a sample entry

## 🔍 Testing the Pipeline

### 1. Generate Test Logs

```bash
# Send a test log entry
curl -X POST http://localhost:8000/log-test

# Generate multiple logs
for i in {1..10}; do
  curl -X POST http://localhost:8000/log-test
  sleep 1
done
```

### 2. Search Logs in Quickwit

Access the Quickwit UI at http://localhost:7280 and try these queries:

**Basic Search:**
```
*
```

**Search by status code:**
```
status_code:200
```

**Search by HTTP method:**
```
method:POST
```

**Search by path:**
```
path:/log-test
```

**Search by IP address:**
```
client_ip:172.18.0.1
```

**Full-text search in request/response:**
```
request_body:test OR response_body:logged
```

**Time range queries:**
```
timestamp:[2024-01-01T00:00:00Z TO 2024-12-31T23:59:59Z]
```

**Complex queries:**
```
method:POST AND status_code:200 AND path:/log-test
```

**Using the REST API:**
```bash
# Search all logs
curl "http://localhost:7280/api/v1/api-logs/search?query=*"

# Filter by status code
curl "http://localhost:7280/api/v1/api-logs/search?query=status_code:200"

# Aggregate queries (via JSON)
curl -X POST "http://localhost:7280/api/v1/api-logs/search" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "*",
    "max_hits": 10,
    "aggs": {
      "avg_latency": {
        "avg": {
          "field": "latency_ms"
        }
      }
    }
  }'
```

### 3. Monitor Kafka

Visit http://localhost:8080 to:
- View the `api-logs` topic
- Monitor message throughput
- Inspect individual messages
- Check consumer group status

## 📊 Log Schema

Each log entry contains:

```json
{
  "timestamp": 1234567890.123,
  "method": "POST",
  "path": "/log-test",
  "client_ip": "172.18.0.1",
  "status_code": 200,
  "latency_ms": 52.43,
  "request_id": "550e8400-e29b-41d4-a716-446655440000",
  "request_body": "...",
  "response_body": "..."
}
```

## 🔧 Configuration

### FastStream & Kafka Integration

FastStream provides a declarative way to work with Kafka in FastAPI applications:

```python
from faststream.kafka.fastapi import KafkaRouter

# Initialize KafkaRouter with broker addresses
kafka_router = KafkaRouter(bootstrap_servers)

# Subscribe to topics with decorators
@kafka_router.subscriber("test-topic")
async def consume(msg: str):
    print("Received:", msg)

# Publish messages easily
await kafka_router.broker.publish(
    json.dumps(log_entry),
    topic="api-logs"
)
```

**Benefits of FastStream:**
- ✅ Seamless FastAPI integration
- ✅ Async/await native support
- ✅ Automatic message serialization/deserialization
- ✅ Type hints and Pydantic models support
- ✅ Declarative subscriber/publisher patterns
- ✅ Built-in connection management and retry logic

### Kafka Configuration

The project uses a 3-node KRaft cluster with:
- **Replication Factor**: 3
- **Min In-Sync Replicas**: 2
- **Partitions**: 3 per topic

Modify in `docker-compose.yml` for different setups.

### Quickwit Index Configuration

Index settings are defined in `deployments/quickwit/indexes/webservice/index.json`.

#### Understanding the Index Configuration

**Top-Level Settings:**
- **`version: "0.7"`** - Quickwit configuration schema version
- **`index_id: "api-logs"`** - Unique identifier for this index

**Field Mappings Explained:**

| Field | Type | Settings | Purpose |
|-------|------|----------|---------|
| `timestamp` | `datetime` | `fast: true`, `stored: true` | Time-based filtering, sorting, and aggregations |
| `method` | `text` | `tokenizer: "raw"` | Exact HTTP method matching (GET, POST, etc.) |
| `path` | `text` | `tokenizer: "raw"` | Exact URL path matching |
| `client_ip` | `text` | `tokenizer: "raw"` | Exact IP address matching |
| `status_code` | `i64` | Integer | Numeric filtering and aggregations |
| `latency_ms` | `f64` | Float | Precise latency measurements |
| `request_id` | `text` | `tokenizer: "raw"` | Exact UUID matching |
| `request_body` | `text` | Default tokenizer | Full-text search in request content |
| `response_body` | `text` | Default tokenizer | Full-text search in response content |

**Key Concepts:**

- **`fast: true`**: Enables columnar storage for fast filtering, sorting, and aggregations (essential for time-series data)
- **`stored: true`**: Original value is returned in search results
- **`tokenizer: "raw"`**: Treats entire value as single token for exact matching (no word splitting)
  - Example: `"POST"` remains `"POST"`, not split into letters
  - Perfect for structured data like HTTP methods, paths, IPs, UUIDs
- **Default tokenizer**: Splits text into words for full-text search (used for request/response bodies)

**Indexing Settings:**

```json
"commit_timeout_secs": 5
```
- Quickwit commits data to disk every 5 seconds
- Lower value = more real-time visibility
- Higher value = better indexing performance

```json
"split_num_docs_target": 100000
```
- Documents are organized into "splits" (like shards)
- Each split targets ~100,000 documents
- Balances query performance with storage efficiency

**Search Settings:**

```json
"default_search_fields": ["path", "method", "request_body", "response_body"]
```
- When searching without specifying a field, these are searched by default
- Query `"error"` searches across all four fields
- Explicit field queries like `request_body:error` search only that field

**Performance Tips:**

✅ **Selective `fast` fields** - Only `timestamp` has `fast: true` to reduce memory usage  
✅ **Raw tokenizers** - Used for structured data to minimize index size  
✅ **Full-text where needed** - Only request/response bodies use word tokenization  
✅ **Reasonable split size** - 100k documents balances speed and storage

### Kafka Source Configuration

Kafka source settings in `deployments/quickwit/kafka-source.yaml`:
- **Pipelines**: 2 concurrent indexing pipelines
- **Consumer Group**: quickwit-indexer
- **Auto Offset Reset**: earliest (process all messages)

## 🛠️ Development

### Local Development Setup

1. **Create virtual environment**
   ```bash
   python -m venv .venv
   source .venv/bin/activate  # On Windows: .venv\Scripts\activate
   ```

2. **Install dependencies**
   ```bash
   pip install -r requirements.txt
   ```

3. **Run FastAPI locally** (with Docker services)
   ```bash
   # Start only Kafka and Quickwit
   docker-compose up -d kafka1 kafka2 kafka3 quickwit quickwit-init
   
   # Run FastAPI locally
   uvicorn main:app --reload --host 0.0.0.0 --port 8000
   ```

### Adding Custom Endpoints

1. Define your endpoint in `main.py` using FastStream for Kafka publishing:
   ```python
   @api_router.get("/your-endpoint")
   async def your_endpoint(request: Request):
       start_time = time.time()
       
       # Your business logic here
       result = {"status": "success"}
       
       # Log to Kafka using FastStream
       log_entry = {
           "timestamp": time.time(),
           "method": request.method,
           "path": request.url.path,
           "client_ip": request.client.host,
           "status_code": 200,
           "latency_ms": round((time.time() - start_time) * 1000, 2),
           "request_id": str(uuid.uuid4()),
           "request_body": "your request data",
           "response_body": json.dumps(result)
       }
       
       # Publish to Kafka topic
       await kafka_router.broker.publish(
           json.dumps(log_entry, separators=(',', ':')),
           topic="api-logs"
       )
       
       return result
   ```

2. **Add Kafka consumers** for processing messages:
   ```python
   @kafka_router.subscriber("your-topic")
   async def process_message(msg: dict):
       # Process incoming Kafka messages
       print(f"Processing: {msg}")
       
       # Can also publish to another topic
       await kafka_router.broker.publish(
           json.dumps({"processed": True}),
           topic="processed-topic"
       )
   ```

## 📦 Project Structure

```
.
├── main.py                           # FastAPI application
├── requirements.txt                   # Python dependencies
├── Dockerfile                         # FastAPI container image
├── docker-compose.yml                 # Complete stack orchestration
├── deployments/
│   └── quickwit/
│       ├── init-quickwit.sh          # Initialization script
│       ├── kafka-source.yaml         # Kafka source configuration
│       └── indexes/
│           └── webservice/
│               └── index.json        # Index schema definition
└── README.md
```

## 🔍 Troubleshooting

### Services Not Starting

```bash
# Check service logs
docker-compose logs quickwit
docker-compose logs kafka1
docker-compose logs fastapi

# Restart services
docker-compose restart
```

### Logs Not Appearing in Quickwit

1. **Check Kafka topic has messages**:
   - Visit http://localhost:8080
   - Navigate to Topics → api-logs
   - Verify messages are being produced

2. **Verify Quickwit source is running**:
   ```bash
   curl http://localhost:7280/api/v1/indexes/api-logs/sources
   ```

3. **Check Quickwit logs**:
   ```bash
   docker-compose logs quickwit
   ```

### Reset Everything

```bash
# Stop and remove all containers, volumes, and networks
docker-compose down -v

# Start fresh
docker-compose up -d
```

## 📈 Performance Tuning

### For High Throughput

1. **Increase Kafka partitions**:
   ```python
   NewTopic(name="api-logs", num_partitions=6, replication_factor=3)
   ```

2. **Add more Quickwit pipelines**:
   ```yaml
   num_pipelines: 4  # in kafka-source.yaml
   ```

3. **Adjust Kafka fetch settings**:
   ```yaml
   fetch.message.max.bytes: 2000000
   fetch.min.bytes: 10000
   ```

### For Low Latency

The current configuration is optimized for low latency with:
- `fetch.wait.max.ms: 10` - Fast polling
- `fetch.min.bytes: 1` - No wait for batching
- `commit_timeout_secs: 5` - Quick commits

## 🧪 Testing

Run the test suite:

```bash
# Generate load
for i in {1..100}; do
  curl -X POST http://localhost:8000/log-test &
done
wait

# Check Quickwit received all logs
curl -s "http://localhost:7280/api/v1/api-logs/search?query=*" | jq '.num_hits'
```

## 🤝 Contributing

Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Open a Pull Request


## 🙏 Acknowledgments

- [Quickwit](https://quickwit.io/) - Fast and cost-efficient search engine
- [FastAPI](https://fastapi.tiangolo.com/) - Modern Python web framework
- [FastStream](https://faststream.airt.ai/) - Powerful framework for building async services with Kafka
- [Apache Kafka](https://kafka.apache.org/) - Distributed streaming platform

## 📚 Additional Resources

- [Quickwit Documentation](https://quickwit.io/docs)
- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [FastStream Documentation](https://faststream.airt.ai/)
- [Kafka Documentation](https://kafka.apache.org/documentation/)
- [Medium Article: Quickwit Comprehensive Guide](https://medium.com/@moeinkolivand97/quickwit-a-comprehensive-guide-84cfd775e790)

