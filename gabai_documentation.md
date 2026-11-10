# GABAI System Documentation and Capstone Reference

>Document purpose:** This file is a complete technical and academic reference for the GABAI system. It is intended to give another AI assistant, developer, researcher, or capstone adviser enough context to understand the project and help develop its proposal, Chapters 1 and 2, system design, and future implementation.
>
> **Important boundary:** This is **not** a finished capstone paper. The academic sections provide verified project information, research directions, suggested framing, and items that still require validation. They should be converted into the institution's required writing format, supported with current scholarly sources, and reviewed by the adviser before submission.
>
 **Evidence status used in this document**
>
> - **Implemented:** directly evidenced by the current source code.
> - **Inferred:** a reasonable interpretation of implemented behavior, but not an explicit business requirement.
> - **Proposed:** a possible capstone framing, enhancement, or research direction; it must not be presented as an existing feature unless implemented.
> - **To validate:** information that requires confirmation from the proponents, target users, adviser, device testing, or academic sources.

---

## 1. Project identity

| Field | Current information |
|---|---|
| Application name | GABAI |
| Package name | `gabay` |
| Product concept | A personal grocery, wallet, budgeting, bill, and spending-assistance application |
| Primary platform | Flutter application with Android, iOS, macOS, Linux, and Windows project targets |
| Current storage model | Local device storage using `shared_preferences` and JSON serialization |
| Current AI model | No remote LLM is used by the implemented GAB assistant; GAB is a deterministic, rule-based conversational assistant |
| Currency default | Philippine Peso (`₱`) |
| Intended users | Individuals or households managing grocery purchases, accounts, expenses, income, bills, and spending limits |
| Current version in `pubspec.yaml` | `1.0.0+1` |
| Dart SDK constraint | `^3.11.0` |

### 1.1 Meaning of the name

“GABAI” is the product name, shortened from “Gab AI.” It identifies the application that provides practical guidance for everyday grocery planning and personal financial decisions.

### 1.2 One-sentence system description

GABAI is a local-first Flutter application that helps users organize grocery lists and prices, manage financial accounts and transactions, monitor bills and future income, calculate safe-to-spend amounts, view spending analytics, and interact with the built-in GAB rule-based assistant.

### 1.3 Capstone framing

The current system can be framed as a **personal financial and grocery management information system with an integrated conversational decision-support assistant**. This framing is more accurate than calling the current GAB implementation a generative-AI system, because the code uses local rule matching, regular expressions, state machines, stored data, and a local cooking engine rather than an external language model.

The final capstone title should be selected after confirming:

1. the target population;
2. whether the main emphasis is grocery management, personal finance, budgeting, or the integrated system;
3. whether GAB will remain rule-based or be upgraded to an external AI service;
4. the required platform and evaluation method; and
5. the academic institution's preferred title structure.

Possible working title directions, **not final titles**, are:

- **GABAI: A Personal Grocery and Financial Management Application with Conversational Decision Support**
- **GABAI: A Local-First Mobile Application for Grocery Planning, Expense Monitoring, and Budget Guidance**
- **GABAI: An Integrated Grocery, Wallet, Bill, and Safe-to-Spend Management System**

---

## 2. Current system scope

### 2.1 Implemented functional scope

The codebase currently includes the following functional areas:

1. Grocery list and cart management.
2. Grocery item quantities, units, categories, prices, and completion status.
3. Grocery budgets and selected stores.
4. Recent grocery trips.
5. Store-specific price history.
6. Financial account management.
7. Income, expense, and transfer transactions.
8. Balance and net-worth computation.
9. Bills and expected income records.
10. Recurring bill frequencies.
11. Future scheduled financial events.
12. Safe-to-spend and daily allocation calculations.
13. Payday and pay-frequency configuration.
14. Spending analytics and charts.
15. Onboarding and settings.
16. Currency and theme preferences.
17. Local bill notifications.
18. Device calendar synchronization.
19. iOS home-widget data publishing.
20. Speech-to-text support in the grocery workflow.
21. A unified GAB assistant.
22. One unified GAB assistant surface.

### 2.2 Explicitly out of current scope

The repository does not currently demonstrate:

- a user account server or cloud backend;
- registration, login, or remote authentication;
- cloud synchronization or multi-device data synchronization;
- a server-side database;
- durable cloud backup;
- a remote large language model call from `GABAssistant`;
- a complete online grocery-price data source;
- a payment gateway;
- a bank API or automatic bank transaction import;
- a multi-user household collaboration service;
- a web administration portal.

These may be proposed future enhancements, but they must not be described as current features.

### 2.3 Scope boundary for an academic study

For a manageable capstone, the system may be treated as a standalone application that stores data on the user's device and provides decision support from user-entered information. Claims about improved financial behavior, savings, or budgeting outcomes require an actual evaluation and must not be assumed from the presence of the features alone.

---

## 3. Technical architecture

### 3.1 Architectural style

The application is a Flutter client application organized into:

- presentation pages and widgets;
- domain/data models;
- local storage services;
- calculation and assistant services;
- platform integration services; and
- configuration/navigation files.

The architecture is service-oriented within a single Flutter application rather than a client-server architecture.

### 3.2 High-level component flow

```text
User
  |
  v
Flutter pages and reusable widgets
  |
  +--> Grocery, wallet, bill, settings, and analytics interactions
  |
  +--> GABChatPage
          |
          v
      GABAssistant
          |
          +--> intent and phrase matching
          +--> conversation state machine
          +--> FinanceStorage
          +--> FutureEventStorage
          +--> BillStorage
          +--> GroceryStorage/AppState
          +--> SettingsService
          +--> GabCookingAssistant
  |
  v
Local services
  |
  +--> SharedPreferences JSON data
  +--> local notifications
  +--> device calendar
  +--> iOS home widget bridge
```

### 3.3 Application startup

The entry point is [`lib/main.dart`](./lib/main.dart).

Startup behavior implemented in `main()`:

1. Calls `WidgetsFlutterBinding.ensureInitialized()`.
2. Sets the system UI overlay style.
3. Loads grocery data through `GroceryStorage.loadAll()`.
4. Loads price history through `PriceStorage.load()`.
5. Loads settings through `SettingsService().load()`.
6. Initializes `NotificationService`.
7. Runs `GroceryApp`.
8. After the first frame, loads stored bills and attempts to:
   - reschedule local bill notifications; and
   - synchronize bills to the device calendar.
