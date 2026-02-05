#!/usr/bin/env node

/**
 * Kakao OAuth Refresh Token Collector
 * 
 * 1. Starts local server on :8080
 * 2. Opens browser for authorization
 * 3. Exchanges code for tokens
 * 4. Saves refresh_token to openclaw.json
 */

const http = require('http');
const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

const REST_API_KEY = process.env.KAKAO_REST_API_KEY || 'YOUR_KAKAO_API_KEY_HERE';
const CLIENT_SECRET = process.env.KAKAO_CLIENT_SECRET;
const REDIRECT_URI = 'http://localhost:8080/callback';
const SCOPE = 'talk_calendar';

if (!CLIENT_SECRET) {
  console.error('❌ KAKAO_CLIENT_SECRET environment variable not set');
  process.exit(1);
}

const CONFIG_PATH = path.join(process.env.HOME, '.openclaw', 'openclaw.json');

// Authorization URL
const authUrl = `https://kauth.kakao.com/oauth/authorize?client_id=${REST_API_KEY}&redirect_uri=${encodeURIComponent(REDIRECT_URI)}&response_type=code&scope=${SCOPE}`;

console.log('📱 Kakao OAuth Refresh Token Collector\n');
console.log('🔗 Authorization URL:');
console.log(authUrl);
console.log('\n🌐 Opening browser...\n');

// Open browser
spawn('open', [authUrl]);

// Start callback server
const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://localhost:8080`);
  
  if (url.pathname === '/callback') {
    const code = url.searchParams.get('code');
    const error = url.searchParams.get('error');
    
    if (error) {
      res.writeHead(400, { 'Content-Type': 'text/html; charset=utf-8' });
      res.end(`<h1>❌ Authorization Failed</h1><p>Error: ${error}</p>`);
      console.error('❌ Authorization failed:', error);
      server.close();
      process.exit(1);
    }
    
    if (!code) {
      res.writeHead(400, { 'Content-Type': 'text/html; charset=utf-8' });
      res.end('<h1>❌ No code received</h1>');
      console.error('❌ No authorization code received');
      server.close();
      process.exit(1);
    }
    
    console.log('✅ Authorization code received:', code);
    console.log('🔄 Exchanging code for tokens...\n');
    
    // Exchange code for tokens
    try {
      const tokenResponse = await fetch('https://kauth.kakao.com/oauth/token', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded;charset=utf-8'
        },
        body: new URLSearchParams({
          grant_type: 'authorization_code',
          client_id: REST_API_KEY,
          client_secret: CLIENT_SECRET,
          redirect_uri: REDIRECT_URI,
          code: code
        })
      });
      
      const tokens = await tokenResponse.json();
      
      if (tokens.error) {
        throw new Error(`Token exchange failed: ${tokens.error_description || tokens.error}`);
      }
      
      console.log('✅ Tokens received:');
      console.log(`   Access Token: ${tokens.access_token.substring(0, 20)}...`);
      console.log(`   Refresh Token: ${tokens.refresh_token.substring(0, 20)}...`);
      console.log(`   Expires in: ${tokens.expires_in}s (${tokens.expires_in / 3600}h)`);
      console.log(`   Refresh Token Expires in: ${tokens.refresh_token_expires_in}s (${tokens.refresh_token_expires_in / 86400}d)\n`);
      
      // Save to openclaw.json
      const config = JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8'));
      
      if (!config.env) config.env = {};
      if (!config.env.vars) config.env.vars = {};
      
      config.env.vars.KAKAO_ACCESS_TOKEN = tokens.access_token;
      config.env.vars.KAKAO_REFRESH_TOKEN = tokens.refresh_token;
      config.env.vars.KAKAO_TOKEN_EXPIRES_AT = new Date(Date.now() + tokens.expires_in * 1000).toISOString();
      config.env.vars.KAKAO_REFRESH_TOKEN_EXPIRES_AT = new Date(Date.now() + tokens.refresh_token_expires_in * 1000).toISOString();
      
      fs.writeFileSync(CONFIG_PATH, JSON.stringify(config, null, 2));
      
      console.log('💾 Tokens saved to:', CONFIG_PATH);
      console.log('✅ Done! Gateway restart required.\n');
      
      res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
      res.end(`
        <h1>✅ Success!</h1>
        <p>Refresh token saved. You can close this window.</p>
        <p>Next: Restart OpenClaw gateway.</p>
      `);
      
      server.close();
      process.exit(0);
      
    } catch (error) {
      console.error('❌ Token exchange failed:', error.message);
      res.writeHead(500, { 'Content-Type': 'text/html; charset=utf-8' });
      res.end(`<h1>❌ Token Exchange Failed</h1><p>${error.message}</p>`);
      server.close();
      process.exit(1);
    }
  } else {
    res.writeHead(404);
    res.end('Not Found');
  }
});

server.listen(8080, () => {
  console.log('🚀 Callback server listening on http://localhost:8080');
  console.log('⏳ Waiting for authorization...\n');
});

// Timeout after 5 minutes
setTimeout(() => {
  console.log('\n⏰ Timeout after 5 minutes');
  server.close();
  process.exit(1);
}, 5 * 60 * 1000);
