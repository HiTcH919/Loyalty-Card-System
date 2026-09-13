// Next.js configuration.
import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  // Internationalization is handled by next-intl middleware.
  // The built-in i18n config is NOT used — it causes Turbopack
  // route-parsing errors in Next.js 16 when combined with middleware matchers.

  images: {
    remotePatterns: [
      {
        protocol: "https",
        hostname: "*.supabase.co",
        pathname: "/storage/v1/object/public/**",
      },
      {
        protocol: "https",
        hostname: "images.unsplash.com",
      },
    ],
  },

  async headers() {
    return [
      {
        source: "/(.*)",
        headers: [
          { key: "X-Content-Type-Options", value: "nosniff" },
          { key: "X-Frame-Options", value: "DENY" },
          { key: "X-XSS-Protection", value: "1; mode=block" },
          { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
          { key: "Permissions-Policy", value: "camera=(), microphone=(), nfc=()" },
        ],
      },
    ];
  },
};

export default nextConfig;
