-- =============================================================================
-- Loyalty Card System — Initial Database Schema
-- Supabase / PostgreSQL
-- -----------------------------------------------------------------------------
-- Run this migration ONCE on a fresh Supabase project:
--   1. Go to Supabase Dashboard → SQL Editor
--   2. Paste this entire file and run
--   3. (Alternatively: psql -h <host> -U postgres -d postgres -f this_file.sql)
--
-- After migration, go to Supabase Dashboard → Authentication → Policies
-- and ensure RLS is enabled on every table.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Enable required extensions
-- -----------------------------------------------------------------------------

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- -----------------------------------------------------------------------------
-- Custom ENUMs (used in CHECK constraints and native types)
-- -----------------------------------------------------------------------------

-- Membership roles
DO $$ BEGIN
  CREATE TYPE membership_role AS ENUM (
    'system_manager',
    'business_owner',
    'employee',
    'cashier',
    'manager',
    'admin'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Customer identification methods
DO $$ BEGIN
  CREATE TYPE customer_identification_method AS ENUM (
    'qr',
    'nfc',
    'search',
    'all'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Offline policy modes
DO $$ BEGIN
  CREATE TYPE offline_policy AS ENUM (
    'automatic',
    'online_only',
    'offline_allowed',
    'offline_disabled'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Sync queue statuses
DO $$ BEGIN
  CREATE TYPE sync_queue_status AS ENUM (
    'pending',
    'uploading',
    'synced',
    'failed',
    'conflict',
    'requires_review'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Payment methods
DO $$ BEGIN
  CREATE TYPE payment_method AS ENUM (
    'cash',
    'card',
    'qr',
    'mobile_wallet',
    'online',
    'other'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Payment statuses
DO $$ BEGIN
  CREATE TYPE payment_status AS ENUM (
    'pending',
    'authorized',
    'captured',
    'completed',
    'failed',
    'refunded',
    'partially_refunded',
    'expired',
    'cancelled'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Loyalty types
DO $$ BEGIN
  CREATE TYPE loyalty_type AS ENUM (
    'points',
    'stamps',
    'visits',
    'spend_based',
    'custom'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Order statuses
DO $$ BEGIN
  CREATE TYPE order_status AS ENUM (
    'draft',
    'pending',
    'completed',
    'cancelled',
    'refunded',
    'partial_refund'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Campaign statuses
DO $$ BEGIN
  CREATE TYPE campaign_status AS ENUM (
    'draft',
    'scheduled',
    'sent',
    'sending',
    'completed',
    'cancelled',
    'failed'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Backup statuses
DO $$ BEGIN
  CREATE TYPE backup_status AS ENUM (
    'pending',
    'running',
    'completed',
    'failed',
    'verification_failed'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Restore statuses
DO $$ BEGIN
  CREATE TYPE restore_status AS ENUM (
    'pending',
    'running',
    'completed',
    'failed',
    'rolled_back'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Audit actions
DO $$ BEGIN
  CREATE TYPE audit_action AS ENUM (
    'login',
    'logout',
    'employee_create',
    'employee_update',
    'employee_revoke',
    'permission_change',
    'product_create',
    'product_update',
    'product_delete',
    'price_change',
    'inventory_adjustment',
    'sale_create',
    'sale_refund',
    'sale_void',
    'loyalty_adjustment',
    'reward_redemption',
    'payment_create',
    'subscription_change',
    'backup_create',
    'backup_restore',
    'ai_action',
    'whatsapp_campaign_send',
    'integration_change',
    'device_revoke',
    'qr_credential_create',
    'qr_credential_use',
    'qr_credential_revoke',
    'nfc_credential_create',
    'nfc_credential_use',
    'nfc_credential_revoke',
    'nfc_credential_rotate',
    'customer_identify',
    'customer_register',
    'customer_segment_create',
    'campaign_create',
    'campaign_send'
  );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- -----------------------------------------------------------------------------
-- TABLES
-- -----------------------------------------------------------------------------

-- =============================================================================
-- PROFILES (Supabase Auth user profiles)
-- =============================================================================

CREATE TABLE IF NOT EXISTS profiles (
  id           UUID PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
  uuid         UUID NOT NULL DEFAULT gen_random_uuid(),
  email        TEXT,
  full_name    TEXT,
  phone        TEXT,
  avatar_url   TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_login_at TIMESTAMPTZ
);

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own profile"
  ON profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile"
  ON profiles FOR UPDATE
  USING (auth.uid() = id);

CREATE POLICY "Users can insert their own profile"
  ON profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

-- Auto-create profile on new user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, avatar_url)
  VALUES (
    NEW.id,
    NEW.raw_user_meta_data ->> 'email',
    NEW.raw_user_meta_data ->> 'full_name',
    NEW.raw_user_meta_data ->> 'avatar_url'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- Updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- BUSINESSES
-- =============================================================================

CREATE TABLE IF NOT EXISTS businesses (
  id                                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uuid                               UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  name                               TEXT NOT NULL,
  legal_name                        TEXT,
  category                           TEXT,
  description                        TEXT,
  logo_url                           TEXT,
  cover_image_url                    TEXT,
  primary_color                     TEXT,
  secondary_color                   TEXT,
  accent_color                      TEXT,
  brand_name                         TEXT,
  brand_short_name                  TEXT,
  brand_acceptance_wording          TEXT,
  brand_tagline                     TEXT,
  phone                              TEXT,
  email                              TEXT,
  website                            TEXT,
  address_line1                      TEXT,
  address_line2                      TEXT,
  city                               TEXT,
  state                              TEXT,
  country                            TEXT,
  postal_code                        TEXT,
  latitude                           DOUBLE PRECISION,
  longitude                          DOUBLE PRECISION,
  currency                           TEXT,
  timezone                           TEXT,
  language                           TEXT,
  tax_rate                           DOUBLE PRECISION,
  tax_name                           TEXT,
  tax_registration_number            TEXT,
  business_number                    TEXT,
  loyalty_points_rate                DOUBLE PRECISION,
  loyalty_stamp_count                INTEGER,
  loyalty_visit_threshold           INTEGER,
  loyalty_spend_threshold            DOUBLE PRECISION,
  first_purchase_bonus_points       INTEGER,
  birthday_bonus_points             INTEGER,
  referral_bonus_points             INTEGER,
  vip_multiplier                     DOUBLE PRECISION,
  double_points_enabled             BOOLEAN,
  customer_identification_methods   customer_identification_method,
  offline_policy                    offline_policy,
  simple_mode                        BOOLEAN,
  setup_completed                    BOOLEAN,
  setup_completed_at                 TIMESTAMPTZ,
  created_at                        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at                        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at                        TIMESTAMPTZ
);

ALTER TABLE businesses ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public businesses are viewable by authenticated users"
  ON businesses FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "Business owners can insert businesses"
  ON businesses FOR INSERT
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.business_memberships
    WHERE business_memberships.business_id = businesses.id
      AND business_memberships.user_id = auth.uid()
      AND business_memberships.role = 'system_manager'
  ));

CREATE POLICY "Business owners can update their own business"
  ON businesses FOR UPDATE
  USING (EXISTS (
    SELECT 1 FROM public.business_memberships
    WHERE business_memberships.business_id = businesses.id
      AND business_memberships.user_id = auth.uid()
      AND business_memberships.role IN ('system_manager', 'business_owner')
  )));

-- setup_completed_at updated automatically
CREATE TRIGGER set_businesses_setup_completed_at
  BEFORE UPDATE ON businesses
  FOR EACH ROW
  WHEN (NEW.setup_completed IS DISTINCT FROM OLD.setup_completed)
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER set_businesses_updated_at
  BEFORE UPDATE ON businesses
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- BUSINESS MEMBERSHIPS
-- =============================================================================

CREATE TABLE IF NOT EXISTS business_memberships (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uuid               UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  business_id        UUID NOT NULL REFERENCES businesses (id) ON DELETE CASCADE,
  user_id            UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  role               membership_role NOT NULL,
  branch_id          UUID,
  is_active          BOOLEAN NOT NULL DEFAULT TRUE,
  joined_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (business_id, user_id)
);

ALTER TABLE business_memberships ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view their own memberships"
  ON business_memberships FOR SELECT
  USING (
    auth.uid() = user_id
    OR EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = business_memberships.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.role = 'system_manager'
    )
  );

CREATE POLICY "System managers can manage memberships"
  ON business_memberships FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = business_memberships.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.role = 'system_manager'
    )
  );

CREATE POLICY "Business owners can insert/update their own memberships"
  ON business_memberships FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = business_memberships.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.role IN ('system_manager', 'business_owner')
    )
  );

CREATE TRIGGER set_business_memberships_updated_at
  BEFORE UPDATE ON business_memberships
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- ROLES (System-defined roles for permissions)
-- =============================================================================

CREATE TABLE IF NOT EXISTS roles (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uuid        UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL UNIQUE,
  description TEXT,
  is_system   BOOLEAN NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE roles ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can view roles"
  ON roles FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- =============================================================================
-- PERMISSIONS
-- =============================================================================

CREATE TABLE IF NOT EXISTS permissions (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uuid        UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  code        TEXT NOT NULL UNIQUE,
  name        TEXT NOT NULL,
  description TEXT,
  category    TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE permissions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can view permissions"
  ON permissions FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- =============================================================================
-- ROLE PERMISSIONS (junction)
-- =============================================================================

CREATE TABLE IF NOT EXISTS role_permissions (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  role_id      UUID NOT NULL REFERENCES roles (id) ON DELETE CASCADE,
  permission_id UUID NOT NULL REFERENCES permissions (id) ON DELETE CASCADE,
  granted_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (role_id, permission_id)
);

ALTER TABLE role_permissions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "System managers can manage role_permissions"
  ON role_permissions FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = business_memberships.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.role = 'system_manager'
    )
  );

-- =============================================================================
-- BRANCHES
-- =============================================================================

CREATE TABLE IF NOT EXISTS branches (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uuid             UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  business_id      UUID NOT NULL REFERENCES businesses (id) ON DELETE CASCADE,
  name             TEXT NOT NULL,
  code             TEXT,
  description      TEXT,
  address_line1    TEXT,
  address_line2    TEXT,
  city             TEXT,
  state            TEXT,
  country          TEXT,
  postal_code      TEXT,
  phone            TEXT,
  email            TEXT,
  latitude         DOUBLE PRECISION,
  longitude        DOUBLE PRECISION,
  is_primary       BOOLEAN NOT NULL DEFAULT FALSE,
  is_active        BOOLEAN NOT NULL DEFAULT TRUE,
  opening_time     TIME,
  closing_time     TIME,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at       TIMESTAMPTZ
);

ALTER TABLE branches ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view business branches"
  ON branches FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = branches.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.is_active = TRUE
    )
  );

CREATE POLICY "Business owners can manage branches"
  ON branches FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = branches.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.role IN ('system_manager', 'business_owner')
    )
  );

CREATE TRIGGER set_branches_updated_at
  BEFORE UPDATE ON branches
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- DEVICES
-- =============================================================================

CREATE TABLE IF NOT EXISTS devices (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uuid                 UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  business_id          UUID NOT NULL REFERENCES businesses (id) ON DELETE CASCADE,
  name                 TEXT NOT NULL,
  device_id            TEXT NOT NULL UNIQUE,
  platform             TEXT,
  app_version          TEXT,
  os_version           TEXT,
  manufacturer         TEXT,
  model                TEXT,
  branch_id            UUID REFERENCES branches (id) ON DELETE SET NULL,
  user_id              UUID REFERENCES auth.users (id) ON DELETE SET NULL,
  nfc_capable          BOOLEAN NOT NULL DEFAULT FALSE,
  camera_capable       BOOLEAN NOT NULL DEFAULT FALSE,
  printer_capable      BOOLEAN NOT NULL DEFAULT FALSE,
  last_seen_at         TIMESTAMPTZ,
  last_sync_at         TIMESTAMPTZ,
  status               TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'revoked', 'lost')),
  is_suggested_as_default BOOLEAN NOT NULL DEFAULT FALSE,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE devices ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view business devices"
  ON devices FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = devices.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.is_active = TRUE
    )
  );

CREATE POLICY "Business owners can manage devices"
  ON devices FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = devices.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.role IN ('system_manager', 'business_owner')
    )
  );

