# Порівняльний аналіз: Beehave vs LimboAI

## Загальна інформація

| Характеристика | Beehave | LimboAI |
|----------------|---------|---------|
| **Версія** | 2.9.1 | 1.5.1 |
| **Мова реалізації** | GDScript | C++ (GDScript для кастомних задач) |
| **Тип** | Editor Plugin | C++ Module / GDExtension |
| **Підтримка Godot** | 3.x, 4.x | 4.2 - 4.5 (залежно від версії) |
| **Ліцензія** | MIT | MIT |
| **Встановлення** | Просте (plugin) | GDExtension (просте) / Module (потрібна компіляція) |

---

## Основні можливості

### Beehave
- ✅ **Behavior Trees** (тільки BT)
- ✅ Візуальний редактор інтегрований у Godot Editor
- ✅ Debugger в редакторі
- ✅ Metrics/Monitoring продуктивності
- ✅ Blackboard система
- ✅ Багато готових composites/decorators/actions

### LimboAI
- ✅ **Behavior Trees** (BT)
- ✅ **Hierarchical State Machines** (HSM) — унікальна можливість
- ✅ Комбінування BT + HSM для складних AI
- ✅ Візуальний редактор BT
- ✅ Візуальний debugger
- ✅ Blackboard з планами (blackboard plans)
- ✅ Blackboard scopes (запобігання конфліктів імен)
- ✅ Демо-проєкт з tutorial
- ✅ Unit tests
- ✅ C# підтримка

---

## Технічні відмінності

### Продуктивність

**LimboAI (C++):**
- Швидша виконавча продуктивність завдяки C++
- Краще для великих проєктів з багатьма AI агентами
- Менше overhead на виконанні задач

**Beehave (GDScript):**
- Повільніше через GDScript
- Для малих/середніх проєктів різниця може бути непомітна
- Легше дебажити та модифікувати код

### Архітектура

**LimboAI:**
- Модульна архітектура (BT + HSM як окремі системи)
- Підтримка BTSubtree (піддерева з окремих ресурсів)
- Більш структурований підхід до організації AI

**Beehave:**
- Монолітна структура (все в одному дереві)
- Більш простий підхід, зрозуміліший для початківців

---

## Зручність використання

### Навчання та документація

**LimboAI:**
- ✅ Детальна онлайн документація (ReadTheDocs)
- ✅ Demo проєкт з tutorial
- ✅ Багато прикладів
- ✅ Активна спільнота (Discord)
- ⚠️ Більш складний для початківців через C++ та HSM

**Beehave:**
- ✅ Простіший для розуміння
- ✅ GDScript — легше модифікувати
- ⚠️ Менше документації
- ⚠️ Немає demo проєкту з tutorial

### Робота з редактором

**LimboAI:**
- Візуальний редактор BT (GraphEdit-based)
- Візуальний debugger в runtime
- BehaviorTreeView для in-game візуалізації
- Blackboard plan editor

**Beehave:**
- Візуальний редактор BT (GraphEdit-based)
- Debugger в редакторі Godot
- Metrics у real-time

### Створення кастомних задач

**LimboAI:**
- GDScript для створення кастомних задач (BTAction, BTCondition, BTDecorator, BTComposite)
- Повна підтримка C# (через GDExtension)
- Type-safe API

**Beehave:**
- GDScript для кастомних задач
- Легше модифікувати код аддона (GDScript)
- Менш типізований

---

## Унікальні можливості

### LimboAI
1. **State Machines + Behavior Trees** — комбінування обох підходів
2. **Blackboard Plans** — визначення змінних у BT ресурсі з override у BTPlayer
3. **Blackboard Scopes** — запобігання конфліктів імен, sharing між агентами
4. **BTSubtree** — виконання піддерев з окремих ресурсів
5. **Performance Monitors** — вбудовані інструменти моніторингу
6. **Event-based HSM** — подієві переходи у state machines
7. **Delegation Option** — швидкий прототип через callback функції

### Beehave
1. **Metrics System** — глобальні метрики продуктивності
2. **Reactive Composites** — селектори/послідовності що реагують на зміни
3. **Randomized Composites** — випадковий порядок виконання
4. **Debugger Integration** — повна інтеграція з Godot debugger

---

## Встановлення та налаштування

### Beehave
1. Клонувати/скачати addon
2. Помістити в `addons/beehave/`
3. Увімкнути plugin в Project Settings
4. Готово

### LimboAI
**Варіант 1: GDExtension (рекомендовано)**
1. Скачати precompiled build
2. Скопіювати в `addons/limboai/`
3. Готово (обмеження: немає вбудованої документації)

**Варіант 2: C++ Module**
1. Скачати source code
2. Компілювати Godot з модулем
3. Більше функцій, але складніше