9. Displays a snackbar if reminder setup produces errors.

### 3.4 Root application and navigation

The root `GroceryApp` is defined in [`lib/pages/cart.dart`](./lib/pages/cart.dart). It builds the Material application, applies theme behavior, and provides the initial splash route.

Route constants are defined in [`lib/navigation/app_routes.dart`](./lib/navigation/app_routes.dart):

- `/splash`
- `/dashboard`
- `/cart`
- `/cart-detail`
- `/settings`
- `/GAB-chat`

The application uses a mixture of route constants and imperative `Navigator`/`MaterialPageRoute` navigation. The route constants are not currently a complete registered named-route table.

### 3.5 Startup and primary navigation flow

```text
Application launch
  -> SplashScreen
  -> OnboardingGate
      -> OnboardingModal for a first-time user
      -> DashboardPage after onboarding or when already completed
  -> AppDrawer and page-level navigation
```

The primary drawer is implemented in [`lib/widgets/app_drawer.dart`](./lib/widgets/app_drawer.dart). It provides access to Dashboard, Analytics, Wallet/Accounts, Cart, Recent Groceries, Bills Tracker, GAB, and Settings.

### 3.6 Repository structure

| Location | Responsibility |
|---|---|
| [`lib/main.dart`](./lib/main.dart) | Application initialization and startup restoration |
| [`lib/pages/`](./lib/pages/) | Full application pages and feature screens |
| [`lib/screens/`](./lib/screens/) | Screen-level composition such as `HomeScreen` |
| [`lib/widgets/`](./lib/widgets/) | Reusable UI widgets and home sections |
| [`lib/services/`](./lib/services/) | Persistence, calculations, assistants, reminders, and integrations |
| [`lib/models/`](./lib/models/) | Serializable domain models |
| [`lib/data/`](./lib/data/) | Local structured data such as grocery/recipe data |
| [`lib/config/`](./lib/config/) | Theme and application configuration |
| [`lib/navigation/`](./lib/navigation/) | Route-name constants |
| `assets/images/` | Logos, assistant images, wallet icons, and other image assets |
| `fonts/` | Registered custom font files |
| `android/`, `ios/`, `macos/`, `linux/`, `windows/` | Flutter platform projects |

---

## 4. User-facing pages and modules

### 4.1 Splash and onboarding

Relevant files:

- [`lib/pages/splash_screen.dart`](./lib/pages/splash_screen.dart)
- [`lib/pages/onboarding.dart`](./lib/pages/onboarding.dart)

Responsibilities:

- show the launch screen;
- determine whether onboarding has been completed;
- present onboarding content for a first-time user; and
- transition the user to the dashboard.

The onboarding completion state is stored by `SettingsService`.

### 4.2 Dashboard

Relevant file: [`lib/pages/dashboard.dart`](./lib/pages/dashboard.dart)

The dashboard loads bills, transactions, accounts, net worth, currency, pay schedule, and daily allocation. It provides a financial overview including:

- account/net-worth information;
- safe-to-spend information;
- daily and weekly spending information;
- bills and upcoming financial events;
- transaction access;
- charts/trend information;
- a way to add income or expense transactions; and
- navigation to financial features and GAB.

The dashboard also sends summarized safe-to-spend and weekly spending data to the home-widget service.

### 4.3 Grocery cart and list management

Relevant files:

- [`lib/pages/cart.dart`](./lib/pages/cart.dart)
- [`lib/screens/home_screen.dart`](./lib/screens/home_screen.dart)
- [`lib/widgets/home/`](./lib/widgets/home/)
- [`lib/models/grocery_models.dart`](./lib/models/grocery_models.dart)

Implemented concepts:

- active grocery lists;
- recent grocery lists;
- list name;
- budget;
- selected store;
- grocery item name;
- quantity;
- unit;
- price;
- item category;
- completion/purchased state;
- item suggestions and category tabs;
- add-item sheets;
- a numeric keypad sheet;
- store picker;
- speech-to-text input support; and
- cart detail and list editing.

`GroceryItem.price` and `qty` allow the application to calculate shopping totals. The active and recent list state is represented by the static `AppState` class.

### 4.4 Recent groceries

Relevant file: [`lib/pages/recent.dart`](./lib/pages/recent.dart)

The recent-grocery page provides access to completed or previous grocery lists, including item viewing, renaming, deletion, and category/price-related displays.

### 4.5 Price comparison and history

Relevant files:

- [`lib/pages/price_comparison.dart`](./lib/pages/price_comparison.dart)
- [`lib/models/price_history.dart`](./lib/models/price_history.dart)
- [`lib/services/price_storage.dart`](./lib/services/price_storage.dart)

The current implementation records user-entered price observations rather than fetching live prices from stores. A price record contains:

- store;
- price;
- unit; and
- date.

Item names are normalized to lowercase keys. The service can retrieve the latest price at a particular store, the latest price at any store, full item history, stores associated with an item, and all tracked item names.

### 4.6 Wallet and accounts

Relevant files:

- [`lib/pages/wallet.dart`](./lib/pages/wallet.dart)
- [`lib/models/finance_models.dart`](./lib/models/finance_models.dart)
- [`lib/services/finance_storage.dart`](./lib/services/finance_storage.dart)

Supported predefined account types:

- Cash
- Bank
- Credit Card
- E-Wallet
- Investment
- Savings

Predefined wallet choices include GCash, Maya, Cash, BDO, Landbank, and PSBank. Accounts have IDs, names, types, balances, icons, and color values.

The wallet module allows users to add, update, and delete financial accounts and view account balances.

### 4.7 Transactions

The financial transaction model supports:

- transaction ID;
- amount;
- linked account ID;
- denormalized account name;
- type (`INCOME` or `EXPENSE`);
- category;
- description;
- date; and
- optional previous balance.

Expense categories include Food, Transportation, Utilities, Shopping, Entertainment, Health, Education, Rent, Subscriptions, Groceries, and Other.

Income categories include Salary, Freelance, Business, Allowance, Gift, Refund, and Other.

Adding a transaction updates the linked account balance. For Cash, E-Wallet, and Bank accounts, an expense that would make the balance negative is rejected with an insufficient-funds exception.

