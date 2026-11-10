# GABAI Presentation Speaker Script

Target length: 15-20 minutes  
Suggested pacing: 13 slides, around 1-1.5 minutes each  
Tone: brief, clear, relatable, and adviser-safe

## Slide 1 - Title
Target time: 45 seconds

Good day everyone. We are the developers of **GABAI APP**, which stands for **Guided Asset Budgeting AI for You**.

Our capstone focuses on a very familiar problem: managing money for daily needs. For many Filipino users, budgeting is not just about saving money. It is about remembering bills, controlling grocery spending, tracking where the money went, and avoiding the feeling of, "Asa naman akong kwarta niadto?"

GABAI is our proposed mobile solution: an offline-first financial management app with expense tracking, grocery budgeting, bill monitoring, analytics, and a rule-based assistant named GAB.

Transition: To understand why we built this, let us start with the background of the study.

## Slide 2 - Background of the Study
Target time: 1.5 minutes

Budgeting is a common struggle, especially when expenses happen every day and income is limited or already assigned to bills and needs.

Many people still track expenses through memory, paper notes, screenshots, or random calculator computations. The problem is that these methods are easy to forget, easy to lose, and hard to review later.

For Filipino users, this becomes more difficult because daily expenses include groceries, transport, school needs, bills, online shopping, and sometimes family contributions. Even small untracked purchases can add up.

GABAI responds to this by giving users one mobile place to record transactions, monitor budgets, track grocery spending, and receive simple guidance from GAB.

Interactive cue: Ask the panel/audience: "How many of us have bought groceries and only realized at the cashier that we already went over budget?"

Transition: Because of these everyday problems, our study identified the specific problems that GABAI aims to address.

## Slide 3 - Statement of the Problem
Target time: 1.5 minutes

The main problem is this: users may record expenses, but they still need help understanding and managing their budget in real time.

GABAI addresses several related problems.

First, informal budgeting methods are unreliable. Paper lists and memory-based tracking do not give automatic totals or reminders.

Second, grocery budgeting is difficult because users may not know how much they are already spending while shopping.

Third, users often lack price awareness. They may buy the same item from different stores without remembering previous prices.

Fourth, bill tracking is often disconnected from daily spending. A user may spend today and forget that a bill is due tomorrow.

Lastly, users need a system that is acceptable in terms of functionality, usability, reliability, and satisfaction.

Transition: These problems shaped the objectives of our study.

## Slide 4 - Objectives of the Study
Target time: 1.5 minutes

The general objective of our study is to design, develop, and evaluate GABAI as an offline-first mobile financial management application for Filipino users.

Specifically, we aim to create a system that allows users to record income, expenses, bills, grocery items, and budget allocations.

We also aim to develop local storage so the app can still work even without continuous internet connection.

Another objective is to implement GAB, a rule-based assistant that can provide budget alerts, spending summaries, bill reminders, and grocery-related suggestions.

Finally, we aim to evaluate the system using selected software quality criteria such as functional suitability, usability, reliability, performance efficiency, and overall satisfaction.

Important clarification: GAB is not presented as a professional financial adviser. It provides budgeting support based on user-entered data.

Transition: To support these objectives, we reviewed related literature and concepts.

## Slide 5 - Review of Related Literature
Target time: 2 minutes

Our review of related literature supports five important ideas.

First, mobile budgeting tools can improve awareness because users can immediately see what they spent and what remains.

Second, grocery lists help users plan purchases and reduce impulse buying. This is important because grocery spending is one of the most common household expenses.

Third, offline-first design is important. A budgeting app should still work inside a store, while commuting, or in areas with unstable internet.

Fourth, human-centered AI should support decision-making, not replace the user. This is why GAB gives suggestions and reminders, but the user still decides.

Fifth, software quality evaluation is needed. Since this is a system-based capstone, we evaluate whether the system is useful, usable, reliable, and acceptable to users.

Transition: With this foundation, we can explain who benefits from GABAI.

## Slide 6 - Significance of the Study
Target time: 1.25 minutes

GABAI is significant to several groups.

For Filipino users and households, the app provides a simple way to manage expenses, grocery budgets, and bills without relying on paper notes.

For students and young professionals, it can help build the habit of tracking allowance, salary, and daily spending.

For IT students and developers, the project serves as a practical example of Flutter development, local storage, analytics, and rule-based assistant design.

For academic institutions and future researchers, this study can serve as a reference for future projects related to financial technology, offline-first applications, and AI-assisted systems.

Transition: The system is also supported by theoretical foundations.

## Slide 7 - Theoretical Framework
Target time: 1.5 minutes

Our study is supported by three theories and concepts.

First is the **Theory of Planned Behavior**. This explains that behavior is influenced by intention and perceived control. In budgeting, users may want to save money, but they need tools that help them feel in control.

Second is the **Technology Acceptance Model**. A system is more likely to be accepted if users find it useful and easy to use. GABAI focuses on simple recording, clear summaries, and practical reminders.

