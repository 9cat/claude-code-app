#!/usr/bin/env node

// Simple WebSocket test without external dependencies
const WebSocket = require('ws');

console.log('🔍 Testing WebSocket connection to Claude-Code proxy...');

const ws = new WebSocket('ws://localhost:64008/ws');

let messageCount = 0;

function logMessage(type, data) {
    messageCount++;
    const timestamp = new Date().toISOString().split('T')[1].split('.')[0];
    console.log(`[${timestamp}] #${messageCount} ${type}:`, data);
}

ws.on('open', function open() {
    logMessage('CONNECTED', '✅ WebSocket connection established');
    
    // Send auth message
    const authMsg = {
        type: 'auth',
        username: 'admin',
        password: 'password123'
    };
    
    logMessage('SENDING', authMsg);
    ws.send(JSON.stringify(authMsg));
});

ws.on('message', function message(data) {
    const rawData = data.toString();
    logMessage('RECEIVED', `Raw: ${rawData}`);
    
    try {
        const parsed = JSON.parse(rawData);
        logMessage('PARSED', parsed);
        
        // After successful auth, send test command
        if (parsed.type === 'auth-success') {
            logMessage('AUTH_SUCCESS', '🔐 Authentication successful, sending test command...');
            
            setTimeout(() => {
                const testCmd = {
                    type: 'command',
                    command: 'create hello world in go'
                };
                logMessage('SENDING', testCmd);
                ws.send(JSON.stringify(testCmd));
            }, 1000);
        }
        
        // Highlight Claude responses
        if (parsed.type === 'claude-output') {
            logMessage('CLAUDE_RESPONSE', `🤖 "${parsed.data || parsed.message}"`);
        }
        
    } catch (e) {
        logMessage('PARSE_ERROR', `Failed to parse JSON: ${e.message}`);
    }
});

ws.on('error', function error(err) {
    logMessage('ERROR', `💥 WebSocket error: ${err.message}`);
});

ws.on('close', function close(code, reason) {
    logMessage('CLOSED', `❌ Connection closed. Code: ${code}, Reason: ${reason}`);
    process.exit(0);
});

// Keep connection alive for testing
setTimeout(() => {
    logMessage('TIMEOUT', '⏰ Test completed, closing connection...');
    ws.close();
}, 30000);