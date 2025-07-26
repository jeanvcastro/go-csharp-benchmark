import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

const errorRate = new Rate('errors');
const responseTime = new Trend('response_time');

export const options = {
    stages: [
        { duration: '1m', target: 100 },   // Ramp up
        { duration: '5m', target: 1000 },  // Stay at 1000 RPS
        { duration: '1m', target: 0 },     // Ramp down
    ],
    thresholds: {
        http_req_duration: ['p(95)<500'],  // 95% requests under 500ms
        http_req_failed: ['rate<0.05'],    // Error rate under 5%
    },
};

const goBaseUrl = 'http://localhost:8080/api/v1';
const csharpBaseUrl = 'http://localhost:8081/api/v1';

let testUsers = [];
let testOrders = [];

export function setup() {
    console.log('Setting up test data...');
    
    const users = [];
    for (let i = 0; i < 50; i++) {
        const userData = {
            username: `testuser${i}`,
            email: `testuser${i}@example.com`,
            full_name: `Test User ${i}`
        };
        
        const goUser = http.post(`${goBaseUrl}/users`, JSON.stringify(userData), {
            headers: { 'Content-Type': 'application/json' }
        });
        
        const csharpUserData = {
            username: `csharpuser${i}`,
            email: `csharpuser${i}@example.com`,
            full_name: `CSharp User ${i}`
        };
        
        const csharpUser = http.post(`${csharpBaseUrl}/users`, JSON.stringify(csharpUserData), {
            headers: { 'Content-Type': 'application/json' }
        });
        
        if (goUser.status === 201) users.push(JSON.parse(goUser.body));
        if (csharpUser.status === 201) users.push(JSON.parse(csharpUser.body));
    }
    
    return { users };
}

export default function(data) {
    const baseUrl = Math.random() < 0.5 ? goBaseUrl : csharpBaseUrl;
    const operation = Math.random();
    
    if (operation < 0.6) {
        // 60% reads
        readOperations(baseUrl, data);
    } else if (operation < 0.9) {
        // 30% writes
        writeOperations(baseUrl, data);
    } else {
        // 10% deletes
        deleteOperations(baseUrl, data);
    }
    
    sleep(0.1);
}

function readOperations(baseUrl, data) {
    const readType = Math.random();
    
    if (readType < 0.5) {
        // Get users with pagination
        const limit = Math.floor(Math.random() * 20) + 1;
        const offset = Math.floor(Math.random() * 100);
        
        const response = http.get(`${baseUrl}/users?limit=${limit}&offset=${offset}`);
        
        check(response, {
            'users list status is 200': (r) => r.status === 200,
            'users list has data': (r) => {
                try {
                    const data = JSON.parse(r.body || '{}');
                    return data.users !== undefined && Array.isArray(data.users);
                } catch (e) {
                    return false;
                }
            },
        });
        
        errorRate.add(response.status !== 200);
        responseTime.add(response.timings.duration);
        
    } else {
        // Get orders with users
        const limit = Math.floor(Math.random() * 10) + 1;
        const offset = Math.floor(Math.random() * 50);
        
        const response = http.get(`${baseUrl}/orders?limit=${limit}&offset=${offset}`);
        
        check(response, {
            'orders list status is 200': (r) => r.status === 200,
            'orders list has data': (r) => {
                try {
                    const data = JSON.parse(r.body || '{}');
                    return data.orders !== undefined && Array.isArray(data.orders);
                } catch (e) {
                    return false;
                }
            },
        });
        
        errorRate.add(response.status !== 200);
        responseTime.add(response.timings.duration);
    }
}

function writeOperations(baseUrl, data) {
    const writeType = Math.random();
    
    if (writeType < 0.7) {
        // Create user
        const userData = {
            username: `loadtest${Date.now()}${Math.floor(Math.random() * 1000)}`,
            email: `loadtest${Date.now()}@example.com`,
            full_name: `Load Test User ${Date.now()}`
        };
        
        const response = http.post(`${baseUrl}/users`, JSON.stringify(userData), {
            headers: { 'Content-Type': 'application/json' }
        });
        
        check(response, {
            'user creation status is 201': (r) => r.status === 201,
            'user creation returns user': (r) => {
                try {
                    const data = JSON.parse(r.body || '{}');
                    return data.id !== undefined;
                } catch (e) {
                    return false;
                }
            },
        });
        
        errorRate.add(response.status !== 201);
        responseTime.add(response.timings.duration);
        
    } else {
        // Create order
        const orderData = {
            user_id: data.users[Math.floor(Math.random() * data.users.length)]?.id,
            order_items: [
                {
                    product_name: `Product ${Math.floor(Math.random() * 100)}`,
                    quantity: Math.floor(Math.random() * 5) + 1,
                    unit_price: (Math.random() * 100 + 10).toFixed(2)
                }
            ]
        };
        
        if (orderData.user_id) {
            const response = http.post(`${baseUrl}/orders`, JSON.stringify(orderData), {
                headers: { 'Content-Type': 'application/json' }
            });
            
            check(response, {
                'order creation status is 201': (r) => r.status === 201,
                'order creation returns order': (r) => {
                    try {
                        const data = JSON.parse(r.body || '{}');
                        return data.id !== undefined;
                    } catch (e) {
                        return false;
                    }
                },
            });
            
            errorRate.add(response.status !== 201);
            responseTime.add(response.timings.duration);
        }
    }
}

function deleteOperations(baseUrl, data) {
    if (data.users.length > 0) {
        const randomUser = data.users[Math.floor(Math.random() * data.users.length)];
        
        const response = http.del(`${baseUrl}/users/${randomUser.id}`);
        
        check(response, {
            'user deletion status is 204 or 404': (r) => r.status === 204 || r.status === 404,
        });
        
        errorRate.add(response.status !== 204 && response.status !== 404);
        responseTime.add(response.timings.duration);
    }
}

export function teardown(data) {
    console.log('Cleaning up test data...');
}