// Database type definitions.
import type {
  SupabaseClient,
  Session,
  User,
  UserAttributes,
  JwtPayload,
} from "@supabase/supabase-js";

// Re-export commonly used Supabase types for convenience
export type {
  SupabaseClient,
  Session,
  User,
  UserAttributes,
  JwtPayload,
};

// Full Database type — mirrors the migration schema.
export type Database = {
  public: {
    Tables: {
      profiles: {
        Row: {
          id: string;
          uuid: string;
          email: string | null;
          full_name: string | null;
          phone: string | null;
          avatar_url: string | null;
          created_at: string;
          updated_at: string;
          last_login_at: string | null;
        };
      };
      businesses: {
        Row: {
          id: string;
          uuid: string;
          name: string;
          legal_name: string | null;
          category: string | null;
          description: string | null;
          logo_url: string | null;
          cover_image_url: string | null;
          primary_color: string | null;
          secondary_color: string | null;
          accent_color: string | null;
          brand_name: string | null;
          brand_short_name: string | null;
          brand_acceptance_wording: string | null;
          brand_tagline: string | null;
          phone: string | null;
          email: string | null;
          website: string | null;
          address_line1: string | null;
          address_line2: string | null;
          city: string | null;
          state: string | null;
          country: string | null;
          postal_code: string | null;
          latitude: number | null;
          longitude: number | null;
          currency: string | null;
          timezone: string | null;
          language: string | null;
          tax_rate: number | null;
          tax_name: string | null;
          tax_registration_number: string | null;
          business_number: string | null;
          loyalty_points_rate: number | null;
          loyalty_stamp_count: number | null;
          loyalty_visit_threshold: number | null;
          loyalty_spend_threshold: number | null;
          first_purchase_bonus_points: number | null;
          birthday_bonus_points: number | null;
          referral_bonus_points: number | null;
          vip_multiplier: number | null;
          double_points_enabled: boolean | null;
          customer_identification_methods: string | null;
          offline_policy: string | null;
          simple_mode: boolean | null;
          setup_completed: boolean | null;
          setup_completed_at: string | null;
          created_at: string;
          updated_at: string;
          deleted_at: string | null;
        };
      };
      business_memberships: {
        Row: {
          id: string;
          uuid: string;
          business_id: string;
          user_id: string;
          role: string;
          branch_id: string | null;
          is_active: boolean;
          joined_at: string;
          created_at: string;
          updated_at: string;
        };
      };
      roles: {
        Row: {
          id: string;
          uuid: string;
          name: string;
          description: string | null;
          is_system: boolean;
          created_at: string;
          updated_at: string;
        };
      };
      permissions: {
        Row: {
          id: string;
          uuid: string;
          code: string;
          name: string;
          description: string | null;
          category: string | null;
          created_at: string;
          updated_at: string;
        };
      };
      role_permissions: {
        Row: {
          id: string;
          role_id: string;
          permission_id: string;
          granted_at: string;
        };
      };
      branches: {
        Row: {
          id: string;
          uuid: string;
          business_id: string;
          name: string;
          code: string | null;
          description: string | null;
          address_line1: string | null;
          address_line2: string | null;
          city: string | null;
          state: string | null;
          country: string | null;
          postal_code: string | null;
          phone: string | null;
          email: string | null;
          latitude: number | null;
          longitude: number | null;
          is_primary: boolean;
          is_active: boolean;
          opening_time: string | null;
          closing_time: string | null;
          created_at: string;
          updated_at: string;
          deleted_at: string | null;
        };
      };
      devices: {
        Row: {
          id: string;
          uuid: string;
          business_id: string;
          name: string;
          device_id: string;
          platform: string | null;
          app_version: string | null;
          os_version: string | null;
          manufacturer: string | null;
          model: string | null;
          branch_id: string | null;
          user_id: string | null;
          nfc_capable: boolean;
          camera_capable: boolean;
          printer_capable: boolean;
          last_seen_at: string | null;
          last_sync_at: string | null;
          status: string;
          is_suggested_as_default: boolean;
          created_at: string;
          updated_at: string;
        };
      };
      customers: {
        Row: {
          id: string;
          uuid: string;
          global_id: string;
          name: string;
          phone: string | null;
          email: string | null;
          date_of_birth: string | null;
          gender: string | null;
          notes: string | null;
          tags: string | null;
          preferences: string | null;
          consent_whatsapp: boolean;
          consent_email: boolean;
          consent_sms: boolean;
          consent_marketing: boolean;
          marketing_opt_out: boolean;
          created_at: string;
          updated_at: string;
          first_visit_at: string | null;
          last_visit_at: string | null;
          total_visits: number;
          total_spending: number;
          average_order_value: number;
          lifetime_value: number;
          loyalty_points_balance: number;
          loyalty_stamps_count: number;
          loyalty_visits_count: number;
          deleted_at: string | null;
        };
      };
      customer_business_memberships: {
        Row: {
          id: string;
          uuid: string;
          customer_id: string;
          business_id: string;
          membership_identifier: string;
          joined_at: string;
          referral_code: string | null;
          referred_by: string | null;
          first_visit_at: string | null;
          last_visit_at: string | null;
          total_visits: number;
          total_spending: number;
          loyalty_points_earned: number;
          loyalty_points_redeemed: number;
          current_points_balance: number;
          current_stamps_count: number;
          current_visits_count: number;
          membership_status: string;
          created_at: string;
          updated_at: string;
          deleted_at: string | null;
        };
      };
      product_categories: {
        Row: {
          id: string;
          uuid: string;
          business_id: string;
          name: string;
          name_arabic: string | null;
          name_english: string | null;
          parent_id: string | null;
          image_url: string | null;
          sort_order: number;
          is_active: boolean;
          created_at: string;
          updated_at: string;
          deleted_at: string | null;
        };
      };
      products: {
        Row: {
          id: string;
          uuid: string;
          business_id: string;
          category_id: string | null;
          supplier_id: string | null;
          name: string;
          name_arabic: string | null;
          name_english: string | null;
          description: string | null;
          description_arabic: string | null;
          description_english: string | null;
          sku: string | null;
          barcode: string | null;
          image_url: string | null;
          cost: number | null;
          selling_price: number;
          discount_amount: number | null;
          discount_type: string | null;
          tax_rate: number | null;
          tax_name: string | null;
          stock_quantity: number | null;
          minimum_stock: number | null;
          reorder_quantity: number | null;
          unit: string | null;
          weight: number | null;
          dimensions_length: number | null;
          dimensions_width: number | null;
          dimensions_height: number | null;
          is_active: boolean;
          is_variant: boolean;
          variant_parent_id: string | null;
          loyalty_eligible: boolean;
          loyalty_points_rate: number | null;
          sort_order: number;
          created_at: string;
          updated_at: string;
          deleted_at: string | null;
        };
      };
      product_variants: {
        Row: {
          id: string;
          uuid: string;
          product_id: string;
          name: string;
          sku: string | null;
          barcode: string | null;
          image_url: string | null;
          selling_price: number;
          stock_quantity: number | null;
          attributes: string | null;
          is_active: boolean;
          created_at: string;
          updated_at: string;
        };
      };
      services: {
        Row: {
          id: string;
          uuid: string;
          business_id: string;
          category_id: string | null;
          name: string;
          name_arabic: string | null;
          name_english: string | null;
          description: string | null;
          price: number;
          duration_minutes: number | null;
          staff_id: string | null;
          tax_rate: number | null;
          loyalty_eligible: boolean;
          is_active: boolean;
          sort_order: number;
          created_at: string;
          updated_at: string;
          deleted_at: string | null;
        };
      };
      inventory: {
        Row: {
          id: string;
          uuid: string;
          business_id: string;
          product_id: string;
          warehouse_location: string | null;
          quantity_on_hand: number;
          quantity_reserved: number;
          quantity_available: number;
          quantity_on_order: number;
          last_counted_at: string | null;
          created_at: string;
          updated_at: string;
        };
      };
      inventory_movements: {
        Row: {
          id: string;
          uuid: string;
          business_id: string;
          inventory_id: string;
          product_id: string;
          type: string;
          quantity_change: number;
          reference_type: string | null;
          reference_id: string | null;
          reason: string | null;
          performed_by: string;
          performed_at: string;
          created_at: string;
        };
      };
      suppliers: {
        Row: {
          id: string;
          uuid: string;
          business_id: string;
          name: string;
          contact_name: string | null;
          phone: string | null;
          email: string | null;
          address_line1: string | null;
          address_line2: string | null;
          city: string | null;
          state: string | null;
          country: string | null;
          postal_code: string | null;
          notes: string | null;
          created_at: string;
          updated_at: string;
          deleted_at: string | null;
        };
      };
    };
  };
};