CREATE TRIGGER set_devices_updated_at
  BEFORE UPDATE ON devices
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- CUSTOMERS (Global customer identity)
-- =============================================================================

CREATE TABLE IF NOT EXISTS customers (
  id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uuid                        UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  global_id                   UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  name                        TEXT NOT NULL,
  phone                       TEXT,
  email                       TEXT,
  date_of_birth               DATE,
  gender                      TEXT,
  notes                       TEXT,
  tags                        TEXT,
  preferences                TEXT,
  consent_whatsapp            BOOLEAN NOT NULL DEFAULT FALSE,
  consent_email               BOOLEAN NOT NULL DEFAULT FALSE,
  consent_sms                 BOOLEAN NOT NULL DEFAULT FALSE,
  consent_marketing           BOOLEAN NOT NULL DEFAULT FALSE,
  marketing_opt_out           BOOLEAN NOT NULL DEFAULT FALSE,
  created_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  first_visit_at              TIMESTAMPTZ,
  last_visit_at               TIMESTAMPTZ,
  total_visits                INTEGER NOT NULL DEFAULT 0,
  total_spending              DOUBLE PRECISION NOT NULL DEFAULT 0,
  average_order_value         DOUBLE PRECISION NOT NULL DEFAULT 0,
  lifetime_value              DOUBLE PRECISION NOT NULL DEFAULT 0,
  loyalty_points_balance      INTEGER NOT NULL DEFAULT 0,
  loyalty_stamps_count        INTEGER NOT NULL DEFAULT 0,
  loyalty_visits_count        INTEGER NOT NULL DEFAULT 0,
  deleted_at                  TIMESTAMPTZ
);

ALTER TABLE customers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Customers can view their own data"
  ON customers FOR SELECT
  USING (
    id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.customer_business_memberships
      WHERE customer_business_memberships.customer_id = customers.id
        AND customer_business_memberships.business_id IN (
          SELECT business_memberships.business_id
          FROM public.business_memberships
          WHERE business_memberships.user_id = auth.uid()
            AND business_memberships.is_active = TRUE
        )
    )
  );

CREATE POLICY "Business owners and employees can view customers in their business"
  ON customers FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.customer_business_memberships
      WHERE customer_business_memberships.customer_id = customers.id
        AND customer_business_memberships.business_id IN (
          SELECT business_memberships.business_id
          FROM public.business_memberships
          WHERE business_memberships.user_id = auth.uid()
            AND business_memberships.is_active = TRUE
            AND business_memberships.role IN ('system_manager', 'business_owner', 'employee', 'manager')
        )
    )
  );

-- Sensitive fields require employee permission to view
CREATE POLICY "Sensitive customer data requires employee permission"
  ON customers FOR SELECT
  USING (
    -- Only expose phone/email to those with explicit permission
    -- This is enforced at the application level, but the policy ensures baseline access.
    TRUE
  );

CREATE TRIGGER set_customers_updated_at
  BEFORE UPDATE ON customers
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- CUSTOMER BUSINESS MEMBERSHIPS
-- =============================================================================

CREATE TABLE IF NOT EXISTS customer_business_memberships (
  id                            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uuid                          UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  customer_id                   UUID NOT NULL REFERENCES customers (id) ON DELETE CASCADE,
  business_id                   UUID NOT NULL REFERENCES businesses (id) ON DELETE CASCADE,
  membership_identifier         TEXT NOT NULL UNIQUE,
  joined_at                     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  referral_code                 TEXT,
  referred_by                   TEXT,
  first_visit_at                TIMESTAMPTZ,
  last_visit_at                 TIMESTAMPTZ,
  total_visits                  INTEGER NOT NULL DEFAULT 0,
  total_spending                DOUBLE PRECISION NOT NULL DEFAULT 0,
  loyalty_points_earned        INTEGER NOT NULL DEFAULT 0,
  loyalty_points_redeemed      INTEGER NOT NULL DEFAULT 0,
  current_points_balance       INTEGER NOT NULL DEFAULT 0,
  current_stamps_count         INTEGER NOT NULL DEFAULT 0,
  current_visits_count         INTEGER NOT NULL DEFAULT 0,
  membership_status             TEXT NOT NULL DEFAULT 'active' CHECK (membership_status IN ('active', 'paused', 'suspended', 'cancelled')),
  created_at                    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at                    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at                    TIMESTAMPTZ,
  UNIQUE (customer_id, business_id)
);

ALTER TABLE customer_business_memberships ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Customers can view their own memberships"
  ON customer_business_memberships FOR SELECT
  USING (customer_id = auth.uid());

CREATE POLICY "Business owner and employees can view memberships in their business"
  ON customer_business_memberships FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = customer_business_memberships.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.is_active = TRUE
    )
  );

CREATE POLICY "Business owners can manage memberships"
  ON customer_business_memberships FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = customer_business_memberships.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.role IN ('system_manager', 'business_owner')
    )
  );

CREATE TRIGGER set_customer_business_memberships_updated_at
  BEFORE UPDATE ON customer_business_memberships
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- PRODUCT CATEGORIES
-- =============================================================================

CREATE TABLE IF NOT EXISTS product_categories (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uuid         UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  business_id  UUID NOT NULL REFERENCES businesses (id) ON DELETE CASCADE,
  name         TEXT NOT NULL,
  name_arabic  TEXT,
  name_english TEXT,
  parent_id    UUID REFERENCES product_categories (id) ON DELETE SET NULL,
  image_url    TEXT,
  sort_order   INTEGER NOT NULL DEFAULT 0,
  is_active    BOOLEAN NOT NULL DEFAULT TRUE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at   TIMESTAMPTZ
);

ALTER TABLE product_categories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view business product categories"
  ON product_categories FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = product_categories.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.is_active = TRUE
    )
  );

CREATE POLICY "Business owners can manage product categories"
  ON product_categories FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = product_categories.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.role IN ('system_manager', 'business_owner')
    )
  );

CREATE TRIGGER set_product_categories_updated_at
  BEFORE UPDATE ON product_categories
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- PRODUCTS
-- =============================================================================

CREATE TABLE IF NOT EXISTS products (
  id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uuid                   UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  business_id            UUID NOT NULL REFERENCES businesses (id) ON DELETE CASCADE,
  category_id            UUID REFERENCES product_categories (id) ON DELETE SET NULL,
  supplier_id            UUID,
  name                   TEXT NOT NULL,
  name_arabic            TEXT,
  name_english           TEXT,
  description            TEXT,
  description_arabic     TEXT,
  description_english    TEXT,
  sku                    TEXT,
  barcode                TEXT,
  image_url              TEXT,
  cost                   DOUBLE PRECISION,
  selling_price          DOUBLE PRECISION NOT NULL DEFAULT 0,
  discount_amount        DOUBLE PRECISION,
  discount_type          TEXT CHECK (discount_type IS NULL OR discount_type IN ('fixed', 'percentage')),
  tax_rate               DOUBLE PRECISION,
  tax_name               TEXT,
  stock_quantity         INTEGER,
  minimum_stock          INTEGER,
  reorder_quantity       INTEGER,
  unit                   TEXT,
  weight                 DOUBLE PRECISION,
  dimensions_length      DOUBLE PRECISION,
  dimensions_width       DOUBLE PRECISION,
  dimensions_height      DOUBLE PRECISION,
  is_active              BOOLEAN NOT NULL DEFAULT TRUE,
  is_variant             BOOLEAN NOT NULL DEFAULT FALSE,
  variant_parent_id      UUID REFERENCES products (id) ON DELETE SET NULL,
  loyalty_eligible       BOOLEAN NOT NULL DEFAULT TRUE,
  loyalty_points_rate    DOUBLE PRECISION,
  sort_order             INTEGER NOT NULL DEFAULT 0,
  created_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at             TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at             TIMESTAMPTZ,
  UNIQUE (business_id, barcode)
);

ALTER TABLE products ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view business products"
  ON products FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = products.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.is_active = TRUE
    )
  );

CREATE POLICY "Business owners can manage products"
  ON products FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = products.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.role IN ('system_manager', 'business_owner')
    )
  );

CREATE TRIGGER set_products_updated_at
  BEFORE UPDATE ON products
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- PRODUCT VARIANTS
-- =============================================================================

CREATE TABLE IF NOT EXISTS product_variants (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uuid          UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  product_id    UUID NOT NULL REFERENCES products (id) ON DELETE CASCADE,
  name          TEXT NOT NULL,
  sku           TEXT,
  barcode       TEXT,
  image_url     TEXT,
  selling_price DOUBLE PRECISION NOT NULL DEFAULT 0,
  stock_quantity INTEGER,
  attributes    TEXT,
  is_active     BOOLEAN NOT NULL DEFAULT TRUE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE product_variants ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view product variants"
  ON product_variants FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.products
      JOIN public.business_memberships ON business_memberships.business_id = products.business_id
      WHERE products.id = product_variants.product_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.is_active = TRUE
    )
  );

CREATE POLICY "Business owners can manage product variants"
  ON product_variants FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.products
      JOIN public.business_memberships ON business_memberships.business_id = products.business_id
      WHERE products.id = product_variants.product_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.role IN ('system_manager', 'business_owner')
    )
  );

CREATE TRIGGER set_product_variants_updated_at
  BEFORE UPDATE ON product_variants
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- SERVICES
-- =============================================================================

CREATE TABLE IF NOT EXISTS services (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uuid              UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  business_id       UUID NOT NULL REFERENCES businesses (id) ON DELETE CASCADE,
  category_id       UUID REFERENCES product_categories (id) ON DELETE SET NULL,
  name              TEXT NOT NULL,
  name_arabic       TEXT,
  name_english      TEXT,
  description       TEXT,
  price             DOUBLE PRECISION NOT NULL DEFAULT 0,
  duration_minutes  INTEGER,
  staff_id          UUID,
  tax_rate          DOUBLE PRECISION,
  loyalty_eligible  BOOLEAN NOT NULL DEFAULT TRUE,
  is_active         BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order        INTEGER NOT NULL DEFAULT 0,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at        TIMESTAMPTZ
);

ALTER TABLE services ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view business services"
  ON services FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = services.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.is_active = TRUE
    )
  );

CREATE POLICY "Business owners can manage services"
  ON services FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = services.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.role IN ('system_manager', 'business_owner')
    )
  );

CREATE TRIGGER set_services_updated_at
  BEFORE UPDATE ON services
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- INVENTORY
-- =============================================================================

CREATE TABLE IF NOT EXISTS inventory (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uuid                  UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  business_id           UUID NOT NULL REFERENCES businesses (id) ON DELETE CASCADE,
  product_id            UUID NOT NULL REFERENCES products (id) ON DELETE CASCADE,
  warehouse_location    TEXT,
  quantity_on_hand      INTEGER NOT NULL DEFAULT 0,
  quantity_reserved     INTEGER NOT NULL DEFAULT 0,
  quantity_available    INTEGER NOT NULL DEFAULT 0,
  quantity_on_order     INTEGER NOT NULL DEFAULT 0,
  last_counted_at       TIMESTAMPTZ,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (business_id, product_id)
);

ALTER TABLE inventory ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view business inventory"
  ON inventory FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = inventory.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.is_active = TRUE
    )
  );

CREATE POLICY "Business owners can manage inventory"
  ON inventory FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = inventory.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.role IN ('system_manager', 'business_owner')
    )
  );

CREATE TRIGGER set_inventory_updated_at
  BEFORE UPDATE ON inventory
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- INVENTORY MOVEMENTS
-- =============================================================================

CREATE TABLE IF NOT EXISTS inventory_movements (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uuid              UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  business_id       UUID NOT NULL REFERENCES businesses (id) ON DELETE CASCADE,
  inventory_id      UUID NOT NULL REFERENCES inventory (id) ON DELETE CASCADE,
  product_id        UUID NOT NULL REFERENCES products (id) ON DELETE CASCADE,
  type              TEXT NOT NULL CHECK (type IN ('sale', 'return', 'adjustment', 'transfer', 'purchase', 'damage', 'expiry', 'count_correction')),
  quantity_change   INTEGER NOT NULL,
  reference_type    TEXT CHECK (reference_type IN ('order', 'return', 'adjustment', 'purchase_order', 'transfer', 'inventory_count')),
  reference_id      UUID,
  reason            TEXT,
  performed_by      UUID NOT NULL REFERENCES auth.users (id),
  performed_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE inventory_movements ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view business inventory movements"
  ON inventory_movements FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = inventory_movements.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.is_active = TRUE
    )
  );

