# Підготовка GIS-вузла

1. На окремому MAAS region+rack налаштувати мережу BMC і PXE. Узгодити DHCP до його ввімкнення.
2. Провести commissioning. Звірити системний ID, фізичні диски й розмітку MAAS. Для повторного встановлення перевірити наявність придатної копії на NAS та підтвердити втрату даних на дисках, які буде перерозмічено.
3. Виділити вузол у MAAS. Скопіювати приклад інвентарю в `inventory.local.json` та заповнити перевіреними значеннями. Увійти в MAAS CLI локально, поза Git.
4. Виконати попередній перегляд `bash bootstrap/maas/deploy.sh --inventory inventory.local.json --system-id ID`. Після звірки виконати ту саму команду з `--apply`.
5. Після завантаження ОС перевірити `cloud-init status --wait`. Монтування та інсталяція k3s потребують затвердженого профілю дисків та версії.

Після підготовки дисків додати постійні монтування за UUID. Перевірити їх через `findmnt`. Звірити зафіксовану версію k3s і SHA-256 перевіреного upstream installer з матрицею версій. Виконати на GIS-вузлі, підставивши значення з профілю майданчика.

```bash
sudo bash bootstrap/k3s/install.sh --config bootstrap/k3s/config.yaml \
  --version "$K3S_VERSION" --installer "$K3S_INSTALLER" --sha256 "$K3S_INSTALLER_SHA256" \
  --mount /srv/gis
```

Після запуску покласти оригінальний k3s server token у незалежне сховище секретів. Його потребує відновлення etcd.

[MAAS CLI](https://canonical.com/maas/docs/stable/how-to-guides/manage-machines/), [конфігурація k3s](https://docs.k3s.io/installation/configuration)

## Початковий Argo CD

Перевірити поточний контекст kubectl. Підготувати install.yaml затвердженого релізу Argo CD та його перевірений SHA-256. Запустити з адміністративним доступом до кластера після появи маніфестів у гілці main.

```bash
ARGOCD_INSTALL_MANIFEST=/path/to/install.yaml ARGOCD_INSTALL_SHA256="$ARGOCD_SHA256" \
  bash bootstrap/argocd/install.sh --root clusters/prod/bootstrap/root.yaml
kubectl -n argocd get application gis-root
kubectl -n argocd get appproject gis
```

Root Application керує деклараціями в clusters/prod. Сам root і його bootstrap AppProject застосовуються окремо. Публічне джерело читається без Git-ключа. Перед додаванням сервісів із секретами налаштувати захищене джерело майданчика.

## Мережева основа GIS

Після синхронізації root дочірня Application `gis-network` створює namespace `gis` та політики вхідного трафіку. Pod-и в `gis` можуть спілкуватися між собою. Для доступу через штатний Traefik k3s шаблон Pod має містити label `gis-sdi-lab/ingress: enabled` і оголошувати TCP container port з іменем `gis-http`. Service для маршруту має вказувати цей порт у `targetPort`.

Перед підключенням першого сервісу перевірити, що контролер NetworkPolicy увімкнений, а Pod-и Traefik у `kube-system` мають label `app.kubernetes.io/name=traefik`. На тестовому кластері перевірити з'єднання з іншого Pod у `gis`, відмову з іншого namespace та маршрут Traefik до позначеного Pod. DNS, TLS, firewall для доступу з мережі майданчика та egress-політики налаштовуються окремо.

[Мережеві сервіси k3s](https://docs.k3s.io/networking/networking-services), [Kubernetes NetworkPolicy](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
