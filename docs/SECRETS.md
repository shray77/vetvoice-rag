# Настройка секретов в GitHub

Эта инструкция объясняет, **как правильно добавить HF_TOKEN и другие секреты** в репозиторий `shray77/vetvoice-rag`, чтобы они подхватывались в GitHub Actions.

## ❓ Почему секрет может не работать (даже если ты его добавил)

### 1. Секрет добавлен в **fork**, а не в исходный репо
GitHub не копирует секреты при fork-е. Если ты сделал fork репо `shrayyyy/vetvoice-rag` → `shray77/vetvoice-rag`, то секреты из исходного репо **не скопировались**. Их нужно добавить заново в **свой** fork.

**Проверь:** зайди на `https://github.com/shray77/vetvoice-rag/settings/secrets/actions` — там должен быть `HF_TOKEN` в списке.

### 2. Секрет добавлен в **Dependabot** или **Codespaces**, а не в **Actions**
В настройках репо есть **4 разных раздела** секретов:
- ✅ `Settings → Secrets and variables → Actions` ← **сюда нужно добавить**
- ❌ `Settings → Secrets and variables → Codespaces`
- ❌ `Settings → Secrets and variables → Dependabot`
- ❌ `Settings → Environments → ...` (если используешь environments)

Если секрет добавлен не в тот раздел — Actions его не увидит.

### 3. Секрет добавлен в **Environment**, а не в **Repository**
Если в workflow указано `environment: production`, то секрет должен быть в **Environment**, а не в **Repository**. В наших workflow `environment` не используется, поэтому секрет должен быть в **Repository secrets**.

### 4. PAT с `repo` правами не помогает с секретами
PAT (Personal Access Token) даёт доступ к **содержимому** репо, но не к секретам. Секреты можно добавить **только через веб-интерфейс GitHub** или через API с правами админа репо.

### 5. Секрет добавлен, но workflow не активирован на fork-е
Если репо — fork, то по умолчанию GitHub **отключает** Actions. Зайди в `Actions` tab — там должна быть зелёная кнопка "I understand my workflows, go ahead and enable them". Пока не нажмёшь — workflows не запустятся, и секреты не будут проверены.

## ✅ Как правильно добавить HF_TOKEN

### Шаг 1: Получи HF токен

1. Зайди на https://huggingface.co/settings/tokens
2. Нажми **"New token"**
3. Name: `vetvoice-rag-ci`
4. Type: **Write** (нужен для upload в Space)
5. Скопируй токен (начинается с `hf_...`)

### Шаг 2: Добавь секрет в GitHub

1. Зайди на **ПРЯМУЮ** ссылку:
   ```
   https://github.com/shray77/vetvoice-rag/settings/secrets/actions
   ```
2. Нажми **"New repository secret"**
3. Name: `HF_TOKEN` (точно так, без пробелов)
4. Secret: вставь токен
5. Нажми **"Add secret"**

### Шаг 3: Проверь, что секрет добавился

После добавления `HF_TOKEN` должен появиться в списке секретов с бейджем "Updated X minutes ago".

Если в списке пусто — секрет не добавился. Возможные причины:
- У тебя нет прав **admin** на репо `shray77/vetvoice-rag`
- Ты добавляешь в **fork**, но fork не активирован для Actions (нужно зайти в Actions tab и нажать "I understand my workflows, go ahead and enable them")

### Шаг 4: Триггерни workflow вручную

1. Зайди на `https://github.com/shray77/vetvoice-rag/actions/workflows/deploy-hf.yml`
2. Нажми **"Run workflow"** → выбери branch `main` → **"Run workflow"**
3. Открой запущенный run
4. В шаге `Verify HF_TOKEN is configured` должно появиться:
   ```
   ::notice::HF_TOKEN is set (starts with hf_x...)
   ```
   Если видишь `::error::HF_TOKEN secret is NOT configured` — секрет не добавлен.

## 🔍 Диагностика: как проверить, что секрет доходит до workflow

### Способ 1: В логах Actions (безопасный)
Я уже добавил шаг `Verify HF_TOKEN is configured` в `deploy-hf.yml`. Он покажет **первые 4 символа** токена (не весь токен!) — это подтвердит, что секрет подхватился.

### Способ 2: Через GitHub CLI (если установлен)
```bash
gh secret list -R shray77/vetvoice-rag
```
Должен показать:
```
HF_TOKEN  Updated 2024-...
```

### Способ 3: Через API
```bash
curl -H "Authorization: token YOUR_GITHUB_PAT" \
  https://api.github.com/repos/shray77/vetvoice-rag/actions/secrets
```
Вернёт список имён секретов (без значений).

## 🎯 Какие секреты нужны для vetvoice-rag

| Секрет | Где получить | Зачем нужен | Обязателен? |
|--------|--------------|-------------|-------------|
| `HF_TOKEN` | https://huggingface.co/settings/tokens | Деплой на HF Space + upload RAG KB | ✅ для деплоя |
| `NCBI_API_KEY` | https://www.ncbi.nlm.nih.gov/account/settings/ | PubMed API (без него rate-limit 3 req/sec) | ⚠️ опционально |
| `GITHUB_TOKEN` | автоматически | Создание релизов | ✅ но он уже есть |

## 📋 Чеклист "секрет не работает"

- [ ] Секрет добавлен в `Settings → Secrets and variables → Actions` (не в Codespaces/Dependabot)
- [ ] Имя секрета точно `HF_TOKEN` (без нижнего подчёркивания в начале, без пробелов)
- [ ] У тебя есть права **admin** на репо (или ты владелец)
- [ ] Если это fork — Actions tab активирован (зайди в Actions → нажми зелёную кнопку)
- [ ] Workflow запущен на branch `main` (или том, что указан в `on:`)
- [ ] В логе шага `Verify HF_TOKEN is configured` видно `::notice::HF_TOKEN is set`

## 🛠️ Что я починил в workflow

### `update-rag.yml`
- **Было:** шаг `Check required secrets` читал `$HF_TOKEN` без `env:` → переменная всегда пустая → условие `if: env.HF_TOKEN != ''` всегда false → шаг download пропускался.
- **Стало:** top-level `env:` блок экспортирует секрет во **все** шаги. Условие теперь работает правильно.

### `deploy-hf.yml`
- **Было:** если секрет пустой, `deploy_hf.py` падал с `exit(1)` без понятного сообщения.
- **Стало:** добавлен шаг `Verify HF_TOKEN is configured`, который падает **раньше** с понятной ошибкой и ссылкой на настройки.

## 🔗 Полезные ссылки

- Настройки секретов: https://github.com/shray77/vetvoice-rag/settings/secrets/actions
- Workflow runs: https://github.com/shray77/vetvoice-rag/actions
- HF токены: https://huggingface.co/settings/tokens
- Документация GitHub: https://docs.github.com/en/actions/security-guides/using-secrets-in-github-actions