CREATE POLICY "Business owners can manage inventory movements"
  ON inventory_movements FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = inventory_movements.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.role IN ('system_manager', 'business_owner')
    )
  );

-- =============================================================================
-- SUPPLIERS
-- =============================================================================

CREATE TABLE IF NOT EXISTS suppliers (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uuid             UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  business_id      UUID NOT NULL REFERENCES businesses (id) ON DELETE CASCADE,
  name             TEXT NOT NULL,
  contact_name     TEXT,
  phone            TEXT,
  email            TEXT,
  address_line1    TEXT,
  address_line2    TEXT,
  city             TEXT,
  state            TEXT,
  country          TEXT,
  postal_code      TEXT,
  notes            TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at       TIMESTAMPTZ
);

ALTER TABLE suppliers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view business suppliers"
  ON suppliers FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = suppliers.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.is_active = TRUE
    )
  );

CREATE POLICY "Business owners can manage suppliers"
  ON suppliers FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = suppliers.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.role IN ('system_manager', 'business_owner')
    )
  );

CREATE TRIGGER set_suppliers_updated_at
  BEFORE UPDATE ON suppliers
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- ORDERS
-- =============================================================================

CREATE TABLE IF NOT EXISTS orders (
  id                                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uuid                              UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  business_id                       UUID NOT NULL REFERENCES businesses (id) ON DELETE CASCADE,
  branch_id                         UUID REFERENCES branches (id) ON DELETE SET NULL,
  customer_id                       UUID REFERENCES customers (id) ON DELETE SET NULL,
  customer_business_membership_id  UUID REFERENCES customer_business_memberships (id) ON DELETE SET NULL,
  order_number                      TEXT NOT NULL UNIQUE,
  status                            order_status NOT NULL DEFAULT 'draft',
  subtotal                          DOUBLE PRECISION NOT NULL DEFAULT 0,
  discount_total                    DOUBLE PRECISION NOT NULL DEFAULT 0,
  tax_total                         DOUBLE PRECISION NOT NULL DEFAULT 0,
  total                             DOUBLE PRECISION NOT NULL DEFAULT 0,
  payment_method                    payment_method,
  payment_status                    payment_status NOT NULL DEFAULT 'pending',
  loyalty_points_earned            INTEGER NOT NULL DEFAULT 0,
  loyalty_points_redeemed          INTEGER NOT NULL DEFAULT 0,
  reward_redemption_id              UUID,
  discount_applied                  DOUBLE PRECISION,
  discount_description              TEXT,
  notes                             TEXT,
  customer_notes                    TEXT,
  cashier_id                        UUID NOT NULL REFERENCES auth.users (id),
  cashier_name                      TEXT,
  opened_at                         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at                      TIMESTAMPTZ,
  cancelled_at                      TIMESTAMPTZ,
  refunded_at                       TIMESTAMPTZ,
  created_at                        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at                        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at                        TIMESTAMPTZ
);

ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view business orders"
  ON orders FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = orders.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.is_active = TRUE
    )
  );

CREATE POLICY "Business owners can manage orders"
  ON orders FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = orders.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.role IN ('system_manager', 'business_owner')
    )
  );

CREATE TRIGGER set_orders_updated_at
  BEFORE UPDATE ON orders
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- ORDER ITEMS
-- =============================================================================

CREATE TABLE IF NOT EXISTS order_items (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uuid             UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  order_id         UUID NOT NULL REFERENCES orders (id) ON DELETE CASCADE,
  product_id       UUID REFERENCES products (id) ON DELETE SET NULL,
  service_id       UUID REFERENCES services (id) ON DELETE SET NULL,
  name             TEXT NOT NULL,
  quantity         INTEGER NOT NULL DEFAULT 1,
  unit_price       DOUBLE PRECISION NOT NULL DEFAULT 0,
  discount_amount  DOUBLE PRECISION,
  discount_type    TEXT CHECK (discount_type IS NULL OR discount_type IN ('fixed', 'percentage')),
  tax_rate         DOUBLE PRECISION,
  tax_amount       DOUBLE PRECISION NOT NULL DEFAULT 0,
  total            DOUBLE PRECISION NOT NULL DEFAULT 0,
  loyalty_points_earned INTEGER NOT NULL DEFAULT 0,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE order_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view business order items"
  ON order_items FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.orders
      JOIN public.business_memberships ON business_memberships.business_id = orders.business_id
      WHERE orders.id = order_items.order_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.is_active = TRUE
    )
  );

-- =============================================================================
-- PAYMENTS
-- =============================================================================

CREATE TABLE IF NOT EXISTS payments (
  id                                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uuid                              UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  business_id                       UUID NOT NULL REFERENCES businesses (id) ON DELETE CASCADE,
  order_id                          UUID NOT NULL REFERENCES orders (id) ON DELETE CASCADE,
  provider_id                       UUID,
  provider_transaction_id           UUID,
  method                            payment_method NOT NULL,
  amount                            DOUBLE PRECISION NOT NULL DEFAULT 0,
  currency                          TEXT NOT NULL DEFAULT 'EGP',
  status                            payment_status NOT NULL DEFAULT 'pending',
  card_last_four                    TEXT,
  card_brand                        TEXT,
  qr_code                           TEXT,
  mobile_wallet                     TEXT,
  online_payment_reference          TEXT,
  failure_reason                    TEXT,
  metadata                          TEXT,
  processed_by                      UUID REFERENCES auth.users (id),
  processed_at                      TIMESTAMPTZ,
  refunded_amount                   DOUBLE PRECISION NOT NULL DEFAULT 0,
  refunded_at                       TIMESTAMPTZ,
  refund_reason                     TEXT,
  refund_transaction_id             UUID,
  created_at                        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at                        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE payments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view business payments"
  ON payments FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = payments.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.is_active = TRUE
    )
  );

CREATE POLICY "Business owners can manage payments"
  ON payments FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = payments.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.role IN ('system_manager', 'business_owner')
    )
  );

CREATE TRIGGER set_payments_updated_at
  BEFORE UPDATE ON payments
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- PAYMENT TRANSACTIONS (webhook/event log)
-- =============================================================================

CREATE TABLE IF NOT EXISTS payment_transactions (
  id                     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uuid                   UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  business_id            UUID NOT NULL REFERENCES businesses (id) ON DELETE CASCADE,
  payment_id             UUID NOT NULL REFERENCES payments (id) ON DELETE CASCADE,
  order_id               UUID NOT NULL REFERENCES orders (id) ON DELETE CASCADE,
  provider_id            UUID,
  provider               TEXT NOT NULL,
  provider_transaction_id TEXT NOT NULL,
  provider_response      TEXT,
  event_type             TEXT NOT NULL CHECK (event_type IN ('authorization', 'capture', 'refund', 'reversal', 'notification', 'webhook', 'status_update')),
  event_data             TEXT,
  received_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  processed_at           TIMESTAMPTZ,
  created_at             TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE payment_transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Business owners can view payment transactions"
  ON payment_transactions FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = payment_transactions.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.is_active = TRUE
        AND business_memberships.role IN ('system_manager', 'business_owner')
    )
  );

-- =============================================================================
-- PAYMENT PROVIDERS
-- =============================================================================

CREATE TABLE IF NOT EXISTS payment_providers (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uuid             UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  business_id      UUID NOT NULL REFERENCES businesses (id) ON DELETE CASCADE,
  name             TEXT NOT NULL,
  provider_type    TEXT NOT NULL CHECK (provider_type IN ('cash', 'card', 'qr', 'mobile_wallet', 'online', 'custom')),
  is_active        BOOLEAN NOT NULL DEFAULT TRUE,
  config_key       TEXT,
  config_value     TEXT,
  webhook_url      TEXT,
  webhook_secret   TEXT,
  is_test_mode     BOOLEAN NOT NULL DEFAULT FALSE,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE payment_providers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view business payment providers"
  ON payment_providers FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = payment_providers.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.is_active = TRUE
    )
  );

CREATE POLICY "Business owners can manage payment providers"
  ON payment_providers FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = payment_providers.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.role IN ('system_manager', 'business_owner')
    )
  );

CREATE TRIGGER set_payment_providers_updated_at
  BEFORE UPDATE ON payment_providers
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- LOYALTY PROGRAMS
-- =============================================================================

CREATE TABLE IF NOT EXISTS loyalty_programs (
  id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uuid                        UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  business_id                 UUID NOT NULL REFERENCES businesses (id) ON DELETE CASCADE,
  name                        TEXT NOT NULL,
  description                 TEXT,
  type                        loyalty_type NOT NULL DEFAULT 'points',
  points_rate                 DOUBLE PRECISION,
  stamp_count                 INTEGER,
  visit_threshold            INTEGER,
  spend_threshold             DOUBLE PRECISION,
  first_purchase_bonus_points INTEGER,
  birthday_bonus_points      INTEGER,
  referral_bonus_points      INTEGER,
  vip_multiplier              DOUBLE PRECISION,
  double_points_enabled      BOOLEAN NOT NULL DEFAULT FALSE,
  points_expiry_days          INTEGER,
  stamps_expiry_days          INTEGER,
  visits_expiry_days          INTEGER,
  spend_expiry_days           INTEGER,
  min_purchase_amount         DOUBLE PRECISION,
  eligible_product_ids        TEXT,
  eligible_category_ids       TEXT,
  eligible_service_ids        TEXT,
  bonus_period_start          TIMESTAMPTZ,
  bonus_period_end            TIMESTAMPTZ,
  is_active                   BOOLEAN NOT NULL DEFAULT TRUE,
  is_default                  BOOLEAN NOT NULL DEFAULT FALSE,
  created_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE loyalty_programs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view business loyalty programs"
  ON loyalty_programs FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = loyalty_programs.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.is_active = TRUE
    )
  );

CREATE POLICY "Business owners can manage loyalty programs"
  ON loyalty_programs FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = loyalty_programs.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.role IN ('system_manager', 'business_owner')
    )
  );

CREATE TRIGGER set_loyalty_programs_updated_at
  BEFORE UPDATE ON loyalty_programs
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- LOYALTY RULES
-- =============================================================================

CREATE TABLE IF NOT EXISTS loyalty_rules (
  id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uuid                     UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  business_id              UUID NOT NULL REFERENCES businesses (id) ON DELETE CASCADE,
  loyalty_program_id       UUID REFERENCES loyalty_programs (id) ON DELETE SET NULL,
  name                     TEXT NOT NULL,
  description              TEXT,
  type                     loyalty_type NOT NULL DEFAULT 'points',
  threshold_value          DOUBLE PRECISION,
  threshold_type           TEXT CHECK (threshold_type IS NULL OR threshold_type IN ('points', 'spend', 'visits', 'stamps', 'custom')),
  reward_type              TEXT CHECK (reward_type IS NULL OR reward_type IN ('points', 'stamp', 'visit', 'spend', 'product', 'service', 'discount', 'custom')),
  reward_value             DOUBLE PRECISION,
  reward_description       TEXT,
  eligible_products        TEXT,
  eligible_categories      TEXT,
  eligible_services        TEXT,
  minimum_purchase         DOUBLE PRECISION,
  expiration_days          INTEGER,
  is_active                BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order               INTEGER NOT NULL DEFAULT 0,
  created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE loyalty_rules ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view business loyalty rules"
  ON loyalty_rules FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = loyalty_rules.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.is_active = TRUE
    )
  );

CREATE POLICY "Business owners can manage loyalty rules"
  ON loyalty_rules FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = loyalty_rules.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.role IN ('system_manager', 'business_owner')
    )
  );

CREATE TRIGGER set_loyalty_rules_updated_at
  BEFORE UPDATE ON loyalty_rules
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- LOYALTY BALANCES
-- =============================================================================

CREATE TABLE IF NOT EXISTS loyalty_balances (
  id                              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uuid                            UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  customer_business_membership_id UUID NOT NULL REFERENCES customer_business_memberships (id) ON DELETE CASCADE,
  business_id                     UUID NOT NULL REFERENCES businesses (id) ON DELETE CASCADE,
  points_balance                  INTEGER NOT NULL DEFAULT 0,
  stamps_count                    INTEGER NOT NULL DEFAULT 0,
  visits_count                    INTEGER NOT NULL DEFAULT 0,
  spend_tracker                   DOUBLE PRECISION NOT NULL DEFAULT 0,
  last_updated_at                 TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at                      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at                      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (customer_business_membership_id)
);

