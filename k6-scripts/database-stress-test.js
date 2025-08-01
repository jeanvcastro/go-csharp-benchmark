import { check, sleep } from 'k6';
import http from 'k6/http';
import { Counter, Rate, Trend } from 'k6/metrics';

const errorRate = new Rate('errors');
const responseTime = new Trend('response_time');
const databaseOperations = new Counter('database_operations');

// Separate metrics for each application
const goErrorRate = new Rate('go_db_errors');
const csharpEfErrorRate = new Rate('csharp_ef_db_errors');
const csharpDapperErrorRate = new Rate('csharp_dapper_db_errors');
const goResponseTime = new Trend('go_db_response_time');
const csharpEfResponseTime = new Trend('csharp_ef_db_response_time');
const csharpDapperResponseTime = new Trend('csharp_dapper_db_response_time');
const goDbOperations = new Counter('go_db_operations');
const csharpEfDbOperations = new Counter('csharp_ef_db_operations');
const csharpDapperDbOperations = new Counter('csharp_dapper_db_operations');

export const options = {
    scenarios: {
        database_stress: {
            executor: 'constant-vus',
            vus: 50,                    // 50 concurrent connections
            duration: '10m',            // 10 minutes stress test
            gracefulStop: '30s',
        },
    },
    thresholds: {
        http_req_duration: ['p(95)<1000'],  // 95% under 1s
        http_req_failed: ['rate<0.1'],      // Error rate under 10%
        database_operations: ['count>10000'], // Minimum operations
    },
};

const goBaseUrl = 'http://localhost:8080/api/v1';
const csharpEfBaseUrl = 'http://localhost:8081/api/v1';
const csharpDapperBaseUrl = 'http://localhost:8082/api/v1';

let createdUsers = [];
let createdOrders = [];

export function setup() {
    console.log('Setting up database stress test...');
    return { startTime: Date.now() };
}

// Helper function to track metrics per app
function trackMetrics(appChoice, response, operationCount = 1) {
    const duration = response.timings.duration;
    const isError = response.status < 200 || response.status >= 400;
    
    if (appChoice === 0) {
        goResponseTime.add(duration);
        goErrorRate.add(isError);
        goDbOperations.add(operationCount);
    } else if (appChoice === 1) {
        csharpEfResponseTime.add(duration);
        csharpEfErrorRate.add(isError);
        csharpEfDbOperations.add(operationCount);
    } else {
        csharpDapperResponseTime.add(duration);
        csharpDapperErrorRate.add(isError);
        csharpDapperDbOperations.add(operationCount);
    }
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
    
    if (operation < 0.4) {
        // 40% - Complex read operations with JOINs
        complexReadOperations(baseUrl, appChoice);
    } else if (operation < 0.7) {
        // 30% - Write operations with transactions
        complexWriteOperations(baseUrl, appChoice);
    } else if (operation < 0.85) {
        // 15% - Batch operations
        batchOperations(baseUrl, appChoice);
    } else {
        // 15% - Connection pool stress
        connectionPoolStress(baseUrl, appChoice);
    }
    
    sleep(Math.random() * 0.5); // Variable sleep to simulate real usage
}

function complexReadOperations(baseUrl, appChoice) {
    const operations = [
        // Get orders with user data (JOIN operation)
        () => {
            const response = http.get(`${baseUrl}/orders?limit=20&offset=${Math.floor(Math.random() * 100)}`);
            
            check(response, {
                'complex orders query status is 200': (r) => r.status === 200,
                'orders have user data': (r) => {
                    try {
                        const data = JSON.parse(r.body || '{}');
                        return data.orders && data.orders.length > 0 ? data.orders[0].user !== undefined : true;
                    } catch (e) {
                        return false;
                    }
                },
            });
            
            databaseOperations.add(1);
            return response;
        },
        
        // Multiple user queries in sequence
        () => {
            const responses = [];
            for (let i = 0; i < 5; i++) {
                const response = http.get(`${baseUrl}/users?limit=10&offset=${i * 10}`);
                responses.push(response);
                
                check(response, {
                    'sequential user query status is 200': (r) => r.status === 200,
                });
                
                databaseOperations.add(1);
            }
            return responses[0]; // Return first for timing
        }
    ];
    
    const selectedOp = operations[Math.floor(Math.random() * operations.length)];
    const response = selectedOp();
    
    errorRate.add(response.status !== 200);
    responseTime.add(response.timings.duration);
    trackMetrics(appChoice, response, 1);
}

