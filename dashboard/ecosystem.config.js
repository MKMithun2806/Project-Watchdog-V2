module.exports = {
  apps: [
    {
      name: 'watchdog',
      script: '.next/standalone/server.js',
      env: {
        NODE_ENV: 'production',
        PORT: 3000,
      },
      max_memory_restart: '400M',
      instances: 1,
      autorestart: true,
      watch: false,
    },
  ],
};
