import { check, sleep } from 'k6';
import http from 'k6/http';
import { Counter, Rate, Trend } from 'k6/metrics';

const errorRate = new Rate('errors');
const responseTime = new Trend('response_time');
const memoryOperations = new Counter('memory_operations');

export const options = {
    scenarios: {
        memory_pressure: {
            executor: 'ramping-vus',
            startVUs: 1,
            stages: [
                { duration: '2m', target: 10 },   // Gradual ramp up
                { duration: '5m', target: 25 },   // Memory pressure phase
                { duration: '5m', target: 50 },   // High memory pressure
                { duration: '2m', target: 0 },    // Cool down
            ],
        },
    },
    thresholds: {
        http_req_duration: ['p(95)<2000'],  // 95% under 2s (memory pressure allows higher latency)
        http_req_failed: ['rate<0.15'],     // Error rate under 15%
        memory_operations: ['count>1000'],  // Minimum memory operations
    },
};

const goBaseUrl = 'http://localhost:8080/api/v1';
const csharpEfBaseUrl = 'http://localhost:8083/api/v1';
const csharpDapperBaseUrl = 'http://localhost:8082/api/v1';

let largeDataSets = [];

export function setup() {
    console.log('Setting up memory pressure test...');
    
    // Pre-create large datasets to stress memory
    console.log('Creating large datasets for memory pressure...');
    const userData = [];
    
    for (let i = 0; i < 200; i++) {
        userData.push({
            username: `memuser${i}`,
            email: `memuser${i}@example.com`,
            full_name: `Memory Test User ${i} with very long name to increase memory usage and stress garbage collection systems`
        });
    }
    
    return { 
        userData,
        startTime: Date.now()
    };
}

export default function(data) {
    // Randomly select one of the 3 applications
    const appChoice = Math.floor(Math.random() * 3);
    let baseUrl;
    
    if (appChoice === 0) {
        baseUrl = goBaseUrl;
    } else if (appChoice === 1) {
        baseUrl = csharpEfBaseUrl;
    } else {
        baseUrl = csharpDapperBaseUrl;
    }
    const operation = Math.random();
    
    if (operation < 0.3) {
        // 30% - Large payload operations
        largePayloadOperations(baseUrl, data);
    } else if (operation < 0.6) {
        // 30% - Rapid allocation/deallocation
        rapidAllocationOperations(baseUrl, data);
    } else if (operation < 0.8) {
        // 20% - Large result set queries
        largeResultSetOperations(baseUrl);
    } else {
        // 20% - Memory-intensive batch operations
        memoryIntensiveBatchOperations(baseUrl, data);
    }
    
    sleep(Math.random() * 0.2); // Short sleep to maintain pressure
}

function largePayloadOperations(baseUrl, data) {
    // Create users with large payloads
    const largeUserData = {
        username: `largepayload${Date.now()}${Math.floor(Math.random() * 10000)}`,
        email: `largepayload${Date.now()}@example.com`,
        full_name: 'Large Payload User '.repeat(50) + Math.random() // ~1KB name
    };
    
    const response = http.post(`${baseUrl}/users`, JSON.stringify(largeUserData), {
        headers: { 'Content-Type': 'application/json' }
    });
    
    check(response, {
        'large payload user creation status is 201': (r) => r.status === 201,
        'large payload response time acceptable': (r) => r.timings.duration < 3000,
    });
    
    memoryOperations.add(1);
    errorRate.add(response.status !== 201);
    responseTime.add(response.timings.duration);
    
    if (response.status === 201) {
        let user;
        try {
            user = JSON.parse(response.body || '{}');
        } catch (e) {
            console.log('Error parsing user response:', e);
            return;
        }
        
        // Create order with many items to stress memory
        const manyItems = [];
        for (let i = 0; i < 20; i++) {
            manyItems.push({
                product_name: `Memory Stress Product ${i} `.repeat(10), // Large product names
                quantity: Math.floor(Math.random() * 100) + 1,
                unit_price: (Math.random() * 1000 + 100).toFixed(2)
            });
        }
        
        const orderData = {
            user_id: user.id,
            order_items: manyItems
        };
        
        const orderResponse = http.post(`${baseUrl}/orders`, JSON.stringify(orderData), {
            headers: { 'Content-Type': 'application/json' }
        });
        
        check(orderResponse, {
            'large order creation status is 201': (r) => r.status === 201,
        });
        
        memoryOperations.add(1);
        errorRate.add(orderResponse.status !== 201);
    }
}

