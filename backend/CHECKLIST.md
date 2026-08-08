# CivicLens Backend Checklist

## Done

- [x] FastAPI app foundation with config, logging, security headers, exception handlers, limiter binding, and health endpoint.
- [x] Async SQLAlchemy database session factory and shared base repository/service/model/schema layers.
- [x] Auth domain scaffold completed: users, roles, sessions, login history, OTP verification, refresh rotation, logout, password reset.
- [x] Organizations domain implemented: organizations, departments, memberships, member invite/update/remove APIs.
- [x] Infrastructure assets domain implemented: asset CRUD and PostGIS-backed nearby/bbox repository methods.
- [x] Infrastructure passport domain implemented: passport fetch/create and degradation history APIs.
- [x] Inspection domain implemented: inspections, items, media metadata, status updates.
- [x] AI intelligence domain implemented: model registry, analysis submission, inference history.
- [x] Severity engine implemented: rules, assessment, manual override.
- [x] Notifications implemented: mock dispatch, current-user feed, mark-read endpoint.
- [x] Analytics implemented: dashboard metrics and degradation trends.
- [x] All business routers mounted under `/api/v1`.
- [x] Backend Dockerfile and local docker-compose stack added.

## To Do

- [ ] Add Alembic migrations for all domain tables, indexes, constraints, and PostGIS extensions.
- [ ] Expand authorization from system role checks to organization-scoped membership checks.
- [ ] Add real MinIO upload handling and ONNX inference execution behind `/prediction/predict`.
- [ ] Add PostGIS coordinate serialization for GeoJSON responses instead of placeholder coordinates.
- [ ] Add integration tests against a disposable PostgreSQL/PostGIS database.
- [ ] Add seed data for roles, permissions, severity rules, and default AI model metadata.