Transfers are stored as two transactions:

1. an expense from the source account; and
2. an income to the destination account.

### 4.8 Bills

Relevant files:

- [`lib/pages/bills.dart`](./lib/pages/bills.dart)
- [`lib/models/bill_models.dart`](./lib/models/bill_models.dart)
- [`lib/services/bill_storage.dart`](./lib/services/bill_storage.dart)

A `Bill` contains:

- ID;
- type/name;
- amount;
- due date;
- paid state;
- income/expense state; and
- frequency.

Predefined expense examples include electricity, water, internet, loans, insurance, rent, subscriptions, tuition, medical expenses, groceries, transportation, dining, shopping, and utilities.

Predefined income examples include salary, remittance, business income, allowance, scholarship, freelance income, investment, bonus, commission, dividends, pension, gifts, refunds, rental income, and debt.

Supported recurrence values used by the calendar service include:

- Once
- Everyday
- Weekly
- Monthly
- Quarterly
- Bi-monthly
- Annually

### 4.9 Scheduled future events

Relevant files:

- [`lib/models/finance_models.dart`](./lib/models/finance_models.dart)
- [`lib/services/future_event_storage.dart`](./lib/services/future_event_storage.dart)

`FutureEvent` represents a future bill or incoming-money event. It includes amount, category, description, scheduled date, frequency, optional entity, completion state, type, status, reschedule count, optional wallet, and creation time.

Storage provides:

- loading;
- saving;
- adding;
- removing;
- updating;
- listing upcoming events; and
- listing due events.

### 4.10 Analytics

Relevant file: [`lib/pages/analytics.dart`](./lib/pages/analytics.dart)

The analytics page includes period-based views for today, week, month, and year. It presents spending summaries, trends, category breakdowns, bills, and transaction history. The `fl_chart` package is used for charts.

The exact academic effectiveness of the analytics must be evaluated rather than assumed. The current code demonstrates data presentation, not proof that users make better financial decisions.

### 4.11 Settings

Relevant file: [`lib/pages/settings.dart`](./lib/pages/settings.dart)

Settings include:

- currency selection;
- theme mode;
- budget alerts;
- smart suggestions;
- compact view;
- savings tips;
- user name;
- onboarding completion;
- daily spending allocation;
- salary/payday configuration;
- pay frequency;
- pay interval;
- anchor payday; and
- related preferences.

### 4.12 GAB chat

Relevant files:

- [`lib/pages/gab_chat.dart`](./lib/pages/gab_chat.dart)
- [`lib/services/gab_assistant.dart`](./lib/services/gab_assistant.dart)
- [`lib/widgets/gab_floating_bubble.dart`](./lib/widgets/gab_floating_bubble.dart)

GAB is the single built-in assistant and can be opened as a dedicated chat page or through the floating assistant bubble.

The user interface provides:

- assistant greeting;
- user and assistant message bubbles;
- quick replies;
- typing animation;
- delayed response presentation;
- chat clearing/reset;
- highlighted income/expense responses; and
- navigation to the cart detail page when the assistant returns that target.

Messages and conversation state are kept in process memory and are not persisted as a durable chat history.

### 4.13 Consolidated GAB assistant

Relevant files:

- [`lib/pages/gab_chat.dart`](./lib/pages/gab_chat.dart)
- [`lib/services/gab_cooking_assistant.dart`](./lib/services/gab_cooking_assistant.dart)
- [`lib/services/gab_assistant.dart`](./lib/services/gab_assistant.dart)

The current repository consolidates the former assistant behaviors under GAB:

- GAB handles finance, grocery, budgeting, bills, and conversational workflows.
- The local cooking engine provides recipes, grocery ingredients, meal planning, and cooking-related spending summaries.
- Former specialized assistant pages/services are no longer part of the product surface.

---

## 5. Data model and persistence

### 5.1 Storage approach

The current application uses `shared_preferences` for local persistence. Structured objects are converted to JSON strings and stored under service-specific keys. There is no repository evidence of SQLite, Firebase, REST persistence, or another remote database.

### 5.2 Persistence keys

| Service | Keys or storage area | Data |
|---|---|---|
| `GroceryStorage` | `grocery_active_lists`, `grocery_recent_lists`, `grocery_active_index` | Active/recent lists and selected index |
| `PriceStorage` | `store_price_history` | Store-specific price records |
| `FinanceStorage` | `finance_accounts`, `finance_transactions` | Accounts and transactions |
| `BillStorage` | `bills_data` | Bills |
| `FutureEventStorage` | `future_events` | Scheduled future events |
| `SettingsService` | Multiple `settings_*` keys | Preferences, budget, payday, onboarding, and display settings |
| `BillCalendarService` | `device_calendar_bill_events` | References to device calendar events |

### 5.3 Grocery entities

#### `GroceryItem`

| Field | Meaning |
|---|---|
| `id` | Item identifier |
| `name` | Item name |
| `qty` | Quantity |
| `unit` | Unit such as pcs |
| `price` | Unit/item price used by the application |
| `isDone` | Completion or purchased state |
| `category` | Item category |

#### `GroceryList`

| Field | Meaning |
|---|---|
| `name` | List/trip name |
| `budget` | Planned grocery budget |
| `store` | Selected store |
| `items` | Grocery items |
| `date` | List date |

#### `AppState`

Contains static in-memory lists for active lists, recent lists, and the active list index.

### 5.4 Financial entities

#### `Account`

Stores the account ID, display name, type, balance, icon, and color value.

#### `FinanceTransaction`

Stores the amount, account reference, account display name, transaction type, category, description, date, and previous balance.

#### `FutureEvent`

Stores future bill/income information and lifecycle state such as pending, paid, received, completed, or rescheduled.

### 5.5 Bill entity

`Bill` stores a recurring or one-time bill/income record. `isIncome` differentiates outgoing obligations from expected incoming money, while `isPaid` tracks completion.

### 5.6 Price entity

`PriceRecord` stores a single observation for an item and store. `PriceHistory` maps a lowercase item name to a list of records.

### 5.7 Data relationships

```text
GroceryList 1 ---- * GroceryItem

Account 1 ---- * FinanceTransaction

Bill 1 ---- 0..1 device-calendar reference
Bill 1 ---- * local notification schedules

FutureEvent ---- queried by GAB and dashboard

PriceHistory item key ---- * PriceRecord ---- store
```

