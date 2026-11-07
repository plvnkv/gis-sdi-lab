# Матриця версій

Перед першим rollout зафіксувати точні версії, джерела й digests. Вибір потребує тестів на цільовій архітектурі.

| Група | Перевірка |
|---|---|
| MAAS / Ubuntu LTS / k3s / Argo CD | PXE, bootstrap, синхронізація, відновлення etcd |
| PostgreSQL / PostGIS / GeoNode / GeoServer / брокер / Martin | Міграції, публікація шару, права, MVT, відновлення БД |
| RustFS / TiTiler | COG, range read, права, експорт та відновлення |
| Prometheus / Grafana / Alertmanager / Loki / Alloy | Метрики, алерти, логи, обмежений retention |