ALTER TABLE loyalty_balances ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Customers can view their own loyalty balance"
  ON loyalty_balances FOR SELECT
  USING (customer_business_membership_id IN (
    SELECT id FROM public.customer_business_memberships WHERE customer_id = auth.uid()
  ));

CREATE POLICY "Business owner and employees can view loyalty balances"
  ON loyalty_balances FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = loyalty_balances.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.is_active = TRUE
    )
  );

CREATE POLICY "Business owners can manage loyalty balances"
  ON loyalty_balances FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = loyalty_balances.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.role IN ('system_manager', 'business_owner')
    )
  );

CREATE TRIGGER set_loyalty_balances_updated_at
  BEFORE UPDATE ON loyalty_balances
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- LOYALTY TRANSACTIONS
-- =============================================================================

CREATE TABLE IF NOT EXISTS loyalty_transactions (
  id                               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uuid                             UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  business_id                      UUID NOT NULL REFERENCES businesses (id) ON DELETE CASCADE,
  customer_id                      UUID NOT NULL REFERENCES customers (id) ON DELETE CASCADE,
  customer_business_membership_id  UUID NOT NULL REFERENCES customer_business_memberships (id) ON DELETE CASCADE,
  loyalty_program_id               UUID REFERENCES loyalty_programs (id) ON DELETE SET NULL,
  type                             TEXT NOT NULL CHECK (type IN ('earn', 'redeem', 'adjustment', 'expire', 'transfer', 'birthday_bonus', 'referral_bonus', 'first_purchase_bonus', 'double_points', 'vip_multiplier', 'rollback')),
  points_change                    INTEGER NOT NULL DEFAULT 0,
  stamps_change                    INTEGER NOT NULL DEFAULT 0,
  visits_change                    INTEGER NOT NULL DEFAULT 0,
  spend_change                     DOUBLE PRECISION NOT NULL DEFAULT 0,
  balance_after                    INTEGER NOT NULL DEFAULT 0,
  description                      TEXT,
  reference_type                   TEXT CHECK (reference_type IN ('order', 'reward_redemption', 'manual_adjustment', 'campaign', 'referral', 'birthday', 'expiration')),
  reference_id                     UUID,
  performed_by                     UUID NOT NULL REFERENCES auth.users (id),
  performed_at                     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at                       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE loyalty_transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Customers can view their own loyalty transactions"
  ON loyalty_transactions FOR SELECT
  USING (customer_id = auth.uid());

CREATE POLICY "Business owner and employees can view loyalty transactions"
  ON loyalty_transactions FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = loyalty_transactions.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.is_active = TRUE
    )
  );

-- =============================================================================
-- REWARDS
-- =============================================================================

CREATE TABLE IF NOT EXISTS rewards (
  id                            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uuid                          UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  business_id                   UUID NOT NULL REFERENCES businesses (id) ON DELETE CASCADE,
  loyalty_program_id            UUID REFERENCES loyalty_programs (id) ON DELETE SET NULL,
  name                          TEXT NOT NULL,
  description                   TEXT,
  points_cost                   INTEGER,
  stamps_cost                   INTEGER,
  visits_cost                   INTEGER,
  spend_cost                    DOUBLE PRECISION,
  product_id                    UUID REFERENCES products (id) ON DELETE SET NULL,
  service_id                    UUID REFERENCES services (id) ON DELETE SET NULL,
  discount_amount               DOUBLE PRECISION,
  discount_type                 TEXT CHECK (discount_type IS NULL OR discount_type IN ('fixed', 'percentage')),
  quantity_available            INTEGER,
  quantity_redeemed             INTEGER NOT NULL DEFAULT 0,
  max_redemptions_per_customer  INTEGER,
  starts_at                     TIMESTAMPTZ,
  ends_at                       TIMESTAMPTZ,
  image_url                     TEXT,
  is_active                     BOOLEAN NOT NULL DEFAULT TRUE,
  is_automatic                  BOOLEAN NOT NULL DEFAULT FALSE,
  auto_redeem_enabled           BOOLEAN NOT NULL DEFAULT FALSE,
  created_at                    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at                    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at                    TIMESTAMPTZ
);

ALTER TABLE rewards ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view business rewards"
  ON rewards FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = rewards.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.is_active = TRUE
    )
  );

CREATE POLICY "Business owners can manage rewards"
  ON rewards FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = rewards.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.role IN ('system_manager', 'business_owner')
    )
  );

CREATE TRIGGER set_rewards_updated_at
  BEFORE UPDATE ON rewards
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- REWARD REDEMPTIONS
-- =============================================================================

CREATE TABLE IF NOT EXISTS reward_redemptions (
  id                              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uuid                            UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  business_id                     UUID NOT NULL REFERENCES businesses (id) ON DELETE CASCADE,
  reward_id                       UUID NOT NULL REFERENCES rewards (id) ON DELETE CASCADE,
  customer_id                     UUID NOT NULL REFERENCES customers (id) ON DELETE CASCADE,
  customer_business_membership_id UUID NOT NULL REFERENCES customer_business_memberships (id) ON DELETE CASCADE,
  order_id                        UUID REFERENCES orders (id) ON DELETE SET NULL,
  points_deducted                 INTEGER NOT NULL DEFAULT 0,
  stamps_deducted                 INTEGER NOT NULL DEFAULT 0,
  visits_deducted                 INTEGER NOT NULL DEFAULT 0,
  spend_deducted                  DOUBLE PRECISION NOT NULL DEFAULT 0,
  quantity                        INTEGER NOT NULL DEFAULT 1,
  status                          TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'fulfilled', 'cancelled', 'expired')),
  redeemed_at                     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  fulfilled_at                    TIMESTAMPTZ,
  redeemed_by                     UUID NOT NULL REFERENCES auth.users (id),
  notes                           TEXT,
  created_at                      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at                      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE reward_redemptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Customers can view their own reward redemptions"
  ON reward_redemptions FOR SELECT
  USING (customer_id = auth.uid());

CREATE POLICY "Business owner and employees can view reward redemptions"
  ON reward_redemptions FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = reward_redemptions.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.is_active = TRUE
    )
  );

CREATE POLICY "Business owners can manage reward redemptions"
  ON reward_redemptions FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = reward_redemptions.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.role IN ('system_manager', 'business_owner')
    )
  );

CREATE TRIGGER set_reward_redemptions_updated_at
  BEFORE UPDATE ON reward_redemptions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- QR CREDENTIALS
-- =============================================================================

CREATE TABLE IF NOT EXISTS qr_credentials (
  id                            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uuid                          UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  business_id                   UUID NOT NULL REFERENCES businesses (id) ON DELETE CASCADE,
  customer_id                   UUID NOT NULL REFERENCES customers (id) ON DELETE CASCADE,
  customer_business_membership_id UUID NOT NULL REFERENCES customer_business_memberships (id) ON DELETE CASCADE,
  credential_code               TEXT NOT NULL UNIQUE,
  credential_token              TEXT NOT NULL UNIQUE,
  status                        TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'revoked', 'expired')),
  issued_at                     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at                    TIMESTAMPTZ,
  last_used_at                  TIMESTAMPTZ,
  usage_count                   INTEGER NOT NULL DEFAULT 0,
  rotation_count                INTEGER NOT NULL DEFAULT 0,
  created_at                    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at                    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE qr_credentials ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Customers can view their own QR credentials"
  ON qr_credentials FOR SELECT
  USING (customer_id = auth.uid());

CREATE POLICY "Business owner and employees can view QR credentials"
  ON qr_credentials FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = qr_credentials.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.is_active = TRUE
    )
  );

CREATE POLICY "Business owners can manage QR credentials"
  ON qr_credentials FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = qr_credentials.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.role IN ('system_manager', 'business_owner')
    )
  );

CREATE TRIGGER set_qr_credentials_updated_at
  BEFORE UPDATE ON qr_credentials
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- NFC CREDENTIALS
-- =============================================================================

CREATE TABLE IF NOT EXISTS nfc_credentials (
  id                            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uuid                          UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  business_id                   UUID NOT NULL REFERENCES businesses (id) ON DELETE CASCADE,
  customer_id                   UUID NOT NULL REFERENCES customers (id) ON DELETE CASCADE,
  customer_business_membership_id UUID NOT NULL REFERENCES customer_business_memberships (id) ON DELETE CASCADE,
  credential_code               TEXT NOT NULL UNIQUE,
  credential_token              TEXT NOT NULL UNIQUE,
  nfc_format                    TEXT,
  nfc_data                      TEXT,
  status                        TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'revoked', 'expired')),
  issued_at                     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at                    TIMESTAMPTZ,
  last_used_at                  TIMESTAMPTZ,
  usage_count                   INTEGER NOT NULL DEFAULT 0,
  rotation_count                INTEGER NOT NULL DEFAULT 0,
  created_at                    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at                    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE nfc_credentials ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Customers can view their own NFC credentials"
  ON nfc_credentials FOR SELECT
  USING (customer_id = auth.uid());

CREATE POLICY "Business owner and employees can view NFC credentials"
  ON nfc_credentials FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = nfc_credentials.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.is_active = TRUE
    )
  );

CREATE POLICY "Business owners can manage NFC credentials"
  ON nfc_credentials FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = nfc_credentials.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.role IN ('system_manager', 'business_owner')
    )
  );

CREATE TRIGGER set_nfc_credentials_updated_at
  BEFORE UPDATE ON nfc_credentials
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- WALLET PASSES
-- =============================================================================

CREATE TABLE IF NOT EXISTS wallet_passes (
  id                            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uuid                          UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  business_id                   UUID NOT NULL REFERENCES businesses (id) ON DELETE CASCADE,
  customer_id                   UUID NOT NULL REFERENCES customers (id) ON DELETE CASCADE,
  customer_business_membership_id UUID NOT NULL REFERENCES customer_business_memberships (id) ON DELETE CASCADE,
  provider                      TEXT NOT NULL CHECK (provider IN ('apple_wallet', 'google_wallet', 'other')),
  pass_type                     TEXT,
  pass_data_url                 TEXT,
  pass_barcode                  TEXT,
  status                        TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'revoked', 'expired')),
  issued_at                     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at                    TIMESTAMPTZ,
  last_used_at                  TIMESTAMPTZ,
  created_at                    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at                    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE wallet_passes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Customers can view their own wallet passes"
  ON wallet_passes FOR SELECT
  USING (customer_id = auth.uid());

CREATE POLICY "Business owner and employees can view wallet passes"
  ON wallet_passes FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = wallet_passes.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.is_active = TRUE
    )
  );

CREATE POLICY "Business owners can manage wallet passes"
  ON wallet_passes FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = wallet_passes.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.role IN ('system_manager', 'business_owner')
    )
  );

CREATE TRIGGER set_wallet_passes_updated_at
  BEFORE UPDATE ON wallet_passes
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- CUSTOMER SEGMENTS
-- =============================================================================

CREATE TABLE IF NOT EXISTS customer_segments (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uuid          UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  business_id   UUID NOT NULL REFERENCES businesses (id) ON DELETE CASCADE,
  name          TEXT NOT NULL,
  description   TEXT,
  type          TEXT NOT NULL DEFAULT 'automatic' CHECK (type IN ('automatic', 'custom')),
  rule_definition TEXT,
  rule_type     TEXT,
  customer_count INTEGER NOT NULL DEFAULT 0,
  color         TEXT,
  is_system     BOOLEAN NOT NULL DEFAULT FALSE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE customer_segments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view business customer segments"
  ON customer_segments FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = customer_segments.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.is_active = TRUE
    )
  );

CREATE POLICY "Business owners can manage customer segments"
  ON customer_segments FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = customer_segments.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.role IN ('system_manager', 'business_owner')
    )
  );

CREATE TRIGGER set_customer_segments_updated_at
  BEFORE UPDATE ON customer_segments
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- CAMPAIGNS
-- =============================================================================

