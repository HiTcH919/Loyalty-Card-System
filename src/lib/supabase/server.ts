// Supabase client for server-side usage (Server Components, Server Actions).
// Uses cookies to persist the session across server requests.
// Compatible with @supabase/ssr v0.12.x.
// Note: `cookies()` from next/headers returns a Promise in Next.js 16,
// so the cookie handlers below are async-compatible. We cast to `any`
// because the library's type declarations only expose the legacy
// sync-overload signature — the runtime accepts both.
import { createServerClient } from "@supabase/ssr";
import { cookies } from "next/headers";
import type { Database } from "@/types/database";

export function createServerSupabaseClient() {
  const cookiePromise = cookies();

  return createServerClient<Database>(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY!,
    {
      cookies: {
        get(name: string): Promise<string | null | undefined> {
          return cookiePromise.then((c) => {
            const found = c.getAll().find(({ name: n }) => n === name);
            return found?.value ?? null;
          });
        },
        set(name: string, value: string, options?: any) {
          return cookiePromise.then((c) => c.set(name, value, options));
        },
        remove(name: string, options?: any) {
          return cookiePromise.then((c) =>
            c.set(name, "", { ...options, maxAge: 0 })
          );
        },
      } as any,
    }
  );
}

/** Server-side client with the SERVICE ROLE key (bypasses RLS).
 * Use ONLY for admin/system operations that genuinely need it.
 * NEVER expose to the browser.
 */
export function createServiceRoleClient() {
  const cookiePromise = cookies();

  return createServerClient<Database>(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
    {
      cookies: {
        get(name: string): Promise<string | null | undefined> {
          return cookiePromise.then((c) => {
            const found = c.getAll().find(({ name: n }) => n === name);
            return found?.value ?? null;
          });
        },
        set(name: string, value: string, options?: any) {
          return cookiePromise.then((c) => c.set(name, value, options));
        },
        remove(name: string, options?: any) {
          return cookiePromise.then((c) =>
            c.set(name, "", { ...options, maxAge: 0 })
          );
        },
      } as any,
    }
  );
}