The relationship between transactions and accounts is represented by `accountId`; `accountName` is also stored for display. This means the account name is denormalized and may become stale if an account is renamed unless the relevant update logic refreshes it.

---

## 6. Core business logic

### 6.1 Finance transaction behavior

`FinanceStorage.addTransaction()`:

1. loads all accounts;
2. finds the account identified by `txn.accountId`;
3. calculates the new balance;
4. rejects an invalid negative balance for non-negative account types;
5. saves the transaction with the prior balance;
6. updates the account balance; and
7. persists the accounts.

`FinanceStorage.transferMoney()` records paired outgoing/incoming transactions and updates both account balances.

### 6.2 Safe-to-spend behavior

The calculation is implemented in [`lib/services/safe_to_spend.dart`](./lib/services/safe_to_spend.dart).

Inputs include:

- current balance;
- daily budget;
- days until payday;
- spending today; and
- optional cycle data kept for API compatibility.

The key logic is:

```text
futureDays = max(0, daysLeft - 1)
reservedFuture = dailyBudget * futureDays
extra = currentBalance - reservedFuture
safeToSpend = max(0, extra)
```

When the balance falls below the future reserve, the service calculates an effective daily budget across the remaining future days. It also returns whether the shortfall is severe.

Important implementation note: the current balance is treated as already reflecting today's transactions, so `spentToday` is not subtracted a second time from the balance calculation. `spentToday` is still used for today's progress/available amount.

### 6.3 Pay schedule behavior

`PayFrequency` supports:

- monthly;
- twice monthly;
- weekly;
- every two weeks;
- every 15 days;
- every 30 days; and
- custom intervals.

`nextPayday()` determines the next payday using calendar dates or an anchor date and interval. Monthly and twice-monthly schedules clamp day numbers to the number of days in a month.

### 6.4 Grocery persistence behavior

`GroceryStorage.saveAll()` debounces writes by 500 milliseconds. This reduces repeated writes while a user is editing a list. The save operation is initiated asynchronously and the method itself does not expose a completion result.

### 6.5 Price-history behavior

Prices are normalized by lowercase item name. The service:

- rejects an empty store or non-positive price;
- appends a new record;
- persists the updated history;
- retrieves the most recent record for a specified store; and
- retrieves the most recent record for any store.

This is a user-entered historical record system, not a live market-price comparison engine.

### 6.6 Notification behavior

`NotificationService`:

- initializes timezone data;
- determines the local timezone;
- requests Android notification/exact-alarm permissions;
- requests iOS notification permissions;
- schedules reminders at 9:00 a.m.;
- schedules each day from seven days before a due date through the due date; and
- cancels reminders when a bill is paid or changed.

### 6.7 Calendar behavior

`BillCalendarService`:

- requests calendar permission;
- finds a writable calendar;
- creates or updates events;
- supports recurrence rules;
- stores local references to created events;
- deletes references when bills are removed; and
- removes or marks calendar instances when bills are paid.

Calendar access depends on platform permissions and the presence of a writable calendar.

### 6.8 Home-widget behavior

`WidgetService` publishes:

- safe-to-spend value;
- weekly spending; and
- weekly budget.

The implementation references iOS home-widget configuration and an app group. Native signing and widget configuration must match the values expected by the service.

---

## 7. GAB assistant: detailed reference

### 7.1 What GAB is

GAB is the unified local assistant implemented by [`GabAssistant`](./lib/services/gab_assistant.dart). It is not currently a cloud-based generative AI model. Its behavior is implemented through:

- string normalization;
- regular expressions;
- keyword lists;
- category sets;
- amount/date/frequency extraction;
- a multi-turn state machine;
- calls to local storage services; and
- delegation to `GabCookingAssistant`.

### 7.2 Public reply contract

`GABReply` contains:

| Field | Purpose |
|---|---|
| `text` | Main assistant response |
| `extraTexts` | Optional additional response messages |
| `quickReplies` | Suggested user actions |
| `navigateTo` | Optional navigation target |
| `highlightColor` | Optional presentation hint, such as red for expense or green for income |

### 7.3 Conversation states

`GABStep` includes states for:

- idle;
- craving, dish, and cart cooking prompts;
- expense account/amount/item collection;
- income account/amount/source collection;
- allocation period/amount collection;
- clarification;
- due-payment action/account/amount confirmation;
- due-event rescheduling;
- scheduled-event creation;
- scheduled-event selection;
- scheduled-event deletion;
- scheduled-event movement; and
- scheduled-event amount updates.

These states allow GAB to continue a multi-turn interaction after the initial message.

### 7.4 GAB lifecycle

```text
Open GAB
  -> getAsyncGreeting()
      -> check due events
      -> either due-event question or normal greeting

User message
  -> GABChatPage calls GABAssistant.handle()
  -> normalize and classify input
  -> check current conversation state
  -> extract amount/date/name/category/account
  -> perform a local operation or delegate to the cooking engine
  -> return GABReply
  -> UI shows typing delay and reply
```

### 7.5 Implemented GAB capabilities

The current implementation provides code evidence for:

#### Account and balance support

- total balance/net-worth questions;
- individual account lookup;
- account name matching;
- account labels and inline account icons.

#### Expense recording

- identify expense intent;
- extract amount;
- extract or infer description/category;
- select an account;
- request missing information through a multi-turn flow;
- write the transaction through `FinanceStorage`; and
- return expense-highlighted responses.

#### Income recording

- identify income intent;
- extract amount and source/category;
- request a destination account;
- write the income transaction; and
- return income-highlighted responses.

#### Transfers and undo

- transfer funds between accounts;
- rely on local balance rules for insufficient-funds protection; and
- track newly created transaction IDs for an undo command.

#### Budget and spending questions

- daily budget/allocation;
- safe-to-spend-related questions;
- spending summaries;
- spending breakdown follow-ups;
- budget questions;
- analytics-related questions; and
- grocery spending history.

#### Bills and scheduled money

- upcoming bills;
- weekly bill questions;
- upcoming expected income;
- future bill/income creation;
- list/show scheduled events;
- delete/cancel scheduled events;
- move/reschedule scheduled events;
- update scheduled amounts;
- due-event prompts;
- confirm payment/receipt; and
- process related account and amount steps.

