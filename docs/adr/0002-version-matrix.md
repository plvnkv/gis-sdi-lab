# Матриця версій

Перед першим rollout зафіксувати точні версії, джерела й digests. Вибір потребує тестів на цільовій архітектурі.

| Група | Перевірка |
|---|---|
| MAAS / Ubuntu LTS / k3s / Argo CD | PXE, bootstrap, синхронізація, відновлення etcd |
| PostgreSQL / PostGIS / GeoNode / GeoServer / брокер / Martin | Міграції, публікація шару, права, MVT, відновлення БД |
| RustFS / TiTiler | COG, range read, права, експорт та відновлення |
| Prometheus / Grafana / Alertmanager / Loki / Alloy | Метрики, алерти, логи, обмежений retention |

## Образи першого пілота

Для Linux amd64 перевірено наявність образів у реєстрі. Digests записані в маніфестах. Сумісність під навантаженням і відновлення залишаються критеріями приймання.

- PostgreSQL 17 / PostGIS 3.6 — `postgis/postgis:17-3.6`.
- RustFS 1.0.4 — `rustfs/rustfs:1.0.4`.
- Martin 1.16.1 — `ghcr.io/maplibre/martin:1.16.1`, digest зафіксовано для індексу з Linux amd64.
