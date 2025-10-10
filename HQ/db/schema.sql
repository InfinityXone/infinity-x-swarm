CREATE EXTENSION IF NOT EXISTS vector;
CREATE TABLE IF NOT EXISTS faucets(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),label text,api_url text,chain text,enabled boolean DEFAULT true,rate_limit_per_min int DEFAULT 1000,auth_token text,last_checked timestamptz);
CREATE TABLE IF NOT EXISTS wallets(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),address text,encrypted_key text,chain text,status text DEFAULT 'active',rotation_interval int DEFAULT 86400,last_rotated timestamptz);
CREATE TABLE IF NOT EXISTS satellites(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),name text UNIQUE,region text,url text,status text,agent_version text,last_ping timestamptz);
CREATE TABLE IF NOT EXISTS jobs(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),type text,payload jsonb,status text DEFAULT 'queued',satellite_id uuid REFERENCES satellites(id),created_at timestamptz DEFAULT now(),dispatched_at timestamptz,completed_at timestamptz);
CREATE TABLE IF NOT EXISTS logs(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),source text,level text,message text,ctx jsonb,ts timestamptz DEFAULT now());
CREATE TABLE IF NOT EXISTS memory_vectors(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),agent_id text,context text,embedding vector(1536),created_at timestamptz DEFAULT now());
CREATE TABLE IF NOT EXISTS profit_ledger(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),satellite_id uuid,revenue numeric,cost numeric,net numeric,ts timestamptz DEFAULT now());