#### Cooking and grocery assistance

- detect meal context;
- interpret craving or cooking requests;
- recommend dishes from the local cooking engine;
- show recipes and ingredients;
- ask whether ingredients should be added to the cart; and
- add selected recipe ingredients to the grocery workflow.

### 7.6 GAB intent strategy

The assistant checks input using groups of helper methods, including checks for:

- bill inquiries;
- weekly bills;
- spending questions;
- breakdown questions;
- budget questions;
- analytics questions;
- meal plans;
- cooking;
- income intent;
- expense intent;
- future tense;
- scheduled-event management;
- undo;
- cancellation; and
- clarification.

Categories and obligations are interpreted with explicit keyword sets. The implementation includes separate known income categories and outgoing obligation categories.

### 7.7 GAB output and UI behavior

The GAB page stores messages in static in-memory lists, prevents concurrent sends, displays a typing animation, adds a randomized response delay, and supports clearing the conversation.

The page may navigate to the cart detail page when `GABReply.navigateTo` is `cart_detail`.

### 7.8 GAB limitations and research implications

Current limitations:

1. GAB is deterministic and phrase-dependent.
2. It does not learn from user behavior.
3. It does not call a remote LLM.
4. It does not persist conversation history across application restarts.
5. The first due event returned by storage is the one used for the initial due greeting.
6. Ambiguous or unsupported wording may trigger clarification or fallback responses.
7. Account/category recognition depends on known names and phrase patterns.
8. The assistant's currency field is captured when the assistant instance is constructed.
9. Current behavior depends on local data being available and correctly serialized.
10. Conversational quality, intent accuracy, and task completion have not been established by a formal user study in the source code.

For a capstone, GAB may be described as a **rule-based conversational decision-support component**. If the capstone intends to claim artificial-intelligence or natural-language-processing performance, the proponents should define measurable metrics such as intent classification accuracy, slot-extraction accuracy, task completion rate, response appropriateness, and user satisfaction.

---

## 8. Dependencies and integrations

Declared dependencies in [`pubspec.yaml`](./pubspec.yaml):

| Dependency | Current purpose or evidence |
|---|---|
| `flutter` | Application framework |
| `cupertino_icons` | iOS-style icons |
| `flutter_svg` | SVG rendering support |
| `google_fonts` | Typography |
| `fl_chart` | Dashboard/analytics charts |
| `http` | Declared; no confirmed use in `lib/` inventory |
| `shared_preferences` | Local JSON/string preference persistence |
| `speech_to_text` | Speech input in grocery workflow |
| `intl` | Number/date formatting |
| `image_picker` | Declared; no confirmed use in `lib/` inventory |
| `permission_handler` | Declared; no confirmed use in `lib/` inventory |
| `table_calendar` | Calendar UI |
| `home_widget` | Home-widget data bridge |
| `flutter_local_notifications` | Local notifications |
| `timezone` | Notification timezone scheduling |
| `device_calendar` | Device calendar synchronization |
| `flutter_timezone` | Local timezone discovery |

### 8.1 Platform permissions and configuration

The notification and calendar features require platform permission handling. The home-widget feature requires matching native app-group/widget configuration. Exact behavior must be tested on supported physical devices, not only in a simulator.

### 8.2 Declared but unconfirmed functionality

`http`, `image_picker`, and `permission_handler` are declared in the manifest, but the current source inventory did not establish corresponding active usage under `lib/`. They may be reserved for future work or used by platform/generated code. Their role should be confirmed before describing them as system features.

---

## 9. Security, privacy, and reliability profile

### 9.1 Current privacy model

Because the main data is stored locally:

- grocery, financial, bill, and settings data is intended to remain on the device;
- there is no demonstrated server-side user account;
- there is no demonstrated cloud synchronization; and
- there is no demonstrated remote processing of GAB messages.

This does not automatically guarantee privacy. Device access, backups, logs, screenshots, platform permissions, and future integrations must still be considered.

### 9.2 Security considerations

Items to document and validate in the capstone:

- financial data is stored in local preferences rather than an encrypted database;
- sensitive data protection at rest has not been demonstrated;
- there is no login or user identity layer in the current implementation;
- local device compromise could expose stored JSON data;
- calendar and notification permissions expose bill-related information to the operating system;
- API keys are not part of the current GAB design because no remote AI API is used;
- input parsing must be tested against malformed values and unexpected data;
- data migration/versioning is not clearly formalized; and
- error handling in some loaders returns empty collections after malformed JSON, which may conceal data corruption.

### 9.3 Reliability considerations

Known technical limitations include:

- debounced grocery saves may be pending when the process is terminated;
- several storage loaders fall back to empty results after decode errors;
- calendar/notification behavior depends on permissions and platform setup;
- route constants and actual navigation registration are not fully unified;
- local data has no automatic cloud backup;
- transaction/account consistency is implemented by sequential local writes rather than a database transaction;
- GAB behavior depends on current local data and phrase patterns; and
- no automated test inventory was established from the source review.

These should be treated as engineering limitations, not hidden from a capstone panel.

---

## 10. Current strengths and differentiators

The system has several potentially strong capstone characteristics:

1. **Integrated workflow:** grocery planning and personal finance are connected rather than isolated.
2. **Local-first design:** the app can operate without a demonstrated backend dependency.
3. **Actionable budgeting:** safe-to-spend translates account and pay-schedule information into a practical daily decision value.
4. **Future-money awareness:** bills and expected income are represented as scheduled events.
5. **Conversational access:** users can initiate several financial and grocery operations through GAB.
6. **Practical reminders:** local notifications and calendar synchronization connect records to daily routines.
7. **Price history:** users can build store-specific records from actual shopping observations.
8. **Platform integration:** home widgets, speech input, notifications, and calendar access extend beyond a basic CRUD application.
9. **Filipino-oriented context:** the default currency and local wallet choices support a Philippine use case.
10. **Extensible architecture:** domain services and serializable models provide a base for future backend or AI integrations.

---

## 11. Recommended capstone problem framing

This section is guidance for developing a proposal, not a finished Chapter 1.

### 11.1 Candidate real-world problem

Many individuals manage grocery planning, expenses, account balances, bills, and expected income in separate notes, spreadsheets, or applications. This fragmentation can make it difficult to see how a planned grocery purchase affects a user's available spending capacity and upcoming obligations.

