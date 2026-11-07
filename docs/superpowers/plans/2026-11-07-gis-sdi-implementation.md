# GIS/SDI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Відтворювано розгорнути та відновити GIS/SDI на одному фізичному GIS-вузлі.

**Architecture:** Окремий MAAS region+rack провіжинить Ubuntu LTS. Bootstrap запускає однонодовий k3s та Argo CD, який синхронізує публічний GitHub-репозиторій. Критичні копії зберігаються на окремому NAS.

**Tech Stack:** MAAS, cloud-init, k3s, Argo CD, GitHub Actions, Helm, Kustomize, SOPS/age, PostGIS, RustFS, GeoNode, GeoServer, Martin, TiTiler, Prometheus, Grafana, Alertmanager, Loki, Alloy.

**Spec:** [Архітектура GIS/SDI](../specs/2026-11-07-gis-sdi-design.md).

## Global Constraints

- Один фізичний GIS-сервер із k3s, окремий малий вузол MAAS і NAS для копій.
- CI не потребує доступу до Kubernetes API. Merge в GitHub не запускає операції з дисками.
- Початковий профіль доступу — внутрішні маршрути з TLS.
- Кожен каталог застосунку містить один явний спосіб рендерингу, Helm або Kustomize.
- Автоматичний prune дозволяється для безстанових ресурсів.
- Ключ розшифрування копій має бути доступний до запуску кластера.
- Публічний доступ, SSO та перенесення робочих даних мають окремі критерії приймання.

## Review Focus

- Помилка вибору вузла чи диска в MAAS має зупиняти операцію до виклику deploy. Завдання 2.
- Арго застосовує Git до недоступного кластера після відновлення зв’язку, а видалення маніфесту PVC не видаляє том автоматично. Завдання 3.
- Приватні дані недоступні через прямий URL GeoServer, Martin або TiTiler. Завдання 5.
- Втрата NAS під час backup не оновлює позначку останньої успішної копії. Завдання 7.
- Новий сервер відновлюється з NAS без залежності від старого кластера та його RustFS. Завдання 8.

---

## Межі робіт та карта файлів

- `docs/adr/` фіксує вимоги майданчика й матрицю версій. `docs/runbooks/` містить процедури, які виконуються поза GitOps.
- `bootstrap/` налаштовує MAAS, вузол і початковий Argo CD. `clusters/prod/` задає власність і склад production.
- `platform/` керує доступом, томами, секретами й телеметрією. `apps/` містить GIS-конфігурацію.
- `tests/` містить перевірки контрактів і smoke-тести. `.github/` запускає CI та призначає власників.
- Порядок робіт — фундамент (1–3), GIS і моніторинг (4–6), перевірка відновлення (7–8). Кожен етап має окремий критерій приймання. Тестовий кластер для CI або локальної перевірки може бути тимчасовим.

### 1. Зафіксувати вимоги майданчика і створити репозиторій

**Файли:** `README.md`, `.gitignore`, `.github/CODEOWNERS`, `docs/adr/0001-site-profile.md`, `docs/adr/0002-version-matrix.md`.

**Інтерфейс:** профіль містить CPU/RAM, диски та серійні номери, BMC/PXE, VLAN/DHCP, DNS/TLS, протокол і можливості NAS, обсяг та ріст даних, RPO/RTO і час заміни GIS-вузла. Матриця фіксує точні версії та джерела k3s, Argo, charts і images. PostGIS/GeoNode/GeoServer/Martin затверджуються як сумісний набір.

- [ ] Ініціалізувати Git і підключити публічний репозиторій plvnkv/gis-sdi-lab. Додати правила PR і CODEOWNERS для bootstrap, clusters, platform та workflows. Потрібен принаймні один доступний рев’юер окрім автора PR.
- [ ] Заповнити профіль реальними параметрами. Позначити невідомі значення як блокери відповідних робіт. Значення стенда можна застосувати лише в локальних перевірках.
- [ ] Підтвердити версії за upstream і smoke-тестами обраних образів. Зафіксувати точні версії й digests до першого релізу. Визначити сумісний брокер GeoNode, режим RustFS, оператор або спосіб керування PostgreSQL і механізм NAS backup.
- [ ] Перевірити `git status --short`, `git check-ignore -q .env` і правила GitHub. Очікування — локальні секрети ігноруються, прямий запис до main обмежений, правила вимагають PR-перевірку після підключення CI. Коміт `docs: define GIS site and release baseline`.

### 2. Bootstrap MAAS і k3s

**Файли:** `bootstrap/maas/inventory.example.yaml`, `bootstrap/maas/cloud-init.yaml`, `bootstrap/maas/deploy.sh`, `bootstrap/k3s/config.yaml`, `bootstrap/k3s/install.sh`, `tests/bootstrap/test-deploy.sh`, `docs/runbooks/bootstrap.md`.

