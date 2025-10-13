# Infinity X Swarm – Console (Next.js App Router)
Black–metallic UI with neon green accents. Groq is primary LLM; Cloud Run “services” + metrics are mocked until wired.
## Dev
npm run dev
## Env (Vercel → Project → Settings → Environment Variables)
- GROQ_API_KEY (required)
- GROQ_MODEL (optional, default: llama-3.1-70b-versatile)
- CLOUD_ADMIN_BASE (optional)
- SUPABASE_URL, SUPABASE_ANON_KEY (optional)
- NEXT_PUBLIC_API_BASE (optional)
## Wire real backends
Edit API routes under app/api/*
