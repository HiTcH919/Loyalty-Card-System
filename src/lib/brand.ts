// Brand configuration — centralized.
import type { Database } from "@/types/database";

type Business = Database["public"]["Tables"]["businesses"]["Row"];

export interface BrandConfig {
  name: string;
  shortName: string;
  acceptanceWording: string;
  tagline: string;
  primaryColor: string;
  secondaryColor: string;
  accentColor: string;
  logoUrl: string | null;
  iconUrl: string | null;
  memberWording: string;
  rewardsWording: string;
  qrWording: string;
}

export function loadBrandConfig(
  business: Pick<
    Business,
    | "brand_name"
    | "brand_short_name"
    | "brand_acceptance_wording"
    | "brand_tagline"
    | "primary_color"
    | "secondary_color"
    | "accent_color"
    | "logo_url"
  >
): BrandConfig {
  return {
    name: business.brand_name ?? process.env.NEXT_PUBLIC_APP_NAME ?? "[SYSTEM NAME]",
    shortName: business.brand_short_name ?? "SYS",
    acceptanceWording: business.brand_acceptance_wording ?? "ACCEPTED HERE",
    tagline: business.brand_tagline ?? "Your rewards, everywhere you go.",
    primaryColor: business.primary_color ?? "#6366f1",
    secondaryColor: business.secondary_color ?? "#1e293b",
    accentColor: business.accent_color ?? "#38bdf8",
    logoUrl: business.logo_url,
    iconUrl: null,
    memberWording: "MEMBER",
    rewardsWording: "REWARDS",
    qrWording: "QR",
  };
}

export const DEFAULT_BRAND_CONFIG: BrandConfig = {
  name: process.env.NEXT_PUBLIC_APP_NAME ?? "[SYSTEM NAME]",
  shortName: "SYS",
  acceptanceWording: "ACCEPTED HERE",
  tagline: "Your rewards, everywhere you go.",
  primaryColor: "#6366f1",
  secondaryColor: "#1e293b",
  accentColor: "#38bdf8",
  logoUrl: null,
  iconUrl: null,
  memberWording: "MEMBER",
  rewardsWording: "REWARDS",
  qrWording: "QR",
};