**Інтерфейси:** `deploy.sh --inventory FILE --system-id ID` друкує план. Виконання потребує явного прапорця `--apply` і збігу системного ID, серійних номерів дисків та статусу вузла. `install.sh --config FILE` встановлює закріплений k3s з embedded etcd та шифруванням Secrets.

- [ ] Написати shell-тест із підставним MAAS CLI. Невідомий ID, відмінні диски й відсутній `--apply` мають дати нуль викликів deploy. Виконати `bash tests/bootstrap/test-deploy.sh` і зафіксувати початкове падіння.
- [ ] Реалізувати перевірку плану та конфігурацію MAAS/cloud-init. У runbook задокументувати окремий вузол MAAS, BMC, DHCP/PXE та доступ до копій перед перевстановленням. Монтувати потрібні диски до старту k3s. Відсутній диск має зупиняти bootstrap.
- [ ] Повторити тест. На стенді виконати commissioning, встановлення ОС і повторний bootstrap. `sudo k3s kubectl wait --for=condition=Ready node --all --timeout=180s` має пройти, повторний bootstrap зберігає той самий кластер і стан. Коміт `feat: provision GIS node with MAAS and k3s`.

### 3. Передати кластер під керування Argo CD

**Файли:** `bootstrap/argocd/install.sh`, `clusters/prod/root.yaml`, `clusters/prod/kustomization.yaml`, `clusters/prod/projects.yaml`, `platform/ingress/`, `platform/storage/`, `platform/secrets/`, `.github/workflows/validate.yaml`, `tests/gitops/validate.sh`.

**Інтерфейси:** `bootstrap/argocd/install.sh --root clusters/prod/root.yaml` встановлює Argo, інтеграцію SOPS/age та root Application із публічним URL та окремим захищеним джерелом конфігурації майданчика й секретів. `bash tests/gitops/validate.sh clusters/prod` рендерить кожне джерело як Argo, перевіряє схеми з CRD, зафіксовані джерела та політику для критичних PVC.

- [ ] Додати негативні фікстури для plaintext Secret, образу з `latest`, неправильного namespace/AppProject і критичного PVC з дозволеним prune. Запустити validate до реалізації, потім вимагати відхилення кожної фікстури.
- [ ] Додати root і AppProjects з обмеженими джерелами та призначеннями, єдиного власника ресурсів Argo, черговість CRD/контролерів, читання публічного GitHub URL без credentials, SOPS CMP і окремий шлях введення age-ключа. Додати TLS через ingress, мережеві політики, локальні PV з Retain і захист критичних PVC. У CI закріпити інструменти та actions, додати secret scanning і зробити validate обов’язковим check.
- [ ] Запустити validate з чистого checkout. У тимчасовому кластері перевірити merge → sync, reconcile після перерви зв’язку, self-heal після ручної зміни ConfigMap і збереження критичного PVC після вилучення маніфесту. Коміт `feat: bootstrap Argo CD and protect GitOps state`.

### 4. Підняти PostGIS і RustFS

**Файли:** `apps/postgis/`, `apps/rustfs/`, `clusters/prod/data.yaml`, `tests/gis/data.sh`.

**Інтерфейси:** PostgreSQL Service `postgis-rw` з базами `geonode` і `gis`. RustFS Service `rustfs` з тестовим COG у бакеті `rasters`. DSN та S3 credentials передаються через окремі Secrets. Сценарій `bash tests/gis/data.sh` читає параметри з тестового оточення.

- [ ] Додати перевірки `PostGIS_Full_Version()`, запису контрольної геометрії, відмови запису під роллю Martin і S3 put/head/range read з окремими обліковими даними. Зафіксувати падіння до розгортання.
- [ ] Підключити закріплені артефакти, локальні PV, probes, requests/limits, окремі ролі та бакети. Ініціалізація має витримувати повторний sync без скидання даних. Базові копії й WAL інтегруються у завданні 7.
- [ ] Повторити тест після rollout і після перезапуску подів. Перевірити, що контрольні дані та доступи збереглися. Коміт `feat: deploy persistent GIS data services`.

### 5. Розгорнути GeoNode, GeoServer, Martin і TiTiler

**Файли:** `apps/geonode/`, `apps/martin/`, `apps/titiler/`, `clusters/prod/gis.yaml`, `tests/gis/smoke.sh`, `.github/workflows/images.yaml` якщо потрібні власні образи.

**Інтерфейси:** споживає бази, S3 і Secrets із завдання 4. `bash tests/gis/smoke.sh` приймає URL сервісів і тестові облікові дані з оточення та повертає ненульовий код при будь-якій невдалій перевірці.

