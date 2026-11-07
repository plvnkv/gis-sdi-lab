# Martin

Martin 1.16.1 працює одним екземпляром із пулом PostgreSQL до чотирьох з’єднань та кешем 32 МБ. Пілот публікує один синтетичний шар `pilot-points` із внутрішнього ClusterIP. Джерела додаються явно в конфігурації та через окремі привілеї БД. [Конфігурація Martin 1.16.1](https://github.com/maplibre/martin/blob/martin-v1.16.1/docs/content/files/generated_config.md)

1. Після запуску PostGIS виконати `apps/martin/pilot.sql` у БД `gis` як адміністратор. Використати окрему роль `martin_reader`. Задати пароль інтерактивною командою psql `\password martin_reader`. Для раніше створеної ролі перевірити членство в інших ролях і відсутність прав запису.
2. Імпортувати Secret `gis/martin-reader` із ключем `database-url` за [процедурою секретів](secrets.md). DSN вказує на `postgis-rw.gis.svc.cluster.local:5432/gis` під користувачем `martin_reader`. Спецсимволи в паролі потребують URL-кодування.
3. Явно синхронізувати `gis-martin` в Argo CD. Виконати `kubectl -n gis port-forward svc/martin 3000:3000`, потім `MARTIN_URL=http://127.0.0.1:3000 bash tests/gis/martin.sh`. Підключитися до PostgreSQL під `martin_reader` і перевірити, що SELECT працює, а INSERT у тестову таблицю відхиляється.