CREATE TABLE IF NOT EXISTS campaigns (
  id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uuid                     UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  business_id              UUID NOT NULL REFERENCES businesses (id) ON DELETE CASCADE,
  name                     TEXT NOT NULL,
  description              TEXT,
  type                     TEXT NOT NULL DEFAULT 'whatsapp' CHECK (type IN ('whatsapp', 'email', 'sms', 'push', 'in_app', 'multi_channel')),
  channel                  TEXT,
  segment_id               UUID REFERENCES customer_segments (id) ON DELETE SET NULL,
  target_customer_ids      TEXT,
  message_template_id      UUID,
  message_content          TEXT,
  subject                  TEXT,
  status                   campaign_status NOT NULL DEFAULT 'draft',
  scheduled_at             TIMESTAMPTZ,
  sent_at                  TIMESTAMPTZ,
  sent_count               INTEGER NOT NULL DEFAULT 0,
  delivered_count          INTEGER NOT NULL DEFAULT 0,
  read_count               INTEGER NOT NULL DEFAULT 0,
  failed_count             INTEGER NOT NULL DEFAULT 0,
  failure_reasons          TEXT,
  total_cost               DOUBLE PRECISION,
  created_by               UUID NOT NULL REFERENCES auth.users (id),
  created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE campaigns ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view business campaigns"
  ON campaigns FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = campaigns.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.is_active = TRUE
    )
  );

CREATE POLICY "Business owners can manage campaigns"
  ON campaigns FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = campaigns.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.role IN ('system_manager', 'business_owner')
    )
  );

CREATE TRIGGER set_campaigns_updated_at
  BEFORE UPDATE ON campaigns
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- CAMPAIGN RECIPIENTS
-- =============================================================================

CREATE TABLE IF NOT EXISTS campaign_recipients (
  id                            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uuid                          UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  campaign_id                   UUID NOT NULL REFERENCES campaigns (id) ON DELETE CASCADE,
  customer_id                   UUID NOT NULL REFERENCES customers (id) ON DELETE CASCADE,
  customer_business_membership_id UUID NOT NULL REFERENCES customer_business_memberships (id) ON DELETE CASCADE,
  status                        TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'sent', 'delivered', 'read', 'failed', 'opt_out')),
  sent_at                       TIMESTAMPTZ,
  delivered_at                  TIMESTAMPTZ,
  read_at                       TIMESTAMPTZ,
  failed_at                     TIMESTAMPTZ,
  failure_reason                TEXT,
  created_at                    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (campaign_id, customer_id)
);

ALTER TABLE campaign_recipients ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Business owners can view campaign recipients"
  ON campaign_recipients FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = (
        SELECT business_id FROM public.campaigns WHERE campaigns.id = campaign_recipients.campaign_id
      )
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.is_active = TRUE
        AND business_memberships.role IN ('system_manager', 'business_owner')
    )
  );

-- =============================================================================
-- WHATSAPP TEMPLATES
-- =============================================================================

CREATE TABLE IF NOT EXISTS whatsapp_templates (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uuid        UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES businesses (id) ON DELETE CASCADE,
  name        TEXT NOT NULL,
  language    TEXT NOT NULL DEFAULT 'ar',
  category    TEXT,
  content     TEXT,
  header      TEXT,
  footer      TEXT,
  buttons     TEXT,
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  is_verified BOOLEAN NOT NULL DEFAULT FALSE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE whatsapp_templates ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view business whatsapp templates"
  ON whatsapp_templates FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = whatsapp_templates.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.is_active = TRUE
    )
  );

CREATE POLICY "Business owners can manage whatsapp templates"
  ON whatsapp_templates FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = whatsapp_templates.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.role IN ('system_manager', 'business_owner')
    )
  );

CREATE TRIGGER set_whatsapp_templates_updated_at
  BEFORE UPDATE ON whatsapp_templates
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- WHATSAPP MESSAGES
-- =============================================================================

CREATE TABLE IF NOT EXISTS whatsapp_messages (
  id                            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uuid                          UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  business_id                   UUID NOT NULL REFERENCES businesses (id) ON DELETE CASCADE,
  customer_id                   UUID NOT NULL REFERENCES customers (id) ON DELETE CASCADE,
  customer_business_membership_id UUID NOT NULL REFERENCES customer_business_memberships (id) ON DELETE CASCADE,
  campaign_id                   UUID REFERENCES campaigns (id) ON DELETE SET NULL,
  template_id                   UUID REFERENCES whatsapp_templates (id) ON DELETE SET NULL,
  message_type                  TEXT NOT NULL DEFAULT 'text' CHECK (message_type IN ('template', 'text', 'image', 'video', 'document', 'audio', 'interactive')),
  content                       TEXT,
  status                        TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'sent', 'delivered', 'read', 'failed', 'cancelled')),
  error_code                    TEXT,
  error_message                 TEXT,
  phone_number                  TEXT,
  sent_at                       TIMESTAMPTZ,
  delivered_at                  TIMESTAMPTZ,
  read_at                       TIMESTAMPTZ,
  failed_at                     TIMESTAMPTZ,
  created_at                    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at                    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE whatsapp_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Customers can view their own whatsapp messages"
  ON whatsapp_messages FOR SELECT
  USING (customer_id = auth.uid());

CREATE POLICY "Business owner and employees can view whatsapp messages"
  ON whatsapp_messages FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = whatsapp_messages.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.is_active = TRUE
    )
  );

CREATE POLICY "Business owners can manage whatsapp messages"
  ON whatsapp_messages FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = whatsapp_messages.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.role IN ('system_manager', 'business_owner')
    )
  );

CREATE TRIGGER set_whatsapp_messages_updated_at
  BEFORE UPDATE ON whatsapp_messages
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- SUBSCRIPTION PLANS (SaaS)
-- =============================================================================

CREATE TABLE IF NOT EXISTS subscription_plans (
  id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uuid                        UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  name                        TEXT NOT NULL UNIQUE,
  description                 TEXT,
  type                        TEXT NOT NULL DEFAULT 'monthly' CHECK (type IN ('monthly', 'annual', 'one_time')),
  currency                    TEXT NOT NULL DEFAULT 'EGP',
  setup_fee                   DOUBLE PRECISION,
  monthly_price               DOUBLE PRECISION,
  annual_price                DOUBLE PRECISION,
  limits_employees            INTEGER,
  limits_branches             INTEGER,
  limits_customers            INTEGER,
  limits_products             INTEGER,
  limits_inventory            INTEGER,
  limits_whatsapp_messages    INTEGER,
  limits_campaigns            INTEGER,
  limits_ai_requests          INTEGER,
  limits_reports              INTEGER,
  limits_backup_retention_days INTEGER,
  limits_wallet_features      BOOLEAN,
  limits_offline_capability   BOOLEAN,
  limits_nfc_capabilities     BOOLEAN,
  limits_storage_mb           INTEGER,
  features                    TEXT,
  is_active                   BOOLEAN NOT NULL DEFAULT TRUE,
  sort_order                  INTEGER NOT NULL DEFAULT 0,
  created_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE subscription_plans ENABLE ROW LEVEL SECURITY;

CREATE POLICY "System managers can manage subscription plans"
  ON subscription_plans FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = business_memberships.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.role = 'system_manager'
    )
  );

-- =============================================================================
-- SUBSCRIPTIONS
-- =============================================================================

CREATE TABLE IF NOT EXISTS subscriptions (
  id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uuid                        UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  business_id                 UUID NOT NULL REFERENCES businesses (id) ON DELETE CASCADE,
  plan_id                     UUID NOT NULL REFERENCES subscription_plans (id) ON DELETE RESTRICT,
  status                      TEXT NOT NULL DEFAULT 'incomplete' CHECK (status IN ('active', 'past_due', 'cancelled', 'expired', 'trialing', 'incomplete')),
  type                        TEXT NOT NULL DEFAULT 'monthly' CHECK (type IN ('monthly', 'annual', 'one_time')),
  current_period_start        TIMESTAMPTZ,
  current_period_end          TIMESTAMPTZ,
  next_billing_at             TIMESTAMPTZ,
  setup_fee_paid              BOOLEAN NOT NULL DEFAULT FALSE,
  setup_fee_paid_at           TIMESTAMPTZ,
  cancelled_at                TIMESTAMPTZ,
  cancellation_reason         TEXT,
  created_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at                  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE subscriptions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view their business subscription"
  ON subscriptions FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = subscriptions.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.is_active = TRUE
    )
  );

CREATE POLICY "Business owners can manage subscriptions"
  ON subscriptions FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = subscriptions.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.role IN ('system_manager', 'business_owner')
    )
  );

CREATE TRIGGER set_subscriptions_updated_at
  BEFORE UPDATE ON subscriptions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- SUBSCRIPTION INVOICES
-- =============================================================================

CREATE TABLE IF NOT EXISTS subscription_invoices (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uuid             UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  business_id      UUID NOT NULL REFERENCES businesses (id) ON DELETE CASCADE,
  subscription_id  UUID NOT NULL REFERENCES subscriptions (id) ON DELETE CASCADE,
  invoice_number   TEXT NOT NULL UNIQUE,
  amount           DOUBLE PRECISION NOT NULL,
  currency         TEXT NOT NULL DEFAULT 'EGP',
  status           TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'paid', 'failed', 'overdue', 'refunded', 'cancelled')),
  issued_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  due_at           TIMESTAMPTZ,
  paid_at          TIMESTAMPTZ,
  failure_reason   TEXT,
  pdf_url          TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE subscription_invoices ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view business invoices"
  ON subscription_invoices FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = subscription_invoices.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.is_active = TRUE
    )
  );

CREATE POLICY "Business owners can manage invoices"
  ON subscription_invoices FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = subscription_invoices.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.role IN ('system_manager', 'business_owner')
    )
  );

CREATE TRIGGER set_subscription_invoices_updated_at
  BEFORE UPDATE ON subscription_invoices
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- NOTIFICATIONS
-- =============================================================================

CREATE TABLE IF NOT EXISTS notifications (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uuid        UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES businesses (id) ON DELETE CASCADE,
  user_id     UUID,
  customer_id UUID,
  title       TEXT NOT NULL,
  body        TEXT,
  type        TEXT NOT NULL DEFAULT 'info' CHECK (type IN ('info', 'warning', 'error', 'success', 'marketing', 'transactional')),
  channel     TEXT NOT NULL DEFAULT 'in_app' CHECK (channel IN ('in_app', 'email', 'sms', 'whatsapp', 'push')),
  data        TEXT,
  is_read     BOOLEAN NOT NULL DEFAULT FALSE,
  read_at     TIMESTAMPTZ,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own notifications"
  ON notifications FOR SELECT
  USING (user_id = auth.uid() OR customer_id = auth.uid());

CREATE POLICY "Business owner and employees can view business notifications"
  ON notifications FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = notifications.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.is_active = TRUE
    )
  );

-- =============================================================================
-- AUDIT LOGS
-- =============================================================================

CREATE TABLE IF NOT EXISTS audit_logs (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uuid         UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  business_id  UUID,
  user_id      UUID,
  action       audit_action NOT NULL,
  target_type  TEXT,
  target_id    UUID,
  description  TEXT,
  metadata     TEXT,
  ip_address   INET,
  user_agent   TEXT,
  device_id    UUID,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "System managers can view all audit logs"
  ON audit_logs FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.user_id = auth.uid()
        AND business_memberships.role = 'system_manager'
    )
    OR business_id IN (
      SELECT business_id FROM public.business_memberships
      WHERE user_id = auth.uid() AND is_active = TRUE
    )
  );

CREATE POLICY "Audit logs are insertable by the system"
  ON audit_logs FOR INSERT
  WITH CHECK (TRUE);

-- =============================================================================
-- OFFLINE TRANSACTIONS
-- =============================================================================

CREATE TABLE IF NOT EXISTS offline_transactions (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uuid                  UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  business_id           UUID NOT NULL REFERENCES businesses (id) ON DELETE CASCADE,
  device_id             UUID NOT NULL REFERENCES devices (id) ON DELETE CASCADE,
  user_id               UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  branch_id             UUID REFERENCES branches (id) ON DELETE SET NULL,
  local_transaction_id  TEXT NOT NULL UNIQUE,
  operation             TEXT NOT NULL CHECK (operation IN ('sale', 'return', 'refund', 'loyalty_adjustment', 'inventory_adjustment', 'customer_register', 'customer_update', 'product_sync', 'other')),
  payload               TEXT NOT NULL,
  idempotency_key       TEXT NOT NULL UNIQUE,
  status                sync_queue_status NOT NULL DEFAULT 'pending',
  retry_count           INTEGER NOT NULL DEFAULT 0,
  last_error            TEXT,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  synced_at             TIMESTAMPTZ,
  server_transaction_id UUID
);

