#!/usr/bin/env node

const WebSocket = require('ws');

const ws = new WebSocket('ws://localhost:64008/ws');

ws.on('open', function open() {
    console.log('Connected to WebSocket');
    
    // First authenticate
    const authMsg = {
        type: 'auth',
        username: 'admin',
        password: 'password123'
    };
    
    console.log('Sending auth:', JSON.stringify(authMsg));
    ws.send(JSON.stringify(authMsg));
});

ws.on('message', function message(data) {
    const msg = JSON.parse(data.toString());
    console.log('Received:', JSON.stringify(msg, null, 2));
    
    // After successful auth, send a command
    if (msg.type === 'auth-success') {
        console.log('Auth successful, sending test command...');
        const commandMsg = {
            type: 'command',
            command: 'please create a simple hello world in golang'
        };
        
        setTimeout(() => {
            console.log('Sending command:', JSON.stringify(commandMsg));
            ws.send(JSON.stringify(commandMsg));
        }, 1000);
    }
});

ws.on('error', function error(err) {
    console.error('WebSocket error:', err);
});

ws.on('close', function close() {
    console.log('WebSocket connection closed');
});

// Keep alive for testing
setTimeout(() => {
    console.log('Test complete, closing...');
    ws.close();
}, 30000);