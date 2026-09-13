// Next.js Middleware.
// Runs on every request — refreshes Supabase auth session and protects routes.
// `request.cookies` and `response.cookies` are synchronous in middleware context.
import { createServerClient } from "@supabase/ssr";
import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";
import type { Database } from "@/types/database";

export async function middleware(request: NextRequest) {
  const response = NextResponse.next({ request });

  const supabase = createServerClient<Database>(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        get(name: string): string | null | undefined {
          const cookie = request.cookies.get(name);
          return cookie?.value ?? null;
        },
        set(name: string, value: string, options?: any) {
          request.cookies.set(name, value);
          response.cookies.set(name, value, options);
        },
        remove(name: string, options?: any) {
          request.cookies.set(name, "");
          response.cookies.set(name, "", { ...options, maxAge: 0 });
        },
      } as any,
    }
  );

  // Refresh the session — keeps the user logged in on navigation.
  const {
    data: { user },
  } = await supabase.auth.getUser();

  return response;
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico).*)"],
};