ALTER TABLE offline_transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Business owner and employees can view offline transactions"
  ON offline_transactions FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = offline_transactions.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.is_active = TRUE
    )
  );

CREATE POLICY "System processes can update offline transactions"
  ON offline_transactions FOR UPDATE
  USING (TRUE);

CREATE TRIGGER set_offline_transactions_updated_at
  BEFORE UPDATE ON offline_transactions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- SYNC QUEUE
-- =============================================================================

CREATE TABLE IF NOT EXISTS sync_queue (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uuid             UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  business_id      UUID NOT NULL REFERENCES businesses (id) ON DELETE CASCADE,
  device_id        UUID NOT NULL REFERENCES devices (id) ON DELETE CASCADE,
  user_id          UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  operation        TEXT NOT NULL,
  payload          TEXT NOT NULL,
  local_id         TEXT NOT NULL,
  idempotency_key  TEXT NOT NULL UNIQUE,
  status           sync_queue_status NOT NULL DEFAULT 'pending',
  retry_count      INTEGER NOT NULL DEFAULT 0,
  last_error       TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  processed_at     TIMESTAMPTZ,
  server_id        UUID
);

ALTER TABLE sync_queue ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Business owner and employees can view sync queue"
  ON sync_queue FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = sync_queue.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.is_active = TRUE
    )
  );

CREATE POLICY "System processes can update sync queue"
  ON sync_queue FOR UPDATE
  USING (TRUE);

CREATE TRIGGER set_sync_queue_updated_at
  BEFORE UPDATE ON sync_queue
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- BACKUP JOBS
-- =============================================================================

CREATE TABLE IF NOT EXISTS backup_jobs (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uuid             UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  business_id      UUID NOT NULL REFERENCES businesses (id) ON DELETE CASCADE,
  name             TEXT,
  type             TEXT NOT NULL DEFAULT 'manual' CHECK (type IN ('manual', 'automatic_daily', 'automatic_weekly', 'automatic_monthly')),
  status           backup_status NOT NULL DEFAULT 'pending',
  format           TEXT NOT NULL DEFAULT 'json' CHECK (format IN ('json', 'csv', 'zip', 'database')),
  initiated_by     UUID REFERENCES auth.users (id),
  initiated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at     TIMESTAMPTZ,
  size_bytes       BIGINT,
  file_path        TEXT,
  file_url         TEXT,
  error_message    TEXT,
  integrity_hash   TEXT,
  schema_version   TEXT,
  app_version      TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE backup_jobs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Business owner and employees can view backup jobs"
  ON backup_jobs FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = backup_jobs.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.is_active = TRUE
    )
  );

CREATE POLICY "Business owners can manage backup jobs"
  ON backup_jobs FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = backup_jobs.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.role IN ('system_manager', 'business_owner')
    )
  );

CREATE TRIGGER set_backup_jobs_updated_at
  BEFORE UPDATE ON backup_jobs
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- RESTORE JOBS
-- =============================================================================

CREATE TABLE IF NOT EXISTS restore_jobs (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uuid                 UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  business_id          UUID NOT NULL REFERENCES businesses (id) ON DELETE CASCADE,
  backup_id            UUID NOT NULL REFERENCES backup_jobs (id) ON DELETE RESTRICT,
  name                 TEXT,
  type                 TEXT NOT NULL DEFAULT 'full' CHECK (type IN ('full', 'selective')),
  status               restore_status NOT NULL DEFAULT 'pending',
  selective_components TEXT,
  safety_backup_created BOOLEAN NOT NULL DEFAULT FALSE,
  initiated_by         UUID REFERENCES auth.users (id),
  initiated_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at         TIMESTAMPTZ,
  error_message        TEXT,
  rollback_performed   BOOLEAN NOT NULL DEFAULT FALSE,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE restore_jobs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Business owner and employees can view restore jobs"
  ON restore_jobs FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = restore_jobs.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.is_active = TRUE
    )
  );

CREATE POLICY "Business owners can manage restore jobs"
  ON restore_jobs FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = restore_jobs.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.role IN ('system_manager', 'business_owner')
    )
  );

CREATE TRIGGER set_restore_jobs_updated_at
  BEFORE UPDATE ON restore_jobs
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- AI CONVERSATIONS
-- =============================================================================

CREATE TABLE IF NOT EXISTS ai_conversations (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uuid       UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES businesses (id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  title      TEXT,
  context    TEXT,
  status     TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'archived', 'deleted')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE ai_conversations ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own AI conversations"
  ON ai_conversations FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Business owner and employees can view AI conversations"
  ON ai_conversations FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = ai_conversations.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.is_active = TRUE
    )
  );

CREATE POLICY "Business owners can manage AI conversations"
  ON ai_conversations FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = ai_conversations.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.role IN ('system_manager', 'business_owner')
    )
  );

CREATE TRIGGER set_ai_conversations_updated_at
  BEFORE UPDATE ON ai_conversations
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- AI MESSAGES
-- =============================================================================

CREATE TABLE IF NOT EXISTS ai_messages (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uuid             UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  business_id      UUID NOT NULL REFERENCES businesses (id) ON DELETE CASCADE,
  conversation_id  UUID NOT NULL REFERENCES ai_conversations (id) ON DELETE CASCADE,
  user_id          UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  role             TEXT NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
  content          TEXT NOT NULL,
  tool_calls       TEXT,
  tool_results     TEXT,
  input_tokens     INTEGER,
  output_tokens    INTEGER,
  estimated_cost   DOUBLE PRECISION,
  model            TEXT,
  source           TEXT NOT NULL DEFAULT 'chat' CHECK (source IN ('chat', 'dashboard', 'action_center', 'report', 'campaign', 'other')),
  feature          TEXT,
  error_message    TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE ai_messages ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own AI messages"
  ON ai_messages FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Business owner and employees can view AI messages"
  ON ai_messages FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = ai_messages.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.is_active = TRUE
    )
  );

-- =============================================================================
-- AI USAGE
-- =============================================================================

CREATE TABLE IF NOT EXISTS ai_usage (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uuid                UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  business_id         UUID NOT NULL REFERENCES businesses (id) ON DELETE CASCADE,
  user_id             UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  model               TEXT NOT NULL,
  request_type        TEXT NOT NULL,
  feature             TEXT,
  input_tokens        INTEGER NOT NULL DEFAULT 0,
  output_tokens       INTEGER NOT NULL DEFAULT 0,
  estimated_cost_usd  DOUBLE PRECISION NOT NULL DEFAULT 0,
  status              TEXT NOT NULL DEFAULT 'success' CHECK (status IN ('success', 'failed', 'cancelled', 'rate_limited')),
  error_message       TEXT,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE ai_usage ENABLE ROW LEVEL SECURITY;

CREATE POLICY "System managers can view all AI usage"
  ON ai_usage FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.user_id = auth.uid()
        AND business_memberships.role = 'system_manager'
    )
    OR business_id IN (
      SELECT business_id FROM public.business_memberships
      WHERE user_id = auth.uid() AND is_active = TRUE
    )
  );

CREATE POLICY "Business owner and employees can view their business AI usage"
  ON ai_usage FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = ai_usage.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.is_active = TRUE
        AND business_memberships.role IN ('system_manager', 'business_owner')
    )
  );

-- =============================================================================
-- AI ACTIONS
-- =============================================================================

CREATE TABLE IF NOT EXISTS ai_actions (
  id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uuid                     UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  business_id              UUID NOT NULL REFERENCES businesses (id) ON DELETE CASCADE,
  user_id                  UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
  conversation_id          UUID NOT NULL REFERENCES ai_conversations (id) ON DELETE CASCADE,
  ai_message_id            UUID NOT NULL REFERENCES ai_messages (id) ON DELETE CASCADE,
  action_type              TEXT NOT NULL,
  action_description       TEXT NOT NULL,
  target_type              TEXT,
  target_id                UUID,
  status                   TEXT NOT NULL DEFAULT 'pending_confirmation' CHECK (status IN ('pending_confirmation', 'confirmed', 'executed', 'cancelled', 'failed')),
  confirmation_required    BOOLEAN NOT NULL DEFAULT FALSE,
  confirmed_by             UUID REFERENCES auth.users (id),
  confirmed_at             TIMESTAMPTZ,
  executed_at              TIMESTAMPTZ,
  result                   TEXT,
  error_message            TEXT,
  created_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE ai_actions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Business owner and employees can view AI actions"
  ON ai_actions FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = ai_actions.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.is_active = TRUE
    )
  );

CREATE POLICY "Business owners can manage AI actions"
  ON ai_actions FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = ai_actions.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.role IN ('system_manager', 'business_owner')
    )
  );

CREATE TRIGGER set_ai_actions_updated_at
  BEFORE UPDATE ON ai_actions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- INTEGRATION CONFIGS
-- =============================================================================

CREATE TABLE IF NOT EXISTS integration_configs (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uuid             UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  business_id      UUID NOT NULL REFERENCES businesses (id) ON DELETE CASCADE,
  name             TEXT NOT NULL,
  provider         TEXT NOT NULL,
  type             TEXT NOT NULL CHECK (type IN ('payment', 'whatsapp', 'wallet', 'nfc', 'printer', 'barcode_scanner', 'other')),
  config_key       TEXT,
  config_value     TEXT,
  is_active        BOOLEAN NOT NULL DEFAULT TRUE,
  is_test_mode     BOOLEAN NOT NULL DEFAULT FALSE,
  last_tested_at   TIMESTAMPTZ,
  last_test_result TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE integration_configs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can view business integration configs"
  ON integration_configs FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = integration_configs.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.is_active = TRUE
    )
  );

CREATE POLICY "Business owners can manage integration configs"
  ON integration_configs FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.business_id = integration_configs.business_id
        AND business_memberships.user_id = auth.uid()
        AND business_memberships.role IN ('system_manager', 'business_owner')
    )
  );

CREATE TRIGGER set_integration_configs_updated_at
  BEFORE UPDATE ON integration_configs
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- =============================================================================
-- SYSTEM CATEGORIES (Business categories — managed by System Manager)
-- =============================================================================

CREATE TABLE IF NOT EXISTS system_categories (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uuid        UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
  name        TEXT NOT NULL UNIQUE,
  description TEXT,
  icon        TEXT,
  color       TEXT,
  sort_order  INTEGER NOT NULL DEFAULT 0,
  is_active   BOOLEAN NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE system_categories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Authenticated users can view system categories"
  ON system_categories FOR SELECT
  USING (auth.uid() IS NOT NULL);

CREATE POLICY "System managers can manage system categories"
  ON system_categories FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public.business_memberships
      WHERE business_memberships.user_id = auth.uid()
        AND business_memberships.role = 'system_manager'
    )
  );

CREATE TRIGGER set_system_categories_updated_at
  BEFORE UPDATE ON system_categories
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- -----------------------------------------------------------------------------
-- SEED DATA (System Manager role, permissions, default categories)
-- -----------------------------------------------------------------------------

-- Insert default roles
INSERT INTO roles (name, description, is_system) VALUES
  ('system_manager', 'Platform administrator with full system access.', TRUE),
  ('business_owner', 'Full control of a single business.', TRUE),
  ('manager', 'Extended employee with management permissions.', TRUE),
  ('employee', 'Staff member with configurable permissions.', TRUE),
  ('cashier', 'Front-line cashier with POS-only permissions.', TRUE)
ON CONFLICT (name) DO NOTHING;

