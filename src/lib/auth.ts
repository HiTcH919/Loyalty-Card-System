// Authentication utilities.
import { createServerSupabaseClient } from "@/lib/supabase/server";
import { redirect } from "next/navigation";
import type { MembershipRole } from "@/types/shared";

export async function getCurrentUser() {
  const supabase = createServerSupabaseClient();
  const { data: { user }, error } = await supabase.auth.getUser();

  if (error || !user) {
    return null;
  }

  const { data: profile } = await supabase
    .from("profiles")
    .select("*")
    .eq("id", user.id)
    .single();

  const { data: memberships } = await supabase
    .from("business_memberships")
    .select(
      `*,
      businesses:businesses(id, name, logo_url, primary_color, brand_name, brand_short_name, customer_identification_methods, offline_policy, simple_mode, setup_completed),
      branches:branches(id, name, is_primary)`
    )
    .eq("user_id", user.id)
    .eq("is_active", true);

  return { user, profile, memberships: memberships ?? [] };
}

export async function hasRoleInBusiness(
  userId: string,
  businessId: string,
  role: MembershipRole,
): Promise<boolean> {
  const supabase = createServerSupabaseClient();
  const { data } = await supabase
    .from("business_memberships")
    .select("role")
    .eq("user_id", userId)
    .eq("business_id", businessId)
    .eq("role", role)
    .eq("is_active", true)
    .single();

  return data !== null;
}

export async function isSystemManager(userId: string): Promise<boolean> {
  const supabase = createServerSupabaseClient();
  const { data } = await supabase
    .from("profiles")
    .select("id")
    .eq("id", userId)
    .single();

  if (!data) return false;

  const { data: membership } = await supabase
    .from("business_memberships")
    .select("role")
    .eq("user_id", userId)
    .eq("role", "system_manager")
    .single();

  return membership !== null;
}

export async function requireAuth() {
  const user = await getCurrentUser();
  if (!user) {
    redirect("/login");
  }
  return user;
}

export async function requireSetupComplete(
  businessId: string,
): Promise<void> {
  const supabase = createServerSupabaseClient();
  const result = await supabase
    .from("businesses")
    .select("setup_completed, setup_completed_at")
    .eq("id", businessId)
    .single() as {
    data: { setup_completed: boolean; setup_completed_at: string | null } | null;
    error: unknown;
  };

  if (!result.data || !result.data.setup_completed) {
    redirect(`/onboarding/${businessId}`);
  }
}