Third is **Human-Centered AI**. This means GAB should assist the user, not replace their judgment. GAB gives budget-related suggestions based on the user's own records.

Transition: Before GABAI, the usual process was more fragmented.

## Slide 8 - Old System Process Flow
Target time: 1.75 minutes

This slide shows the old or manual process.

A common scenario starts on payday or budgeting day. The user writes a grocery list on paper, writes bills on a calendar, goes to the store, guesses prices, buys items, receives a receipt, and later calculates expenses manually.

The pain points are clear.

There is no real-time budget visibility. While shopping, the user may not know how much budget is left.

There is no easy price comparison. Users may forget how much the same item cost before.

Expense logging is slow because receipts and notebook records must be computed manually.

Meal planning, grocery planning, and bill tracking are disconnected.

GABAI improves this by bringing these activities into one mobile application.

Interactive cue: "This is the part many users relate to: the budget looks okay before shopping, but after checkout, the total is suddenly higher than expected."

Transition: The next slide shows how users interact with GABAI.

## Slide 9 - Use Case Diagram
Target time: 1.25 minutes

The main actor in the system is the user.

The user can manage shopping lists, monitor the grocery budget, track item prices, manage bills, view the dashboard, review analytics, adjust settings, and ask GAB for budget or grocery-related support.

These use cases show that GABAI is not only an expense tracker. It combines budgeting, grocery planning, bill tracking, analytics, and assistant-based support.

Again, all financial records are manually entered by the user. GABAI does not connect to banks or e-wallets, and it does not process real money.

Transition: Now let us look at how data moves inside the app.

## Slide 10 - Data Flow Diagram
Target time: 1.5 minutes

The data flow of GABAI is designed to be self-contained on the user's device.

The user inputs grocery items, budgets, bills, expenses, or GAB queries.

These inputs are processed by the app's service layer. GroceryStorage handles grocery lists, BillStorage handles bill records, PriceStorage handles item price history, and analytics summarizes the recorded data.

GAB receives context from these records, such as active grocery lists, remaining budget, and upcoming bills. It then generates rule-based responses like reminders, spending summaries, or simple budget suggestions.

The key point is privacy and offline use. The core data does not need to leave the phone for the app to function.

Transition: The next slide shows the local data model behind those features.

## Slide 11 - Entity Relationship Diagram
Target time: 1.5 minutes

The local data model includes the main records needed by GABAI.

The GroceryList contains the list name, store name, date, and budget. Each GroceryList can have many GroceryItems, such as item name, quantity, unit, price, and category.

The Bill entity stores bill name, amount, due date, frequency, and payment status.

PriceHistory stores item prices by item name and store name so users can review previous prices.

ChatMessage stores the user's conversation with GAB.

This structure supports the main goal of the app: helping users record, organize, and understand their financial activities locally.

Transition: After designing the system, we created the high-fidelity prototype.

## Slide 12 - High-Fidelity Prototype
Target time: 2 minutes

This slide shows GABAI in action through its core screens.

The dashboard gives users a quick overview of their financial status, including budget summaries and upcoming items.

The grocery or cart screen allows users to create shopping lists, add items, set prices, and monitor the budget while shopping.

The bills screen helps users record due dates and payment status so they do not forget upcoming obligations.

The analytics screen turns recorded data into charts and summaries, helping users understand where their money goes.

The GAB chat screen allows users to ask simple questions about their budget, bills, grocery list, and spending status.

The design goal is to make financial tracking feel less intimidating. Instead of forcing users to maintain separate notebooks, calendars, and calculators, GABAI puts the main tools in one mobile app.

Transition: To conclude, let us return to the main purpose of the project.

## Slide 13 - Closing Slide
Target time: 1 minute

To conclude, GABAI APP was developed to help Filipino users manage everyday finances in a more organized and accessible way.

It addresses common problems such as manual expense tracking, forgotten bills, grocery overspending, and lack of spending awareness.

Its main contribution is the integration of expense tracking, budget monitoring, grocery planning, bill tracking, analytics, and GAB rule-based assistance in one offline-first mobile app.

GABAI does not promise to make financial decisions for the user. Instead, it gives users clearer information so they can make better budgeting decisions themselves.

Thank you, and we are ready for your questions.

## Suggested Group Distribution

Speaker 1: Slides 1-3  
Speaker 2: Slides 4-6  
Speaker 3: Slides 7-10  
Speaker 4: Slides 11-13

## Quick Defense Lines

If asked why GABAI is needed when other budgeting apps exist: GABAI combines budgeting, grocery planning, bill tracking, analytics, and a rule-based assistant in one offline-first app designed around Filipino daily spending behavior.

If asked whether GAB is true AI: GAB is implemented as a rule-based assistant. It analyzes user-entered data using predefined conditions and provides budgeting support, reminders, and summaries.

If asked about privacy: GABAI stores records locally and does not connect to banks, e-wallets, or payment gateways. The app does not process real money.

If asked about financial advice: GABAI does not provide professional financial, investment, or legal advice. It only provides budgeting support based on the user's own records.