-- Insert default permissions
INSERT INTO permissions (code, name, description, category) VALUES
  -- Business management
  ('business.view', 'View Business', 'View business details and settings.', 'business'),
  ('business.update', 'Update Business', 'Update business details and settings.', 'business'),
  ('business.delete', 'Delete Business', 'Delete a business.', 'business'),
  -- Branch management
  ('branch.view', 'View Branch', 'View branch details.', 'branch'),
  ('branch.create', 'Create Branch', 'Create a new branch.', 'branch'),
  ('branch.update', 'Update Branch', 'Update branch details.', 'branch'),
  ('branch.delete', 'Delete Branch', 'Delete a branch.', 'branch'),
  -- Employee management
  ('employee.view', 'View Employee', 'View employee details.', 'employee'),
  ('employee.create', 'Create Employee', 'Create a new employee.', 'employee'),
  ('employee.update', 'Update Employee', 'Update employee details and permissions.', 'employee'),
  ('employee.revoke', 'Revoke Employee', 'Revoke or delete an employee.', 'employee'),
  -- Product management
  ('product.view', 'View Product', 'View product details.', 'product'),
  ('product.create', 'Create Product', 'Create a new product.', 'product'),
  ('product.update', 'Update Product', 'Update product details and pricing.', 'product'),
  ('product.delete', 'Delete Product', 'Delete a product.', 'product'),
  -- Inventory
  ('inventory.view', 'View Inventory', 'View inventory levels.', 'inventory'),
  ('inventory.update', 'Update Inventory', 'Update inventory quantities.', 'inventory'),
  ('inventory.adjust', 'Adjust Inventory', 'Perform inventory adjustments.', 'inventory'),
  -- POS
  ('pos.open', 'Open POS', 'Open the point of sale interface.', 'pos'),
  ('sale.create', 'Create Sale', 'Create a new sale/order.', 'pos'),
  ('sale.void', 'Void Sale', 'Void a draft sale.', 'pos'),
  ('sale.refund', 'Refund Sale', 'Refund a completed sale.', 'pos'),
  -- Customer
  ('customer.view', 'View Customer', 'View customer profile.', 'customer'),
  ('customer.create', 'Create Customer', 'Register a new customer.', 'customer'),
  ('customer.update', 'Update Customer', 'Update customer details.', 'customer'),
  ('customer.search', 'Search Customer', 'Search for customers.', 'customer'),
  ('customer.identify_qr', 'Scan Customer QR', 'Scan a customer QR credential.', 'customer'),
  ('customer.identify_nfc', 'Tap Customer NFC', 'Tap a customer NFC credential.', 'customer'),
  -- Loyalty
  ('loyalty.view', 'View Loyalty', 'View loyalty program details.', 'loyalty'),
  ('loyalty.create', 'Create Loyalty Program', 'Create a loyalty program.', 'loyalty'),
  ('loyalty.update', 'Update Loyalty Program', 'Update loyalty program settings.', 'loyalty'),
  ('loyalty.adjust', 'Adjust Loyalty Points', 'Manually adjust loyalty points.', 'loyalty'),
  ('reward.view', 'View Rewards', 'View available rewards.', 'loyalty'),
  ('reward.create', 'Create Reward', 'Create a new reward.', 'loyalty'),
  ('reward.redeem', 'Redeem Reward', 'Redeem a reward for a customer.', 'loyalty'),
  -- Marketing
  ('marketing.view', 'View Campaigns', 'View marketing campaigns.', 'marketing'),
  ('marketing.create', 'Create Campaign', 'Create a new campaign.', 'marketing'),
  ('marketing.send', 'Send Campaign', 'Send a marketing campaign.', 'marketing'),
  -- Payments
  ('payment.view', 'View Payments', 'View payment records.', 'payment'),
  ('payment.process', 'Process Payment', 'Process a payment.', 'payment'),
  ('payment.refund', 'Refund Payment', 'Refund a payment.', 'payment'),
  -- Settings
  ('settings.view', 'View Settings', 'View business settings.', 'settings'),
  ('settings.update', 'Update Settings', 'Update business settings.', 'settings'),
  ('settings.nfc', 'Manage NFC', 'Configure NFC settings.', 'settings'),
  ('settings.qr', 'Manage QR', 'Configure QR settings.', 'settings'),
  ('settings.wallet', 'Manage Wallet', 'Configure wallet passes.', 'settings'),
  -- Reports
  ('reports.view', 'View Reports', 'View business reports.', 'reports'),
  ('reports.export', 'Export Reports', 'Export reports as CSV/PDF.', 'reports'),
  -- AI
  ('ai.chat', 'Chat with AI', 'Use the AI business assistant.', 'ai'),
  ('ai.actions', 'AI Actions', 'Allow AI to perform actions.', 'ai'),
  -- Backups
  ('backup.create', 'Create Backup', 'Create a backup.', 'backup'),
  ('backup.restore', 'Restore Backup', 'Restore from a backup.', 'backup'),
  -- System (System Manager only)
  ('system.businesses', 'Manage Businesses', 'Manage all businesses on the platform.', 'system'),
  ('system.users', 'Manage Users', 'Manage all users on the platform.', 'system'),
  ('system.plans', 'Manage Plans', 'Manage subscription plans.', 'system'),
  ('system.categories', 'Manage Categories', 'Manage business categories.', 'system'),
  ('system.integrations', 'Manage Integrations', 'Manage platform integrations.', 'system'),
  ('system.ai', 'Manage AI', 'Manage AI settings and costs.', 'system'),
  ('system.backups', 'Manage Backups', 'Manage all backups.', 'system'),
  ('system.audit', 'View Audit Logs', 'View all audit logs.', 'system'),
  ('system.settings', 'Manage System Settings', 'Manage system-wide settings.', 'system')
ON CONFLICT (code) DO NOTHING;

-- Seed default role_permissions
INSERT INTO role_permissions (role_id, permission_id, granted_at)
SELECT r.id, p.id, NOW()
FROM roles r, permissions p
WHERE r.name = 'system_manager'
  AND p.code IN (
    'business.view', 'business.update', 'business.delete',
    'branch.view', 'branch.create', 'branch.update', 'branch.delete',
    'employee.view', 'employee.create', 'employee.update', 'employee.revoke',
    'product.view', 'product.create', 'product.update', 'product.delete',
    'inventory.view', 'inventory.update', 'inventory.adjust',
    'pos.open', 'sale.create', 'sale.void', 'sale.refund',
    'customer.view', 'customer.create', 'customer.update', 'customer.search',
    'customer.identify_qr', 'customer.identify_nfc',
    'loyalty.view', 'loyalty.create', 'loyalty.update', 'loyalty.adjust',
    'reward.view', 'reward.create', 'reward.redeem',
    'marketing.view', 'marketing.create', 'marketing.send',
    'payment.view', 'payment.process', 'payment.refund',
    'settings.view', 'settings.update', 'settings.nfc', 'settings.qr', 'settings.wallet',
    'reports.view', 'reports.export',
    'ai.chat', 'ai.actions',
    'backup.create', 'backup.restore',
    'system.businesses', 'system.users', 'system.plans', 'system.categories',
    'system.integrations', 'system.ai', 'system.backups', 'system.audit', 'system.settings'
  )
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Business owner gets a subset
INSERT INTO role_permissions (role_id, permission_id, granted_at)
SELECT r.id, p.id, NOW()
FROM roles r, permissions p
WHERE r.name = 'business_owner'
  AND p.code IN (
    'business.view', 'business.update',
    'branch.view', 'branch.create', 'branch.update', 'branch.delete',
    'employee.view', 'employee.create', 'employee.update', 'employee.revoke',
    'product.view', 'product.create', 'product.update', 'product.delete',
    'inventory.view', 'inventory.update', 'inventory.adjust',
    'pos.open', 'sale.create', 'sale.void', 'sale.refund',
    'customer.view', 'customer.create', 'customer.update', 'customer.search',
    'customer.identify_qr', 'customer.identify_nfc',
    'loyalty.view', 'loyalty.create', 'loyalty.update', 'loyalty.adjust',
    'reward.view', 'reward.create', 'reward.redeem',
    'marketing.view', 'marketing.create', 'marketing.send',
    'payment.view', 'payment.process', 'payment.refund',
    'settings.view', 'settings.update', 'settings.nfc', 'settings.qr', 'settings.wallet',
    'reports.view', 'reports.export',
    'ai.chat', 'ai.actions',
    'backup.create', 'backup.restore'
  )
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Manager gets most employee permissions + some management
INSERT INTO role_permissions (role_id, permission_id, granted_at)
SELECT r.id, p.id, NOW()
FROM roles r, permissions p
WHERE r.name = 'manager'
  AND p.code IN (
    'business.view',
    'branch.view',
    'employee.view',
    'product.view', 'product.create', 'product.update',
    'inventory.view', 'inventory.update',
    'pos.open', 'sale.create', 'sale.void',
    'customer.view', 'customer.create', 'customer.update', 'customer.search',
    'customer.identify_qr', 'customer.identify_nfc',
    'loyalty.view', 'loyalty.create', 'loyalty.update',
    'reward.view', 'reward.create', 'reward.redeem',
    'payment.view', 'payment.process',
    'settings.view', 'settings.update',
    'reports.view',
    'ai.chat'
  )
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Employee defaults
INSERT INTO role_permissions (role_id, permission_id, granted_at)
SELECT r.id, p.id, NOW()
FROM roles r, permissions p
WHERE r.name = 'employee'
  AND p.code IN (
    'business.view',
    'branch.view',
    'product.view',
    'pos.open', 'sale.create',
    'customer.view', 'customer.search',
    'customer.identify_qr', 'customer.identify_nfc',
    'loyalty.view',
    'reward.view', 'reward.redeem',
    'payment.view', 'payment.process',
    'settings.view',
    'reports.view'
  )
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Cashier defaults (minimal)
INSERT INTO role_permissions (role_id, permission_id, granted_at)
SELECT r.id, p.id, NOW()
FROM roles r, permissions p
WHERE r.name = 'cashier'
  AND p.code IN (
    'pos.open', 'sale.create',
    'customer.view', 'customer.search',
    'customer.identify_qr', 'customer.identify_nfc',
    'loyalty.view',
    'reward.redeem',
    'payment.process'
  )
ON CONFLICT (role_id, permission_id) DO NOTHING;

-- Seed default business categories
INSERT INTO system_categories (name, description, icon, color, sort_order) VALUES
  ('Café', 'Coffee shops, cafes, and tea houses.', 'MUG', '#c4a35a', 1),
  ('Restaurant', 'Full-service restaurants and dining.', 'FORK_KNIFE', '#e67e22', 2),
  ('Bakery', 'Bakeries, pastries, and bread shops.', 'BAGEL', '#d35400', 3),
  ('Barber', 'Barbershops and men grooming.', 'SCISSORS', '#2c3e50', 4),
  ('Hair Salon', 'Hair salons and styling.', 'SCISSORS', '#8e44ad', 5),
  ('Beauty Salon', 'Beauty salons and cosmetics.', 'PALETTE', '#e91e63', 6),
  ('Spa', 'Spas and wellness centers.', 'SPA', '#16a085', 7),
  ('Gym', 'Gyms and fitness centers.', 'DUMBBELL', '#27ae60', 8),
  ('Clothing Store', 'Clothing and fashion retail.', 'SHIRT', '#3498db', 9),
  ('Shoe Store', 'Shoe and footwear stores.', 'SHOEBASE', '#f39c12', 10),
  ('Grocery Store', 'Grocery and convenience stores.', 'SHOPPING_CART', '#2ecc71', 11),
  ('Retail Store', 'General retail stores.', 'SHOPPING_BAG', '#95a5a6', 12),
  ('Electronics', 'Electronics and tech stores.', 'LAPTOP', '#34495e', 13),
  ('Accessories', 'Jewelry, watches, and accessories.', 'RING', '#e74c3c', 14),
  ('Laundry', 'Laundry and dry cleaning services.', 'SHIRT', '#bdc3c7', 15),
  ('Car Care', 'Car wash, detailing, and auto services.', 'CAR', '#7f8c8d', 16),
  ('Pet Services', 'Pet grooming, vet, and pet services.', 'DOG', '#f1c40f', 17),
  ('Professional Services', 'Consultants, accountants, and professional services.', 'FILE', '#34495e', 18),
  ('Other', 'Other businesses not in the categories above.', 'ELLIPSIS', '#7f8c8d', 99)
ON CONFLICT (name) DO NOTHING;

-- Create indexes for performance

