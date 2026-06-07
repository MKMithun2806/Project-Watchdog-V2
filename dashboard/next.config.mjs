/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone',
  poweredByHeader: false,
  reactStrictMode: true,
  experimental: {
    outputFileTracingIncludes: {
      '/*': ['./node_modules/@supabase/**/*'],
    },
  },
};

export default nextConfig;