function complexWriteOperations(baseUrl, appChoice) {
    // Create user with immediate order creation (transaction stress)
    const userData = {
        username: `stressuser${Date.now()}${Math.floor(Math.random() * 10000)}`,
        email: `stress${Date.now()}@example.com`,
        full_name: `Stress Test User ${Math.floor(Math.random() * 1000)}`
    };
    
    const userResponse = http.post(`${baseUrl}/users`, JSON.stringify(userData), {
        headers: { 'Content-Type': 'application/json' }
    });
    
    check(userResponse, {
        'stress user creation status is 201': (r) => r.status === 201,
    });
    
    databaseOperations.add(1);
    errorRate.add(userResponse.status !== 201);
    responseTime.add(userResponse.timings.duration);
    trackMetrics(appChoice, userResponse, 1);
    
    if (userResponse.status === 201) {
        let user = null;
        try {
            user = JSON.parse(userResponse.body || '{}');
            if (user.id) {
                createdUsers.push(user);
            }
        } catch (e) {
            console.log('Error parsing user response:', e);
            return;
        }
        
        // Immediately create multiple orders for this user
        if (user && user.id) {
            for (let i = 0; i < 3; i++) {
                const orderData = {
                    user_id: user.id,
                order_items: [
                    {
                        product_name: `Stress Product ${i}-${Math.floor(Math.random() * 100)}`,
                        quantity: Math.floor(Math.random() * 10) + 1,
                        unit_price: (Math.random() * 200 + 50).toFixed(2)
                    },
                    {
                        product_name: `Stress Product ${i}-${Math.floor(Math.random() * 100)}-B`,
                        quantity: Math.floor(Math.random() * 5) + 1,
                        unit_price: (Math.random() * 150 + 25).toFixed(2)
                    }
                ]
            };
            
            const orderResponse = http.post(`${baseUrl}/orders`, JSON.stringify(orderData), {
                headers: { 'Content-Type': 'application/json' }
            });
            
            check(orderResponse, {
                'stress order creation status is 201': (r) => r.status === 201,
            });
            
            databaseOperations.add(1);
            errorRate.add(orderResponse.status !== 201);
            trackMetrics(appChoice, orderResponse, 1);
            
            if (orderResponse.status === 201) {
                try {
                    const order = JSON.parse(orderResponse.body || '{}');
                    if (order.id) {
                        createdOrders.push(order);
                    }
                } catch (e) {
                    console.log('Error parsing order response:', e);
                }
            }
        }
    }
    }
}

function batchOperations(baseUrl, appChoice) {
    // Simulate batch processing by rapid-fire requests
    const batchSize = 10;
    const responses = [];
    
    for (let i = 0; i < batchSize; i++) {
        const response = http.get(`${baseUrl}/users?limit=5&offset=${i * 5}`);
        responses.push(response);
        databaseOperations.add(1);
    }
    
    const avgResponseTime = responses.reduce((sum, r) => sum + r.timings.duration, 0) / responses.length;
    const errorCount = responses.filter(r => r.status !== 200).length;
    
    check(responses[0], {
        'batch operations avg response time < 2s': () => avgResponseTime < 2000,
        'batch operations error rate < 20%': () => (errorCount / batchSize) < 0.2,
    });
    
    errorRate.add(errorCount / batchSize);
    responseTime.add(avgResponseTime);
    trackMetrics(appChoice, responses[0], batchSize);
}

function connectionPoolStress(baseUrl, appChoice) {
    // Rapid concurrent requests to stress connection pool
    const concurrent = 20;
    const responses = [];
    
    // Fire concurrent requests
    for (let i = 0; i < concurrent; i++) {
        const endpoint = Math.random() < 0.5 ? 'users' : 'orders';
        const response = http.get(`${baseUrl}/${endpoint}?limit=1&offset=${i}`);
        responses.push(response);
        databaseOperations.add(1);
    }
    
    const successCount = responses.filter(r => r.status === 200).length;
    const maxResponseTime = Math.max(...responses.map(r => r.timings.duration));
    
    check(responses[0], {
        'connection pool stress success rate > 80%': () => (successCount / concurrent) > 0.8,
        'connection pool max response time < 5s': () => maxResponseTime < 5000,
    });
    
    errorRate.add((concurrent - successCount) / concurrent);
    responseTime.add(maxResponseTime);
    trackMetrics(appChoice, responses[0], concurrent);
}

export function teardown(data) {
    console.log('Database stress test completed');
    console.log(`Test duration: ${(Date.now() - data.startTime) / 1000} seconds`);
    console.log(`Created ${createdUsers.length} users and ${createdOrders.length} orders`);
}