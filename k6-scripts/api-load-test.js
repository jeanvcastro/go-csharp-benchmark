import { check, sleep } from 'k6';
import http from 'k6/http';
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

export function setup() {
    console.log('Setting up optimized dual-app test data...');
    
    // Create separate namespaced users for each app to avoid conflicts
    const goUsers = [];
    const csharpUsers = [];
    
    // Create Go users
    for (let i = 0; i < 25; i++) {
        const userData = {
            username: `go_test_${Date.now()}_${i}`,
            email: `go_test_${Date.now()}_${i}@example.com`,
            full_name: `Go Test User ${i}`
        };
        
        const response = http.post(`${goBaseUrl}/users`, JSON.stringify(userData), {
            headers: { 'Content-Type': 'application/json' }
        });
        
        if (response.status === 201) {
            goUsers.push(JSON.parse(response.body));
        }
    }
    
    // Create C# users  
    for (let i = 0; i < 25; i++) {
        const userData = {
            username: `csharp_test_${Date.now()}_${i}`,
            email: `csharp_test_${Date.now()}_${i}@example.com`,
            full_name: `CSharp Test User ${i}`
        };
        
        const response = http.post(`${csharpBaseUrl}/users`, JSON.stringify(userData), {
            headers: { 'Content-Type': 'application/json' }
        });
        
        if (response.status === 201) {
            csharpUsers.push(JSON.parse(response.body));
        }
    }
    
    console.log(`Created ${goUsers.length} Go users and ${csharpUsers.length} C# users`);
    return { goUsers, csharpUsers };
}

export default function(data) {
    // Use VU ID to determine which app to test (split load evenly)
    const useGo = __VU % 2 === 0;
    const baseUrl = useGo ? goBaseUrl : csharpBaseUrl;
    const users = useGo ? data.goUsers : data.csharpUsers;
    const appName = useGo ? 'Go' : 'C#';
    
    if (!users || users.length === 0) {
        console.warn(`No users available for ${appName}`);
        return;
    }
    
    // Test users list
    const usersListResponse = http.get(`${baseUrl}/users?limit=10`);
    check(usersListResponse, {
        [`${appName} users list status is 200`]: (r) => r.status === 200,
        [`${appName} users list has data`]: (r) => {
            try {
                const body = JSON.parse(r.body);
                return body.users && body.users.length > 0;
            } catch (e) {
                return false;
            }
        }
    });
    responseTime.add(usersListResponse.timings.duration);
    errorRate.add(usersListResponse.status !== 200);
    
    // Test orders list
    const ordersListResponse = http.get(`${baseUrl}/orders?limit=10`);
    check(ordersListResponse, {
        [`${appName} orders list status is 200`]: (r) => r.status === 200,
        [`${appName} orders list has data`]: (r) => {
            try {
                const body = JSON.parse(r.body);
                return body.orders && Array.isArray(body.orders);
            } catch (e) {
                return false;
            }
        }
    });
    responseTime.add(ordersListResponse.timings.duration);
    errorRate.add(ordersListResponse.status !== 200);
    
    // Create user (lower frequency to reduce DB pressure)
    if (Math.random() < 0.3) {  // Only 30% of iterations create users
        const newUserData = {
            username: `${appName.toLowerCase()}_load_${Date.now()}_${Math.random()}`,
            email: `${appName.toLowerCase()}_load_${Date.now()}_${Math.random()}@example.com`,
            full_name: `${appName} Load Test User`
        };
        
        const createUserResponse = http.post(`${baseUrl}/users`, JSON.stringify(newUserData), {
            headers: { 'Content-Type': 'application/json' }
        });
        
        check(createUserResponse, {
            [`${appName} user creation status is 201`]: (r) => r.status === 201,
            [`${appName} user creation returns user`]: (r) => {
                try {
                    const body = JSON.parse(r.body);
                    return body.id && body.username;
                } catch (e) {
                    return false;
                }
            }
        });
        responseTime.add(createUserResponse.timings.duration);
        errorRate.add(createUserResponse.status !== 201);
        
        // Create order for the new user
        if (createUserResponse.status === 201) {
            const createdUser = JSON.parse(createUserResponse.body);
            const userIdField = useGo ? 'user_id' : 'user_id'; // Both use same field name
            
            const orderData = {
                [userIdField]: createdUser.id,
                order_items: [
                    {
                        product_name: `${appName} Product ${Math.random()}`,
                        quantity: Math.floor(Math.random() * 3) + 1,
                        unit_price: Math.floor(Math.random() * 50) + 10
                    }
                ]
            };
            
            const createOrderResponse = http.post(`${baseUrl}/orders`, JSON.stringify(orderData), {
                headers: { 'Content-Type': 'application/json' }
            });
            
            check(createOrderResponse, {
                [`${appName} order creation status is 201`]: (r) => r.status === 201,
                [`${appName} order creation returns order`]: (r) => {
                    try {
                        const body = JSON.parse(r.body);
                        return body.id && (body.userId || body.user_id);
                    } catch (e) {
                        return false;
                    }
                }
            });
            responseTime.add(createOrderResponse.timings.duration);
            errorRate.add(createOrderResponse.status !== 201);
            
            // Clean up - delete the created user (lower frequency)
            if (Math.random() < 0.5) {  // Only 50% cleanup to reduce DB load
                const deleteResponse = http.del(`${baseUrl}/users/${createdUser.id}`);
                check(deleteResponse, {
                    [`${appName} user deletion status is 204 or 404`]: (r) => r.status === 204 || r.status === 404
                });
                responseTime.add(deleteResponse.timings.duration);
                errorRate.add(deleteResponse.status !== 204 && deleteResponse.status !== 404);
            }
        }
    }
    
    // Longer sleep to reduce overall pressure
    sleep(0.15);
}

export function teardown(data) {
    console.log('Cleaning up optimized dual-app test data...');
    // Cleanup could be implemented here if needed
}