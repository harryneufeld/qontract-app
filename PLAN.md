# Refactor implementation order

Agreed with Harry on 2026-10-01. FamilyPlanner is the production system and must remain supported until the refactor provides complete feature/data parity and a verified migration. Existing code and tests take precedence over old setup notes.

1. Correct READMEs and issue descriptions to reflect implemented features and approval comments, including Linux Docker deployment.
2. Tenant access and membership: close cross-tenant administration gaps first; introduce multiple memberships, membership-specific roles, tenant switching, configurable public registration, and code/link invitations. Track in [backend #13](https://github.com/harryneufeld/qontract-backend/issues/13) and [app #12](https://github.com/harryneufeld/qontract-app/issues/12).
3. Finish focused usability changes in [app #38](https://github.com/harryneufeld/qontract-app/issues/38).
4. Plan authenticated legacy export and backend import. Inventory all production features and data, implement missing parity (especially billing periods and price history), then prove completeness with dry runs and reconciliation. Track export planning in [FamilyPlanner #1](https://github.com/harryneufeld/FamilyPlanner/issues/1).
5. Add revocable sessions and rotating refresh tokens in [backend #44](https://github.com/harryneufeld/qontract-backend/issues/44), followed by the existing 2FA and login-anomaly issues.

The approved audit cleanup in [backend #38](https://github.com/harryneufeld/qontract-backend/issues/38) remains separate schema work: preserve `Documents.UserId`, retain only base audit fields, and remove unused relationships after checking actual data. Migration must preserve legitimate shared-file relationships from legacy FamilyPlanner even though its schema differs from the new backend's unused join.

Contract amounts are billed per selected period. Current lifetime-value proration is a known parity gap, not the intended financial model. Use FamilyPlanner as the reference and record proposed improvements explicitly.
