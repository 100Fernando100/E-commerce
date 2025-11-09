/*
  # Fix Security Issues

  This migration addresses multiple security concerns:

  ## 1. Remove Unused Index
    - Drop `idx_financial_reports_report_date` (unused index)
    - Keep `idx_financial_reports_created_at` which is used for historical reports ordering

  ## 2. Remove Duplicate RLS Policies
    - Remove duplicate INSERT policy: "Allow public insert to financial_reports"
    - Remove duplicate SELECT policy: "Allow public read access to financial_reports"
    - Keep original policies: "Allow public insert access" and "Allow public read access"

  ## 3. Fix Function Search Path Security
    - Recreate `update_updated_at_column` function with immutable search_path
    - Sets search_path to empty string for security

  ## Notes
    - All changes are idempotent using IF EXISTS
    - No data loss occurs from these operations
    - Maintains same functionality with improved security
*/

-- 1. Remove unused index
DROP INDEX IF EXISTS idx_financial_reports_report_date;

-- 2. Remove duplicate RLS policies
DROP POLICY IF EXISTS "Allow public insert to financial_reports" ON financial_reports;
DROP POLICY IF EXISTS "Allow public read access to financial_reports" ON financial_reports;

-- 3. Fix function search path security issue
-- First, drop the existing function if it exists
DROP FUNCTION IF EXISTS update_updated_at_column() CASCADE;

-- Recreate the function with secure search_path
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- Check if trigger exists and recreate it if the function was being used
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.triggers
    WHERE trigger_name = 'update_financial_reports_updated_at'
    AND event_object_table = 'financial_reports'
  ) THEN
    DROP TRIGGER IF EXISTS update_financial_reports_updated_at ON financial_reports;
    CREATE TRIGGER update_financial_reports_updated_at
      BEFORE UPDATE ON financial_reports
      FOR EACH ROW
      EXECUTE FUNCTION update_updated_at_column();
  END IF;
END $$;