The current GABAI implementation responds to that problem by combining:

- grocery lists and budgets;
- account and transaction records;
- scheduled bills and income;
- safe-to-spend calculations;
- historical price records;
- analytics; and
- conversational access to selected actions.

This problem statement must be narrowed to the actual target users and supported by local evidence, interviews, surveys, or related literature.

### 11.2 General objective direction

To design, develop, and evaluate GABAI as an integrated application for grocery planning, personal financial monitoring, bill awareness, and rule-based conversational decision support.

This is a working objective direction only. The final objective should match the chosen scope and evaluation design.

### 11.3 Specific objective directions

Potential objectives:

1. To design a grocery-list module that records items, quantities, units, prices, stores, budgets, and completion states.
2. To implement local financial-account and transaction management.
3. To implement bill and scheduled-income tracking with recurrence, reminders, and calendar synchronization.
4. To calculate a safe-to-spend amount using balance, spending allocation, and pay schedule inputs.
5. To provide spending analytics and category summaries.
6. To implement a rule-based assistant that supports selected grocery and finance tasks.
7. To evaluate the system's functionality, usability, accuracy, or task completion using a defined instrument.

The final objective list should avoid promising live prices, predictive intelligence, financial advice, or measurable savings unless those capabilities and measurements are actually added.

### 11.4 Possible research questions

Questions that may fit a capstone evaluation:

1. What grocery and personal finance tasks should be integrated for the selected users?
2. How accurately does GAB classify supported user intents?
3. How accurately does GAB extract amounts, dates, categories, and account names?
4. What percentage of representative tasks can users complete using the integrated application?
5. How usable is the application according to a recognized usability instrument?
6. How does the integrated workflow compare with the users' current process?
7. What technical limitations affect local-first storage, reminders, and assistant reliability?

Select only questions that can be answered with the chosen research method.

### 11.5 Possible beneficiaries

Potential beneficiaries, subject to validation:

- individuals managing personal budgets;
- students managing allowances and grocery expenses;
- working users tracking salary, bills, and daily spending;
- households coordinating grocery and financial planning;
- researchers studying local-first personal finance tools;
- future developers extending the system.

Avoid claiming broad benefits to all households unless the target population and evidence justify the claim.

### 11.6 Scope and delimitations to consider

Suggested delimitations:

- the system records user-entered data;
- current storage is local to the device;
- current prices are historical user entries, not live store feeds;
- current GAB is rule-based rather than a general-purpose LLM;
- financial values are informational and not professional financial advice;
- no automatic bank synchronization is included;
- no cloud account or multi-device synchronization is included;
- reminder behavior depends on device permission and platform support;
- supported language and phrase patterns should be specified after testing; and
- evaluation participants should be defined by the proponents.

---

## 12. Chapter 1 information package

Use the following as a fact bank and outline for writing Chapter 1. Do not copy it as a final paper without adapting it to the school's required format.

### 12.1 Introduction information

The introduction can establish:

- everyday grocery and personal-finance tasks are related;
- separate tools may fragment information;
- users need visibility into spending, upcoming obligations, and available money;
- mobile applications can consolidate records and reminders; and
- GABAI combines these functions in a local-first Flutter application.

### 12.2 Background of the study information

Include verified system context:

- the application is built with Flutter/Dart;
- it supports grocery, wallet, bill, budget, analytics, reminders, and assistant modules;
- local structured data is stored through `SharedPreferences`;
- safe-to-spend is computed from balance, daily allocation, and pay schedule;
- bills may be scheduled for local notification and calendar display; and
- GAB uses deterministic intent and state handling.

Add external contextual evidence only after researching current scholarly and local sources.

### 12.3 Problem statement information

Possible problem dimensions:

- grocery information and financial information are separated;
- manually checking balances and future obligations is time-consuming;
- users may not have a single view of grocery budgets and financial capacity;
- recurring bills and expected income can be missed without reminders;
- historical grocery prices may be difficult to recall; and
- users may prefer guided, conversational access to common actions.

The final problem statement must be expressed as observed problems in the selected community, not as unsupported assumptions.

### 12.4 Objectives information

Use the objective directions in Section 11.2 and 11.3. Make every objective measurable or verifiable through a system feature or evaluation procedure.

### 12.5 Significance information

The significance discussion may address:

- users: centralized records and decision support;
- households: better visibility of grocery and bill planning;
- developers: a foundation for local-first mobile applications;
- researchers: a case for evaluating rule-based conversational interfaces; and
- institutions: a practical information-system capstone artifact.

Use cautious language such as “may help” until evidence is collected.

### 12.6 Scope and delimitations information

Use the implemented scope from Section 2 and the limitations from Section 9. Clearly distinguish current behavior from proposed improvements.

### 12.7 Definition-of-terms candidates

Terms that may need operational definitions:

- GABAI
- grocery list
- grocery item
- wallet/account
- financial transaction
- bill
- future event
- safe to spend
- daily spending allocation
- payday/pay frequency
- price history
- local-first application
- conversational assistant
- rule-based assistant
- intent
- slot/entity extraction
- quick reply
- calendar synchronization
- local notification

The final definitions should be written according to how each term is used in the study.

### 12.8 Conceptual framework direction

A possible Input-Process-Output model:

```text
INPUT
- Grocery items, quantities, prices, stores, and grocery budgets
- Account balances and transaction records
- Bills, expected income, due dates, and pay schedule
- User preferences and assistant messages

PROCESS
- Local data validation and JSON persistence
- Grocery total and price-history processing
- Account balance and transaction updates
- Safe-to-spend calculation
- Bill/event reminder and calendar synchronization
- Analytics aggregation
- GAB intent recognition, state management, and local action execution

OUTPUT
- Organized grocery lists and recent trips
- Account and transaction summaries
- Upcoming bill and income visibility
- Safe-to-spend and budget indicators
- Spending analytics
- Price-history information
- Assistant responses and completed supported actions
```

This framework is a planning aid. The final framework should reflect the research variables and evaluation design.

---

## 13. Chapter 2 information package

This section is a literature-review research map, not a completed literature review and not a list of invented citations.

### 13.1 Literature themes to research

Find current, credible scholarly, government, or industry sources for:

