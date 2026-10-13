/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  // API backend ở :8000 (FastAPI), frontend web ở :3001
  async rewrites() {
    return [
      {
        source: "/api/proxy/:path*",
        destination: `${process.env.NEXT_PUBLIC_API_BASE_URL || "http://localhost:8000"}/api/:path*`,
      },
    ];
  },
};

module.exports = nextConfig;
