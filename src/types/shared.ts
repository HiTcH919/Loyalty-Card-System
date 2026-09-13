// Shared type definitions used across the application.
export type LocaleDirection = "ltr" | "rtl";
export type Locale = "en" | "ar";

export function getDirection(locale: Locale): LocaleDirection {
  return locale === "ar" ? "rtl" : "ltr";
}

export const EGYPTIAN_PHONE_REGEX = /^(\+20|0020)?(01[0-5])[0-9]{8}$/;
export const EGYPTIAN_PHONE_STRICT_REGEX = /^01[0-5][0-9]{8}$/;

export function normalizeEgyptianPhone(phone: string): string {
  const cleaned = phone.replace(/[\s\-+()]/g, "");
  if (cleaned.startsWith("20") || cleaned.startsWith("0020")) {
    return "0" + cleaned.slice(cleaned.startsWith("0020") ? 4 : 2);
  }
  return cleaned;
}

export function isValidEgyptianPhone(phone: string): boolean {
  return EGYPTIAN_PHONE_STRICT_REGEX.test(normalizeEgyptianPhone(phone));
}

export type Result<T, E = string> =
  | { success: true; data: T }
  | { success: false; error: E };

export function ok<T>(data: T): Result<T, never> {
  return { success: true, data };
}

export function fail<E>(error: E): Result<never, E> {
  return { success: false, error };
}

export function mergeDeep<T extends object>(target: T, source: Partial<T>): T {
  const result = { ...target };
  for (const key of Object.keys(source) as (keyof T)[]) {
    if (
      source[key] !== null &&
      typeof source[key] === "object" &&
      !Array.isArray(source[key]) &&
      result[key] !== null &&
      typeof result[key] === "object" &&
      !Array.isArray(result[key])
    ) {
      result[key] = mergeDeep(result[key], source[key] as any) as T[keyof T];
    } else {
      result[key] = source[key] as T[keyof T];
    }
  }
  return result;
}

export function randomHex(length: number): string {
  const bytes = new Uint8Array(length);
  crypto.getRandomValues(bytes);
  return Array.from(bytes, (b) => b.toString(16).padStart(2, "0")).join("");
}

export function generateIdentifier(prefix: string = "SYS", length: number = 8): string {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
  return prefix + Array.from(crypto.getRandomValues(new Uint8Array(length)))
    .map((b) => chars[b % chars.length])
    .join("");
}

export type MembershipRole =
  | "system_manager"
  | "business_owner"
  | "employee"
  | "cashier"
  | "manager"
  | "admin";
