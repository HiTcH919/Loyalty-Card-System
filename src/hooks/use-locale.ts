import { useState, useEffect } from "react";
import { Locale, getDirection } from "@/types/shared";

const DEFAULT_LOCALE: Locale = "en";

export function useLocale() {
  const [locale, setLocale] = useState<Locale>(DEFAULT_LOCALE);
  const [direction, setDirection] = useState<"ltr" | "rtl">("ltr");

  useEffect(() => {
    const cookie = document.cookie.split("; ").find((row) => row.startsWith("NEXT_LOCALE="));
    const cookieLocale = cookie ? (cookie.split("=")[1] as Locale) : null;
    const browserLang = navigator.language.slice(0, 2) as Locale;
    const finalLocale = (cookieLocale ?? browserLang) === "ar" ? "ar" : "en";
    setLocale(finalLocale);
    setDirection(getDirection(finalLocale));
  }, []);

  return { locale, direction, isRtl: direction === "rtl" };
}