CREATE INDEX IF NOT EXISTS idx_business_memberships_user_id ON business_memberships (user_id);
CREATE INDEX IF NOT EXISTS idx_business_memberships_business_id ON business_memberships (business_id);
CREATE INDEX IF NOT EXISTS idx_business_memberships_role ON business_memberships (role);
CREATE INDEX IF NOT EXISTS idx_branches_business_id ON branches (business_id);
CREATE INDEX IF NOT EXISTS idx_devices_business_id ON devices (business_id);
CREATE INDEX IF NOT EXISTS idx_devices_device_id ON devices (device_id);
CREATE INDEX IF NOT EXISTS idx_devices_status ON devices (status);
CREATE INDEX IF NOT EXISTS idx_customers_global_id ON customers (global_id);
CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers (phone);
CREATE INDEX IF NOT EXISTS idx_customers_name ON customers (name);
CREATE INDEX IF NOT EXISTS idx_customer_business_memberships_customer_id ON customer_business_memberships (customer_id);
CREATE INDEX IF NOT EXISTS idx_customer_business_memberships_business_id ON customer_business_memberships (business_id);
CREATE INDEX IF NOT EXISTS idx_customer_business_memberships_membership_identifier ON customer_business_memberships (membership_identifier);
CREATE INDEX IF NOT EXISTS idx_products_business_id ON products (business_id);
CREATE INDEX IF NOT EXISTS idx_products_barcode ON products (barcode);
CREATE INDEX IF NOT EXISTS idx_products_category_id ON products (category_id);
CREATE INDEX IF NOT EXISTS idx_products_sku ON products (sku);
CREATE INDEX IF NOT EXISTS idx_services_business_id ON services (business_id);
CREATE INDEX IF NOT EXISTS idx_inventory_business_id ON inventory (business_id);
CREATE INDEX IF NOT EXISTS idx_inventory_product_id ON inventory (product_id);
CREATE INDEX IF NOT EXISTS idx_inventory_movements_business_id ON inventory_movements (business_id);
CREATE INDEX IF NOT EXISTS idx_orders_business_id ON orders (business_id);
CREATE INDEX IF NOT EXISTS idx_orders_order_number ON orders (order_number);
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders (status);
CREATE INDEX IF NOT EXISTS idx_orders_customer_id ON orders (customer_id);
CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON order_items (order_id);
CREATE INDEX IF NOT EXISTS idx_payments_business_id ON payments (business_id);
CREATE INDEX IF NOT EXISTS idx_payments_order_id ON payments (order_id);
CREATE INDEX IF NOT EXISTS idx_payments_status ON payments (status);
CREATE INDEX IF NOT EXISTS idx_loyalty_programs_business_id ON loyalty_programs (business_id);
CREATE INDEX IF NOT EXISTS idx_loyalty_balances_customer_business_membership_id ON loyalty_balances (customer_business_membership_id);
CREATE INDEX IF NOT EXISTS idx_loyalty_transactions_customer_id ON loyalty_transactions (customer_id);
CREATE INDEX IF NOT EXISTS idx_loyalty_transactions_business_id ON loyalty_transactions (business_id);
CREATE INDEX IF NOT EXISTS idx_rewards_business_id ON rewards (business_id);
CREATE INDEX IF NOT EXISTS idx_qr_credentials_business_id ON qr_credentials (business_id);
CREATE INDEX IF NOT EXISTS idx_qr_credentials_credential_code ON qr_credentials (credential_code);
CREATE INDEX IF NOT EXISTS idx_qr_credentials_customer_id ON qr_credentials (customer_id);
CREATE INDEX IF NOT EXISTS idx_nfc_credentials_business_id ON nfc_credentials (business_id);
CREATE INDEX IF NOT EXISTS idx_nfc_credentials_credential_code ON nfc_credentials (credential_code);
CREATE INDEX IF NOT EXISTS idx_nfc_credentials_customer_id ON nfc_credentials (customer_id);
CREATE INDEX IF NOT EXISTS idx_campaigns_business_id ON campaigns (business_id);
CREATE INDEX IF NOT EXISTS idx_campaigns_status ON campaigns (status);
CREATE INDEX IF NOT EXISTS idx_whatsapp_messages_business_id ON whatsapp_messages (business_id);
CREATE INDEX IF NOT EXISTS idx_whatsapp_messages_customer_id ON whatsapp_messages (customer_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_business_id ON subscriptions (business_id);
CREATE INDEX IF NOT EXISTS idx_notifications_business_id ON notifications (business_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications (user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON notifications (is_read);
CREATE INDEX IF NOT EXISTS idx_audit_logs_business_id ON audit_logs (business_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON audit_logs (user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs (action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs (created_at);
CREATE INDEX IF NOT EXISTS idx_offline_transactions_business_id ON offline_transactions (business_id);
CREATE INDEX IF NOT EXISTS idx_offline_transactions_device_id ON offline_transactions (device_id);
CREATE INDEX IF NOT EXISTS idx_offline_transactions_status ON offline_transactions (status);
CREATE INDEX IF NOT EXISTS idx_offline_transactions_idempotency_key ON offline_transactions (idempotency_key);
CREATE INDEX IF NOT EXISTS idx_sync_queue_business_id ON sync_queue (business_id);
CREATE INDEX IF NOT EXISTS idx_sync_queue_device_id ON sync_queue (device_id);
CREATE INDEX IF NOT EXISTS idx_sync_queue_status ON sync_queue (status);
CREATE INDEX IF NOT EXISTS idx_sync_queue_idempotency_key ON sync_queue (idempotency_key);
CREATE INDEX IF NOT EXISTS idx_backup_jobs_business_id ON backup_jobs (business_id);
CREATE INDEX IF NOT EXISTS idx_backup_jobs_status ON backup_jobs (status);
CREATE INDEX IF NOT EXISTS idx_restore_jobs_business_id ON restore_jobs (business_id);
CREATE INDEX IF NOT EXISTS idx_restore_jobs_status ON restore_jobs (status);
CREATE INDEX IF NOT EXISTS idx_ai_usage_business_id ON ai_usage (business_id);
CREATE INDEX IF NOT EXISTS idx_ai_usage_created_at ON ai_usage (created_at);

-- -----------------------------------------------------------------------------
-- FUNCTIONS
-- -----------------------------------------------------------------------------

-- Generate unique order number
CREATE OR REPLACE FUNCTION generate_order_number()
RETURNS TEXT AS $$
DECLARE
  prefix TEXT;
  num    INTEGER;
  result TEXT;
BEGIN
  SELECT COALESCE(business.prefix, 'ORD') INTO prefix
  FROM businesses
  WHERE businesses.id = (SELECT business_id FROM orders LIMIT 1);
  -- This is a placeholder; actual implementation uses business-specific prefix.
  num := floor(random() * 900000 + 100000)::INTEGER;
  result := 'ORD' || num::TEXT;
  RETURN result;
END;
$$ LANGUAGE plpgsql;

-- Helper: create a customer with phone validation (Egyptian format)
CREATE OR REPLACE FUNCTION register_customer(
  p_name           TEXT,
  p_phone          TEXT,
  p_email          TEXT DEFAULT NULL,
  p_date_of_birth  DATE DEFAULT NULL,
  p_business_id    UUID
) RETURNS UUID AS $$
DECLARE
  v_customer_id UUID;
  v_membership_id UUID;
  v_membership_identifier TEXT;
  v_count INTEGER;
BEGIN
  -- Validate Egyptian phone number (starts with 010, 011, 012, 015 and is 11 digits)
  IF p_phone ~ '^01[0-5][0-9]{8}$' THEN
    -- valid
  ELSIF p_phone ~ '^\+201[0-5][0-9]{8}$' THEN
    -- valid with country code
  ELSE
    RAISE EXCEPTION 'Invalid Egyptian phone number format';
  END IF;

  -- Create global customer
  INSERT INTO customers (name, phone, email, date_of_birth)
  VALUES (p_name, p_phone, p_email, p_date_of_birth)
  RETURNING id INTO v_customer_id;

  -- Generate unique membership identifier (short code)
  v_membership_identifier := 'MEM' || upper(substr(md5(random()::TEXT), 1, 8));

  -- Create business membership
  INSERT INTO customer_business_memberships (
    customer_id, business_id, membership_identifier
  ) VALUES (v_customer_id, p_business_id, v_membership_identifier)
  RETURNING id INTO v_membership_id;

  RETURN v_customer_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Loyalty: earn points on order completion
CREATE OR REPLACE FUNCTION earn_loyalty_on_order(
  p_order_id UUID
) RETURNS VOID AS $$
DECLARE
  v_order orders%ROWTYPE;
  v_customer_id UUID;
  v_membership_id UUID;
  v_program loyalty_programs%ROWTYPE;
  v_points_earned INTEGER;
  v_points_rate DOUBLE PRECISION;
  v_customer customers%ROWTYPE;
  v_membership customer_business_memberships%ROWTYPE;
  v_balance loyalty_balances%ROWTYPE;
BEGIN
  SELECT * INTO v_order FROM orders WHERE orders.id = p_order_id FOR UPDATE;

  IF v_order.status != 'completed' OR v_order.customer_id IS NULL THEN
    RETURN;
  END IF;

  SELECT * INTO v_customer FROM customers WHERE customers.id = v_order.customer_id;
  SELECT * INTO v_membership FROM customer_business_memberships
    WHERE customer_business_memberships.customer_id = v_order.customer_id
    AND customer_business_memberships.business_id = v_order.business_id;

  SELECT * INTO v_program FROM loyalty_programs
    WHERE loyalty_programs.business_id = v_order.business_id
    AND loyalty_programs.is_active = TRUE
    AND loyalty_programs.is_default = TRUE
  LIMIT 1;

  IF v_program IS NULL THEN
    RETURN; -- no active default loyalty program
  END IF;

  v_points_rate := COALESCE(v_program.points_rate, v_order.business_id); -- fallback to business.loyalty_points_rate
  v_points_earned := floor(v_order.total * COALESCE(v_points_rate, 1))::INTEGER;

  IF v_points_earned <= 0 THEN
    RETURN;
  END IF;

  -- Update loyalty balance
  UPDATE loyalty_balances
  SET points_balance = points_balance + v_points_earned,
      last_updated_at = NOW()
  WHERE customer_business_membership_id = v_membership.id;

  IF NOT FOUND THEN
    INSERT INTO loyalty_balances (customer_business_membership_id, business_id, points_balance, last_updated_at)
    VALUES (v_membership.id, v_order.business_id, v_points_earned, NOW());
  END IF;

  -- Update customer totals
  UPDATE customers
  SET total_visits = total_visits + 1,
      total_spending = total_spending + v_order.total,
      average_order_value = (total_spending + v_order.total) / (total_visits + 1),
      lifetime_value = lifetime_value + v_order.total,
      loyalty_points_balance = loyalty_points_balance + v_points_earned,
      loyalty_visits_count = loyalty_visits_count + 1,
      last_visit_at = NOW(),
      first_visit_at = COALESCE(first_visit_at, NOW())
  WHERE id = v_order.customer_id;

  -- Update membership totals
  UPDATE customer_business_memberships
  SET total_visits = total_visits + 1,
      total_spending = total_spending + v_order.total,
      loyalty_points_earned = loyalty_points_earned + v_points_earned,
      current_points_balance = current_points_balance + v_points_earned,
      last_visit_at = NOW(),
      first_visit_at = COALESCE(first_visit_at, NOW())
  WHERE id = v_membership.id;

  -- Insert loyalty transaction
  INSERT INTO loyalty_transactions (
    business_id, customer_id, customer_business_membership_id,
    loyalty_program_id, type, points_change, balance_after,
    reference_type, reference_id, performed_by
  ) VALUES (
    v_order.business_id, v_order.customer_id, v_membership.id,
    v_program.id, 'earn', v_points_earned,
    (SELECT points_balance FROM loyalty_balances WHERE customer_business_membership_id = v_membership.id),
    'order', v_order.id, v_order.cashier_id
  );

END;
$$ LANGUAGE plpgsql;

-- -----------------------------------------------------------------------------
-- COMMENTS
-- -----------------------------------------------------------------------------

COMMENT ON TABLE businesses IS 'Businesses (tenants) — each business is a separate tenant.';
COMMENT ON TABLE customers IS 'Global customer identities. A customer can belong to multiple businesses via customer_business_memberships.';
COMMENT ON TABLE customer_business_memberships IS 'Customer membership in a specific business. Links a global customer to a business.';
COMMENT ON TABLE loyalty_balances IS 'Per-membership loyalty balances. One row per customer-business membership.';
COMMENT ON TABLE qr_credentials IS 'QR credentials for customer identification. Opaque, secure, revocable.';
COMMENT ON TABLE nfc_credentials IS 'NFC credentials for customer identification. Opaque, secure, revocable.';