---

## Підтримка платформ

### LimboAI
- ✅ Windows (x86_64)
- ✅ Linux (x86_64, arm64)
- ✅ macOS (arm64, universal)
- ✅ Android (arm32, arm64, x86_32, x86_64)
- ✅ iOS (arm64, simulator)
- ✅ Web (wasm32, wasm32.nothreads)

### Beehave
- ✅ Всі платформи (GDScript, немає компіляції)

---

## Коли використовувати Beehave

✅ **Вибирайте Beehave, якщо:**
- Проєкт малий/середній
- Потрібна швидка інтеграція без компіляції
- Хочете легко модифікувати код аддона
- Потрібні тільки Behavior Trees (без State Machines)
- Важлива простота навчання
- Працюєте з Godot 3.x

### Переваги Beehave
- Простіше встановлення
- Легше навчитися
- GDScript — легко модифікувати
- Підтримка Godot 3.x та 4.x
- Вбудовані metrics

### Недоліки Beehave
- Тільки Behavior Trees (немає State Machines)
- Повільніше через GDScript
- Менше документації
- Немає demo/tutorial

---

## Коли використовувати LimboAI

✅ **Вибирайте LimboAI, якщо:**
- Потрібні складні AI системи (BT + HSM)
- Великий проєкт з багатьма AI агентами
- Потрібна висока продуктивність
- Хочете комбінувати різні підходи до AI
- Потрібна детальна документація та tutorial
- Працюєте тільки з Godot 4.x

### Переваги LimboAI
- Швидше через C++
- BT + HSM комбіновано
- Детальна документація + demo
- Blackboard plans/scopes
- Unit tests
- Підтримка C#
- Активна спільнота

### Недоліки LimboAI
- Складніше для початківців
- Потрібна Godot 4.x
- GDExtension версія має обмеження
- Більше overhead при налаштуванні

---

## Рекомендація для вашого проєкту

### Аналіз потреб:
1. **Воксельний survival проєкт** — можливо потрібні складні AI (вороги, NPC, тварини)
2. **Godot 4.x** — обидва аддони підтримують
3. **Продуктивність** — важлива для процедурної генерації + AI

### Рекомендація: **LimboAI**

**Чому:**
1. **State Machines + BT** — корисно для NPC з різними станами (мирний/боєвий/біжить)
2. **Продуктивність** — C++ краще для багатьох AI агентів
3. **Документація** — легше навчитися завдяки tutorial
4. **Масштабованість** — краще для великих проєктів
5. **Blackboard Plans** — зручно для різних типів NPC (перевизначення параметрів)

**Альтернатива: Beehave**
- Якщо AI буде простим (тільки патрулювання/атака)
- Якщо потрібна швидка інтеграція
- Якщо хочете легко модифікувати код

---

## Порівняльна таблиця функцій

| Функція | Beehave | LimboAI |
|---------|---------|---------|
| Behavior Trees | ✅ | ✅ |
| State Machines | ❌ | ✅ |
| Візуальний редактор | ✅ | ✅ |
| Debugger | ✅ | ✅ |
| Blackboard | ✅ | ✅ |
| Blackboard Plans | ❌ | ✅ |
| Blackboard Scopes | ❌ | ✅ |
| Metrics/Monitoring | ✅ | ✅ (Performance Monitors) |
| Demo/Tutorial | ❌ | ✅ |
| Unit Tests | ❌ | ✅ |
| C# підтримка | ❌ | ✅ |
| Reactive Composites | ✅ | ❌ |
| Randomized Composites | ✅ | ❌ |
| BTSubtree | ❌ | ✅ |
| Event-based HSM | ❌ | ✅ |
| GDScript для кастомних задач | ✅ | ✅ |
| Легко модифікувати код | ✅ (GDScript) | ⚠️ (C++) |
| Godot 3.x підтримка | ✅ | ❌ |

---

## Висновок

**Для вашого проєкту (survival воксельний):**
- **LimboAI** — кращий вибір через продуктивність, BT+HSM, документацію
- **Beehave** — альтернатива якщо AI буде простим або потрібна швидка інтеграція

**Загальна рекомендація:**
- Початківці → Beehave (простіше)
- Досвідчені розробники → LimboAI (більше можливостей)
- Великі проєкти → LimboAI (продуктивність)
- Малі проєкти → Beehave (простота)

---

## Джерела

- [Beehave GitHub](https://github.com/bitbrain/beehave)
- [LimboAI GitHub](https://github.com/limbonaut/limboai)
- [LimboAI Documentation](https://limboai.readthedocs.io/)
- [LimboAI Discord](https://discord.gg/N5MGC95GpP)


