# GIS/SDI GitOps

Окремий MAAS готує фізичний GIS-вузол. k3s та Argo CD утворюють контур розгортання, а NAS зберігає резервні копії.

- [Архітектура](docs/superpowers/specs/2026-11-07-gis-sdi-design.md)
- [План реалізації](docs/superpowers/plans/2026-11-07-gis-sdi-implementation.md)
- [Параметри майданчика](docs/adr/0001-site-profile.md)
- [Bootstrap](docs/runbooks/bootstrap.md)

Локальна перевірка guardrails MAAS потребує Bash і jq.

```bash
bash tests/bootstrap/test-deploy.sh
```
