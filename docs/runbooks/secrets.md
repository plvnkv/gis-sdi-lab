# Секрети майданчика

На етапі пілота адміністратор імпортує SOPS/age-файли у кластер через `platform/secrets/import.sh`. Argo CD керує посиланнями на Secrets, а ключ age залишається в незалежному сховищі. Це рішення замінює пропозицію про плагін розшифрування Argo CD. [Підхід Argo CD до керування секретами](https://argo-cd.readthedocs.io/en/release-3.0/operator-manual/secret-management/)

1. Дочекатися створення namespace `gis`. На довіреній робочій станції підготувати `sops`, `jq` і `kubectl` та перевірити цільовий контекст. Передавати шлях до захищеної age identity через `SOPS_AGE_KEY_FILE`.
2. У захищеному сховищі підготувати один зашифрований SOPS JSON-файл на один Kubernetes Secret. Вхідний документ має містити `apiVersion: v1`, `kind: Secret`, `type: Opaque`, `metadata.name`, `metadata.namespace: gis` та `data` зі значеннями в Base64. Base64 є форматом Kubernetes, а конфіденційність забезпечує шифрування SOPS. Шифрувати до збереження файлу. Зашифровані файли майданчика й ключ age зберігаються поза публічним репозиторієм і окремо один від одного.
3. Перевірити файл без запису, потім явно виконати імпорт. Повторний імпорт використовує того самого field manager. Конфлікт власності зупиняє операцію.

```bash
bash platform/secrets/import.sh --context "$GIS_CONTEXT" --file "$SECRET_FILE"
bash platform/secrets/import.sh --context "$GIS_CONTEXT" --file "$SECRET_FILE" --apply
```

Сценарій перевіряє розшифрований документ перед викликом Kubernetes. Виводяться ім’я Secret і контекст. Після ротації облікових даних узгодити їх із сервісом і перезапустити споживачів, які читають Secret зі змінних середовища. Під час відновлення повторити імпорт до запуску GIS-застосунків.

[SOPS](https://github.com/getsops/sops)
