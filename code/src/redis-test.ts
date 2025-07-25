import { createCluster } from 'redis';

async function testRedisCluster() {
    console.log('🔴 Redis Cluster Connection Test');
    console.log('=================================');

    // Create Redis cluster client
    const client = createCluster({
        rootNodes: [
           {}
        ],
        defaults: {
            socket: {
                host : "localhost",
                tls: true
            },
        }
    });

    try {
        // Connect to cluster
        console.log('📡 Connecting to Redis cluster...');
        await client.connect();
        console.log('✅ Connected to Redis cluster successfully!');

        // Test ping - use sendCommand for cluster
        console.log('\n🏓 Testing PING...');
        const pingResult = await client.sendCommand(undefined, false, ['PING']);
        console.log(`✅ PING response: ${pingResult}`);

        // Test cluster info
        console.log('\n📊 Getting cluster info...');
        const clusterInfo = await client.sendCommand(undefined, false, ['CLUSTER', 'INFO']);
        console.log('Cluster Info:');
        console.log(clusterInfo);

        // Simple SET/GET test
        console.log('\n🧪 Testing SET/GET...');
        await client.set('test:hello', 'Redis Cluster Works!');
        const value = await client.get('test:hello');
        console.log(`✅ SET/GET test: ${value}`);

        // Clean up
        await client.del('test:hello');
        console.log('✅ Test key cleaned up');

        console.log('\n🎉 All tests passed! Redis cluster is working correctly.');

    } catch (error) {
        console.error('❌ Error:', error);
    } finally {
        // Disconnect
        await client.disconnect();
        console.log('👋 Disconnected from Redis cluster');
    }
}

// Run the test
testRedisCluster().catch(console.error);