1. personal financial management systems;
2. budgeting and expense tracking;
3. grocery planning and shopping-list applications;
4. price monitoring and price-history systems;
5. bill and recurring-payment reminders;
6. mobile information systems;
7. local-first/offline-first application design;
8. conversational user interfaces;
9. rule-based natural-language processing;
10. intent classification and entity/slot extraction;
11. personal finance decision support;
12. usability evaluation of mobile applications;
13. privacy and security of locally stored financial data; and
14. human-computer interaction for financial or household applications.

### 13.2 Related system categories

Compare GABAI with relevant system categories:

| Category | What to investigate | GABAI relationship |
|---|---|---|
| Grocery list systems | List organization, quantities, stores, budgets, completion | GABAI has grocery lists and cart details |
| Expense trackers | Account, income, expense, categories, history | GABAI has accounts and transactions |
| Budgeting tools | Daily/period budgets and remaining spending | GABAI has daily allocation and safe-to-spend |
| Bill reminder tools | Recurrence, notifications, calendar | GABAI has both |
| Price comparison tools | Current prices, historical records, store comparison | GABAI currently has user-entered history, not live feeds |
| Conversational assistants | Intent recognition and task execution | GAB provides deterministic conversational task support |
| Local-first apps | Offline access, privacy, synchronization trade-offs | GABAI is currently local-first |
| Analytics dashboards | Trends and category breakdowns | GABAI has analytics pages/charts |

### 13.3 How to synthesize sources

The Chapter 2 synthesis should not merely summarize one source after another. It should compare:

- the problem addressed;
- the target users;
- the data model;
- the platform;
- online/offline behavior;
- automation level;
- assistant interaction method;
- privacy model;
- evaluation method; and
- limitations.

Then explain which gap GABAI addresses and which gaps remain.

### 13.4 Possible technology foundations

Potential foundations to investigate and cite:

- Flutter cross-platform development;
- local-first/offline-first information systems;
- human-computer interaction;
- usability and user experience;
- rule-based natural-language processing;
- conversational user-interface design;
- decision-support systems;
- personal financial management;
- software quality models; and
- mobile application evaluation.

The theoretical framework must be selected with the adviser. Do not add a theory only because it appears in another capstone.

### 13.5 Research gap direction

A defensible gap may involve the limited integration of grocery planning, personal finance, future obligations, safe-to-spend computation, and conversational access in one local-first application for a Philippine-oriented context. This is a hypothesis for literature review, not an established fact. It must be verified by a systematic search of related systems.

### 13.6 Comparison-matrix template

Populate this table with verified sources:

| Source/system | Target users | Grocery support | Finance support | Bills/reminders | Conversational interface | Offline/local storage | Evaluation method | Limitation |
|---|---|---:|---:|---:|---:|---:|---|---|
| Source 1 | To research |  |  |  |  |  |  |  |
| Source 2 | To research |  |  |  |  |  |  |  |
| Source 3 | To research |  |  |  |  |  |  |  |
| GABAI | Selected users | Yes | Yes | Yes | Rule-based GAB | Yes/current design | To conduct | Local-only and phrase-dependent |

### 13.7 Sources still required

Before submitting Chapter 2, add:

- peer-reviewed studies;
- authoritative technology documentation where appropriate;
- credible local or government statistics if used;
- related Philippine applications or studies where available;
- complete author/date/title/publication details;
- consistent in-text citations; and
- a reference list in the required citation style.

No references are intentionally fabricated in this document.

---

## 14. Evaluation and validation plan information

The capstone should define how the system will be evaluated. Possible dimensions:

### 14.1 Functional testing

Test:

- create/edit/delete grocery lists;
- add/edit/complete grocery items;
- calculate grocery totals;
- record and retrieve prices;
- create/update/delete accounts;
- record income and expenses;
- prevent invalid negative balances;
- transfer money;
- create/update/pay bills;
- create and manage future events;
- calculate safe-to-spend values;
- configure pay schedules;
- schedule notifications;
- synchronize calendar events;
- use assistant-supported workflows; and
- preserve data after application restart.

### 14.2 GAB testing

Construct representative test utterances for:

- balance queries;
- expense logging;
- income logging;
- transfer requests;
- undo;
- budget and safe-to-spend questions;
- bill inquiries;
- future-event creation;
- future-event management;
- cooking requests; and
- ambiguous or unsupported messages.

Possible metrics:

- intent classification accuracy;
- amount extraction accuracy;
- date extraction accuracy;
- account matching accuracy;
- category matching accuracy;
- successful task completion rate;
- clarification rate; and
- fallback/error rate.

### 14.3 Usability testing

Use a recognized instrument selected with the adviser, such as a mobile usability questionnaire or System Usability Scale, if appropriate. Define:

- participant profile;
- sample size;
- task scenarios;
- consent and privacy procedures;
- scoring;
- interpretation thresholds; and
- limitations.

### 14.4 Reliability testing

Test:

- malformed local JSON;
- missing permissions;
- no writable calendar;
- notification denial;
- empty account data;
- insufficient funds;
- app restart after edits;
- interrupted save operations;
- unsupported assistant phrasing; and
- platform differences.

### 14.5 Performance testing

Potential measures:

- startup load time;
- response time for local assistant actions;
- time to load large grocery/transaction histories;
- notification/calendar synchronization time; and
- memory behavior for long conversations.

Do not claim a performance threshold until it is measured.

---

## 15. Development and implementation roadmap

This is a suggested roadmap for turning the current application into a capstone-ready system.

### Phase 1: Requirements confirmation

- identify target users;
- conduct interviews or surveys;
- confirm the primary problem;
- decide whether grocery or finance is the central focus;
- define supported GAB intents;
- confirm platforms; and
- agree on evaluation criteria.

### Phase 2: System hardening

- add tests for models, storage, calculations, and assistant flows;
- formalize data validation;
- decide whether malformed data should be recovered, reported, or migrated;
- improve persistence reliability;
- document platform permissions;
- verify native widget configuration; and
- resolve whether legacy Gab/Gab pages remain in scope.

### Phase 3: Capstone evidence

- collect baseline user-process evidence;
- collect related literature;
- create the comparison matrix;
- define research questions;
- define evaluation instruments;
- prepare representative task scenarios; and
- establish ethics/privacy procedures if participants are involved.

### Phase 4: Evaluation