function rapidAllocationOperations(baseUrl, data) {
    // Rapidly create and query data to stress GC
    const operations = [];
    
    for (let i = 0; i < 10; i++) {
        const userData = {
            username: `rapid${Date.now()}${i}`,
            email: `rapid${Date.now()}${i}@example.com`,
            full_name: `Rapid User ${i}`
        };
        
        operations.push(
            http.post(`${baseUrl}/users`, JSON.stringify(userData), {
                headers: { 'Content-Type': 'application/json' }
            })
        );
        
        memoryOperations.add(1);
    }
    
    // Immediately query the data
    for (let i = 0; i < 5; i++) {
        const response = http.get(`${baseUrl}/users?limit=20&offset=${i * 20}`);
        operations.push(response);
        memoryOperations.add(1);
    }
    
    const successCount = operations.filter(r => r.status === 200 || r.status === 201).length;
    const avgResponseTime = operations.reduce((sum, r) => sum + r.timings.duration, 0) / operations.length;
    
    check(operations[0], {
        'rapid allocation success rate > 70%': () => (successCount / operations.length) > 0.7,
        'rapid allocation avg response time < 3s': () => avgResponseTime < 3000,
    });
    
    errorRate.add((operations.length - successCount) / operations.length);
    responseTime.add(avgResponseTime);
}

function largeResultSetOperations(baseUrl) {
    // Query large result sets to stress memory on response processing
    const queries = [
        `${baseUrl}/users?limit=100&offset=0`,
        `${baseUrl}/orders?limit=100&offset=0`,
        `${baseUrl}/users?limit=50&offset=50`,
        `${baseUrl}/orders?limit=50&offset=25`
    ];
    
    const responses = [];
    
    queries.forEach(query => {
        const response = http.get(query);
        responses.push(response);
        
        check(response, {
            'large result set status is 200': (r) => r.status === 200,
            'large result set has data': (r) => {
                try {
                    const data = JSON.parse(r.body || '{}');
                    return (data.users && data.users.length >= 0) || (data.orders && data.orders.length >= 0);
                } catch {
                    return false;
                }
            }
        });
        
        memoryOperations.add(1);
    });
    
    const totalResponseTime = responses.reduce((sum, r) => sum + r.timings.duration, 0);
    const errorCount = responses.filter(r => r.status !== 200).length;
    
    errorRate.add(errorCount / responses.length);
    responseTime.add(totalResponseTime / responses.length);
}

function memoryIntensiveBatchOperations(baseUrl, data) {
    // Batch create multiple users simultaneously
    const batchSize = 15;
    const batch = [];
    
    for (let i = 0; i < batchSize; i++) {
        const userData = {
            username: `batch${Date.now()}${i}${Math.floor(Math.random() * 1000)}`,
            email: `batch${Date.now()}${i}@example.com`,
            full_name: `Batch Memory User ${i} `.repeat(20) // Larger names for memory pressure
        };
        
        batch.push(userData);
    }
    
    // Execute batch operations
    const responses = [];
    batch.forEach((userData, i) => {
        const response = http.post(`${baseUrl}/users`, JSON.stringify(userData), {
            headers: { 'Content-Type': 'application/json' }
        });
        responses.push(response);
        memoryOperations.add(1);
        
        // Small delay to prevent overwhelming
        if (i % 5 === 0) {
            sleep(0.1);
        }
    });
    
    const successCount = responses.filter(r => r.status === 201).length;
    const avgResponseTime = responses.reduce((sum, r) => sum + r.timings.duration, 0) / responses.length;
    
    check(responses[0], {
        'batch memory operations success rate > 60%': () => (successCount / batchSize) > 0.6,
        'batch memory operations avg time < 4s': () => avgResponseTime < 4000,
    });
    
    errorRate.add((batchSize - successCount) / batchSize);
    responseTime.add(avgResponseTime);
}

export function teardown(data) {
    console.log('Memory pressure test completed');
    console.log(`Test duration: ${(Date.now() - data.startTime) / 1000} seconds`);
    console.log('Check application metrics for memory usage and GC patterns');
}