# PR Write-up — Phase 1 Vertical Slice + Phase 2 Planning

## Title
Phase 1 vertical slice with Supabase-backed static POC, setup docs, and Phase 2 implementation plan

## Motivation
- Convert the static proof-of-concept into a usable Phase 1 vertical slice that can send a real postcard via Supabase.
- Provide from-scratch setup instructions for a brand-new Supabase project.
- Document the agreed Phase 2 roadmap so implementation can continue with clear scope and acceptance criteria.

## Description
### Added
- `PHASE1_SETUP.md`
  - End-to-end setup for a fresh project, SQL Editor workflow, localhost serving guidance, and verification flow.
- `supabase/schema.sql`
  - Core schema (`users`, `postcards`), `pgvector` support, vector index, and recipient matching RPC.
- `PHASE2_PLAN.md`
  - Planned Phase 2 lifecycle, schema extensions, RPC list, frontend integration points, and acceptance criteria.

### Updated
- `Static-POC.html`
  - Reworked from hardcoded demo behavior to interactive Supabase-backed flows.
  - Added onboarding persistence, compose/send integration, inbox/route hydration, and runtime safeguards for static serving constraints.

## Testing
- Verified commits were created for the included changes.
- Verified repository state after each commit.
