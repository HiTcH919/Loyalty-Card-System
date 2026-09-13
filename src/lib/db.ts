// Database helper functions.
import { createServerSupabaseClient, createServiceRoleClient } from "@/lib/supabase/server";

export { createServerSupabaseClient, createServiceRoleClient };

export const DEFAULT_PAGE_SIZE = 50;
export const MAX_PAGE_SIZE = 200;

export async function paginate<T>(
  data: T[] | null,
  count: number | null,
  page: number,
  pageSize: number = DEFAULT_PAGE_SIZE,
): Promise<{ data: T[]; count: number | null; nextPage: number | null; totalPages: number | null }> {
  const safePageSize = Math.min(pageSize, MAX_PAGE_SIZE);
  const safePage = Math.max(1, page);
  const totalPages = count ? Math.ceil(count / safePageSize) : null;
  const nextPage = count && safePage * safePageSize < count ? safePage + 1 : null;
  return { data: data ?? [], count, nextPage, totalPages };
}

export function softDeleteFilter() {
  return { deleted_at: null };
}
