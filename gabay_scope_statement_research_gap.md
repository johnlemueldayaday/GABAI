SCOPE AND LIMITATIONS

## 1. Scope

GABAI is a Flutter based mobile application that integrates grocery planning and personal financial management in one local first system. It allows users to create and manage grocery lists, record item quantities, units, prices, categories, stores, and budgets, and review recent grocery activities. The system also supports price history records based on user entered prices and stores.

The financial component allows users to manage accounts such as cash, banks, credit cards, electronic wallets, investments, and savings. Users can record income, expenses, transfers, account balances, financial categories, and transaction descriptions. The system provides spending summaries, analytics, daily spending allocations, pay schedule settings, and a safe to spend calculation based on the available balance, daily budget, and future pay schedule.

GABAI also supports bill and future event management. Users can record bills, expected income, due dates, payment status, recurrence, and scheduled financial events. The system can provide local notifications and synchronize bill information with a device calendar when the required permissions are granted.

The system includes GAB, a rule based conversational assistant that supports selected grocery and finance tasks. GAB can respond to balance, spending, budget, bill, income, expense, transfer, scheduled event, and cooking related requests. It can execute selected local actions through the application services and can guide users through multi step conversations. Cooking assistance is supported by the local cooking assistant.

The system is designed for users who want to organize grocery activities, monitor personal finances, review upcoming financial obligations, and receive basic decision support through a single application. Data is primarily stored locally on the user's device using JSON and SharedPreferences.

## 2. Limitations

GABAI does not currently include user registration, authentication, cloud storage, multi device synchronization, automatic bank integration, payment processing, or a server side database. Financial and grocery information must be entered or maintained by the user.

The price history feature stores user entered prices and does not provide live prices, automatic store comparisons, or verified market data. The safe to spend value is a budgeting indicator and is not professional financial advice, financial forecasting, or a guarantee of savings.

GAB is not currently connected to a large language model or external artificial intelligence service. Its responses depend on predefined keywords, regular expressions, supported categories, known account names, and programmed conversation states. Unsupported, ambiguous, or differently phrased requests may result in clarification or fallback responses. GAB conversation messages are not permanently stored after the application process ends.

The reliability of notifications, calendar synchronization, speech input, and home widget features depends on device compatibility, operating system configuration, permissions, and native platform setup. Local storage may also be affected by device loss, application removal, malformed data, or interrupted save operations.

The current system is intended for personal or household use and does not provide collaborative multi user access. Its effectiveness, usability, assistant accuracy, financial behavior impact, and long term savings benefits have not yet been established through a formal user evaluation.

## 3. STATEMENT OF THE PROBLEM

Many individuals manage grocery planning, personal expenses, account balances, bills, and expected income through separate applications, notes, or manual records. This fragmented process can make it difficult to determine how grocery purchases affect available funds, identify upcoming obligations, monitor spending patterns, and maintain an updated view of personal finances.

Users may also have difficulty recalling previous grocery prices, tracking recurring bills, determining a reasonable amount that can be spent, and completing routine financial tasks efficiently. Existing tools may focus only on grocery lists, expense tracking, budgeting, reminders, or conversational assistance rather than combining these functions into one system.

GABAI was developed to address this problem by integrating grocery management, personal finance tracking, bill and future event monitoring, safe to spend computation, price history, analytics, reminders, and rule based conversational assistance in a single local first application.

The study will focus on the following problems:

1. Users need an organized way to manage grocery items, budgets, stores, prices, and completed shopping activities.

2. Users need a centralized method for recording accounts, income, expenses, transfers, balances, and spending categories.

3. Users need improved visibility of upcoming bills, expected income, recurring obligations, and payment schedules.

4. Users need a practical budgeting indicator that considers their current balance, daily allocation, spending activity, and pay schedule.

5. Users need a convenient method for accessing selected grocery and financial functions through guided conversational interaction.

6. The effectiveness, usability, reliability, and accuracy of the integrated system need to be evaluated using measurable criteria.

## 4. RESEARCH GAP

Existing grocery list applications commonly focus on item organization, quantities, shopping status, and store information. Personal finance applications commonly focus on accounts, income, expenses, budgets, and analytics. Bill reminder applications focus on due dates and notifications, while conversational assistants focus on answering questions or completing selected tasks. These functions are often provided through separate systems, requiring users to manage related information across multiple applications.

There is a potential gap in the integration of grocery planning and personal financial management in one local first application. In particular, limited systems combine grocery budgets, store specific price history, account balances, transaction monitoring, future bills, expected income, pay schedule based safe to spend computation, reminders, analytics, and conversational task support within a single workflow.

There is also a need for further study of rule based conversational assistance for personal finance and grocery management. A rule based assistant may offer predictable local processing and reduced dependence on external services, but its usefulness may be limited by supported phrases, predefined categories, and the accuracy of its intent and information extraction logic. Its task completion rate, response accuracy, usability, and suitability for the intended users require formal evaluation.

GABAI addresses this potential gap by providing an integrated local first system that connects grocery activities with personal financial information and provides rule based conversational decision support. However, the gap must be validated through a review of related literature and existing systems. The study should compare GABAI with existing solutions based on feature integration, local operation, privacy, budgeting support, reminder functions, price history, conversational interaction, usability, and evaluation results.
