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

## GitOps-перевірки

Для локального рендерингу потрібні kubectl і Ruby. GitHub Actions запускає ці перевірки для pull request і push до main.

```bash
bash tests/gitops/test-policy.sh
bash tests/gitops/validate.sh clusters/prod
```

Початкова Application Argo CD керує проєктом GIS. Інструкція встановлення є в [runbook](docs/runbooks/bootstrap.md).

- [Локальне сховище GIS](docs/runbooks/storage.md)
- [Секрети майданчика](docs/runbooks/secrets.md)

- [PostGIS і RustFS](docs/runbooks/data-services.md)
- [Martin](docs/runbooks/martin.md)
