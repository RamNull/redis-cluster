# Redis Cluster Test Application

This TypeScript Node.js application tests the Redis cluster setup defined in the docker-compose.yml file.

## Prerequisites

- Docker and Docker Compose
- Node.js (v18 or higher)
- npm

## Setup

1. **Start the Redis cluster:**
   ```powershell
   docker-compose up -d
   ```

2. **Install dependencies:**
   ```powershell
   npm install
   ```

3. **Build the TypeScript application:**
   ```powershell
   npm run build
   ```

## Running the Application

### Development mode (with ts-node):
```powershell
npm run dev
```

### Production mode:
```powershell
npm start
```

### Quick test:
```powershell
npm test
```

## What the Application Tests

The application performs comprehensive testing of your Redis cluster:

### 🧪 Basic Operations
- **SET/GET**: Basic key-value operations
- **INCR**: Increment operations for counters
- **HSET/HGET**: Hash operations
- **LPUSH/LRANGE**: List operations
- **SADD/SMEMBERS**: Set operations

### 🔍 Cluster Information
- **CLUSTER INFO**: Displays cluster status and statistics
- **CLUSTER NODES**: Shows all nodes in the cluster

### ⚡ Performance Testing
- Executes 1000 concurrent SET operations
- Measures operations per second
- Tests cluster performance under load

### 🧹 Cleanup
- Removes all test data after completion
- Ensures clean state for subsequent runs

## Expected Output

When the Redis cluster is running correctly, you should see output similar to:

```
🔴 Redis Cluster Test Application
==================================
✅ Connected to Redis cluster
🚀 Redis client connected successfully

🧪 Testing basic Redis operations...
✅ SET operation successful
✅ GET operation successful: Hello Redis Cluster!
✅ INCR operation successful: 1
✅ HSET operation successful
✅ HGET operation successful: Redis Cluster
✅ LPUSH operation successful
✅ LRANGE operation successful: item3, item2, item1
✅ SADD operation successful
✅ SMEMBERS operation successful: member1, member2, member3

🔍 Testing cluster information...
📊 Cluster Info:
cluster_state:ok
cluster_slots_assigned:16384
...

⚡ Testing performance...
✅ Performance test completed:
   - Operations: 1000
   - Duration: 245ms
   - Operations/second: 4081

🧹 Cleaning up test data...
✅ Deleted X test keys
✅ Deleted 1000 performance test keys

🎉 All tests completed successfully!
👋 Disconnected from Redis
```

## Troubleshooting

### Connection Issues
- Ensure Redis cluster is running: `docker-compose ps`
- Check if port 7000 is accessible: `netstat -an | findstr 7000`
- Verify Redis container logs: `docker-compose logs redis`

### Cluster Issues
- Check cluster status: `docker exec redis-cluster-single redis-cli -p 7000 cluster info`
- Verify cluster nodes: `docker exec redis-cluster-single redis-cli -p 7000 cluster nodes`

### Application Issues
- Check TypeScript compilation: `npm run build`
- Verify dependencies: `npm list`
- Run in development mode for detailed logs: `npm run dev`

## Configuration

The application connects to:
- **Host**: localhost
- **Port**: 7000 (as defined in docker-compose.yml)

To modify the connection settings, edit the `createClient` configuration in `src/index.ts`.

## Redis Cluster Configuration

The cluster is configured with:
- **Port**: 7000
- **Cluster enabled**: Yes
- **Node timeout**: 5000ms
- **Append-only file**: Yes

Configuration details are in `redis-cluster.conf`.