- [ ] Додати smoke-тест публікації тестового шару GeoNode з OGC-відповіддю GeoServer, MVT від Martin і растрового тайла від TiTiler. Додати негативні перевірки анонімного доступу до приватного шару через всі відповідні endpoints та відмови TiTiler на URL поза дозволеним джерелом. Запустити перед розгортанням і зафіксувати падіння.
- [ ] Розгорнути GeoNode web, Celery, брокер і узгоджений GeoServer. Міграцію виконувати окремою задачею, повторний запуск має бути безпечним. Зберігати медіа та DATA_DIR. Налаштувати Martin з явним списком джерел і read-only роллю. Для TiTiler обмежити джерела та egress. Власні образи збирати в GHCR і просувати через PR з digest.
- [ ] Запустити smoke-тест після першого sync і після повторного запуску міграції. Приватні дані мають бути недоступні напряму, тестова публікація та обидва типи тайлів працюють. Коміт `feat: deploy GIS publication and tile services`.

### 6. Додати моніторинг та збір логів

**Файли:** `platform/observability/`, `clusters/prod/observability.yaml`, `tests/observability/rules.yaml`, `docs/runbooks/alerts.md`.

**Інтерфейси:** Prometheus приймає метрики платформи й GIS, Alloy надсилає логи до monolithic Loki, Grafana відтворює дашборди з Git. Зовнішній probe виконується на вузлі MAAS із незалежним каналом сповіщень.

- [ ] Додати сценарії для алертів про недоступний GIS, брак диска, Argo sync error та прострочену копію. `promtool test rules tests/observability/rules.yaml` має спочатку виявити відсутні правила.
- [ ] Розгорнути моніторинг, обмежити retention і дискові бюджети, додати правила, дашборди й контрольований канал тестового сповіщення. Налаштувати зовнішню перевірку TLS GIS endpoint.
- [ ] Повторити promtool. Перевірити в Grafana тестову метрику і тестовий лог. На стенді зупинити GIS-вузол та перевірити отримання сповіщення з вузла MAAS. Коміт `feat: monitor GIS services and node availability`.

### 7. Автоматизувати резервування на NAS

**Файли:** `platform/storage/backup/`, `tests/backup/verify.sh`, `docs/runbooks/backup.md`.

**Інтерфейс:** кожна успішна копія публікує на NAS запис із UTC-часом, ID набору, ревізією Git, версіями даних і контрольними сумами. Alertmanager отримує час останньої успішної копії через метрику backup. Секрети доступу й розшифрування відновлюються поза кластером.

- [ ] Написати `bash tests/backup/verify.sh` з перевіркою повноти каталогу копії та сценарієм відключення NAS під час запису. Очікування — неповний набір не публікується як успішний і метрика не просувається.
- [ ] Автоматизувати копії MAAS, k3s/etcd з окремим зберіганням токена, PostGIS з WAL за потреби RPO, RustFS із метаданими, GeoNode media та GeoServer DATA_DIR. Документувати узгоджену точку резервування даних із паузою записів і задач на час її створення. Налаштувати retention та окремі права запису й видалення відповідно до можливостей NAS.
- [ ] Запустити перевірку з реальним NAS, включно з відмовою запису та повторним запуском. Перевірити прострочення алертом із завдання 6. Коміт `feat: back up GIS and platform state to NAS`.

### 8. Провести відновлення й приймання

**Файли:** `docs/runbooks/restore.md`, `docs/runbooks/upgrade.md`, `docs/runbooks/rotate-secrets.md`, `docs/runbooks/acceptance.md`.

**Інтерфейси:** використовує bootstrap, каталог копій, validate та GIS smoke-тести попередніх завдань.

- [ ] Записати два сценарії відновлення. Для чистого вузла розгорнути ОС, k3s і GitOps з GitHub, синхронізувати лише платформу й залежності відновлення, імпортувати дані з NAS, підняти GIS внутрішньо та відкрити маршрути після smoke-тестів. Для etcd відновити сумісну версію k3s, той самий токен і PV.
- [ ] Описати ротацію ключів age, Git credentials та сервісних секретів. Для оновлень окремо визначити відкат Git і відновлення даних після незворотної міграції.
- [ ] На чистому вузлі без доступу до старого GIS-сервера відновити контрольний набір. Запустити `bash tests/gis/data.sh` у режимі перевірки відновлених даних і `bash tests/gis/smoke.sh`. Перевірити відновлення MAAS та etcd окремо у безпечному середовищі.
- [ ] Занести фактичний RTO, найновішу відновлену транзакцію для виміру RPO, результати перевірок і ручні кроки в acceptance. Перенесення робочих даних можливе після виконання погоджених RPO/RTO. Коміт `docs: verify disaster recovery and release readiness`.