- perform functional testing;
- perform GAB accuracy/task testing;
- perform usability testing;
- test platform integrations;
- analyze findings; and
- document limitations.

### Phase 5: Future enhancements

Possible proposals, clearly labeled as future work:

- encrypted local storage;
- database-backed persistence;
- cloud backup with explicit consent;
- multi-device synchronization;
- authenticated user profiles;
- live store-price feeds;
- improved multilingual or Filipino-language parsing;
- a remote LLM with privacy controls;
- configurable assistant skills;
- household collaboration;
- receipt scanning;
- automated transaction import; and
- stronger data migration/versioning.

---

## 16. Known implementation observations for future agents

The following observations help another coding or writing agent avoid incorrect assumptions:

1. GAB is not currently an external generative AI integration.
2. The main data store is local `SharedPreferences`, not a server database.
3. Grocery price history is manually recorded and store-specific.
4. Safe-to-spend uses current balance after transactions and does not subtract today's spending twice.
5. Account balance updates and transaction records are persisted separately through local service operations.
6. Cash, E-Wallet, and Bank accounts are protected from negative balances by `FinanceStorage`; other account types have different handling implications and need validation.
7. Bill reminders use local notifications and device calendar synchronization, both of which depend on permissions.
8. GAB chat messages are not durable across restarts.
9. GAB can perform local actions, not merely answer questions.
10. GAB uses a state machine for multi-turn workflows.
11. GAB contains or delegates to the local recipe and cooking logic used for cooking behavior.
12. Former assistant identities are not part of the product surface.
13. The app contains both named route constants and imperative navigation.
14. Some declared packages have no confirmed active source usage.
15. Current source review identified no automatic bank integration or cloud sync.

---

## 17. Information that must be confirmed by the proponents

Before finalizing a capstone proposal, confirm:

- official system name and capitalization;
- target users and location;
- whether the application is intended for an individual or household;
- supported language(s);
- primary platform for the study;
- whether GAB is the only assistant identity in the final product;
- whether GAB will remain rule-based;
- whether a backend is planned;
- whether actual store-price comparison is required;
- whether notifications and calendar are mandatory objectives;
- expected number and profile of evaluation participants;
- research methodology required by the institution;
- software quality framework required by the adviser;
- citation style and minimum source count;
- privacy/ethics approval requirements; and
- which current limitations will be accepted versus fixed before evaluation.

---

## 18. Prompt context for another AI agent

The following compact instruction can be copied together with this document when asking another AI agent for help:

> You are assisting with a capstone project based on the GABAI Flutter application. Use `gabai_documentation.md` as the authoritative project context. Distinguish implemented features from inferred behavior and proposed enhancements. Do not claim that GAB is an LLM: the current assistant is deterministic, rule-based, stateful, and connected to local storage and a local cooking engine. The current system is local-first and uses SharedPreferences JSON persistence; it has no demonstrated cloud backend, authentication, bank API, or live price feed. Help prepare capstone information, research framing, requirements, diagrams, evaluation plans, and source-backed academic writing, but do not invent citations or present proposed features as implemented. When drafting Chapters 1 or 2, ask for the target population, research methodology, school format, and adviser requirements before producing final prose.

---

## 19. Source map

Key source files for further verification:

- [`lib/main.dart`](./lib/main.dart) — startup and restoration
- [`lib/pages/cart.dart`](./lib/pages/cart.dart) — root application and grocery workflow
- [`lib/pages/dashboard.dart`](./lib/pages/dashboard.dart) — financial dashboard
- [`lib/pages/gab_chat.dart`](./lib/pages/gab_chat.dart) — GAB user interface
- [`lib/services/gab_assistant.dart`](./lib/services/gab_assistant.dart) — unified assistant logic
- [`lib/services/gab_cooking_assistant.dart`](./lib/services/gab_cooking_assistant.dart) — local cooking assistant
- [`lib/services/finance_storage.dart`](./lib/services/finance_storage.dart) — accounts and transactions
- [`lib/services/grocery_storage.dart`](./lib/services/grocery_storage.dart) — grocery persistence
- [`lib/services/bill_storage.dart`](./lib/services/bill_storage.dart) — bill persistence
- [`lib/services/future_event_storage.dart`](./lib/services/future_event_storage.dart) — future-event persistence
- [`lib/services/price_storage.dart`](./lib/services/price_storage.dart) — price-history persistence
- [`lib/services/settings_service.dart`](./lib/services/settings_service.dart) — settings and pay schedule
- [`lib/services/safe_to_spend.dart`](./lib/services/safe_to_spend.dart) — budgeting calculations
- [`lib/services/notification_service.dart`](./lib/services/notification_service.dart) — local reminders
- [`lib/services/bill_calendar_service.dart`](./lib/services/bill_calendar_service.dart) — device calendar
- [`lib/services/widget_service.dart`](./lib/services/widget_service.dart) — home-widget bridge
- [`lib/models/grocery_models.dart`](./lib/models/grocery_models.dart) — grocery entities
- [`lib/models/finance_models.dart`](./lib/models/finance_models.dart) — accounts, transactions, and future events
- [`lib/models/bill_models.dart`](./lib/models/bill_models.dart) — bill entity
- [`lib/models/price_history.dart`](./lib/models/price_history.dart) — price-history entities
- [`lib/pages/analytics.dart`](./lib/pages/analytics.dart) — analytics views
- [`lib/pages/bills.dart`](./lib/pages/bills.dart) — bills interface
- [`lib/pages/wallet.dart`](./lib/pages/wallet.dart) — accounts interface
- [`lib/pages/settings.dart`](./lib/pages/settings.dart) — settings interface
- [`lib/widgets/app_drawer.dart`](./lib/widgets/app_drawer.dart) — primary navigation
- [`pubspec.yaml`](./pubspec.yaml) — dependencies, assets, fonts, and SDK constraint

---

## 20. Final status of this documentation

This file is a **capstone information and system-reference document**. It intentionally does not provide:

- a submission-ready Chapter 1;
- a submission-ready Chapter 2;
- invented research citations;
- unsupported claims about user impact;
- unsupported claims that GAB uses a large language model; or
- proposed future features disguised as current functionality.

The next academic step is to validate the target problem and users, gather related literature, select the research methodology, define measurable evaluation criteria, and then convert the verified information in this document into the institution's required capstone format.
