# Grocery Wallet

Grocery Wallet is a professional Flutter-based mobile application designed for efficient grocery management, budget tracking, and intelligent meal planning. It integrates advanced AI capabilities to provide users with personalized cooking suggestions and financial insights based on their shopping habits.

## Core Features

- **Shopping Management**: Real-time tracking of grocery items with categorized organization and status updates.
- **Budget Tracking**: Dynamic monitoring of expenditures against set budgets, featuring visual progress indicators and over-budget alerts.
- **Intelligent Analytics**: Comprehensive data visualization of spending trends, category distributions, and historical budget performance.
- **AI Assistant**: A specialized chatbot powered by Google Gemini, offering meal suggestions from bought ingredients, budget advice, and Filipino recipe guidance.
- **Grocery History**: Detailed archival of past shopping trips with the ability to instantly replicate previous lists.

## Technology Stack

- **Framework**: Flutter (Dart)
- **State Management**: In-memory AppState with static list management.
- **Data Visualization**: fl_chart for analytical representation.
- **AI Integration**: Google Generative AI (Gemini 1.5 Flash).
- **Local Storage**: SharedPreferences for persistent chat history.
- **Design System**: Custom design system utilizing Google Fonts (Plus Jakarta Sans) and HSL-based color tokens.

## Getting Started

### Prerequisites

- Flutter SDK (v3.11.0 or higher)
- Android Studio / Xcode for mobile simulation
- Google Gemini API Key

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/johnlemueldayaday/Grocery-Wallet.git
   ```

2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Configure the AI Assistant:
   Update the API key in `lib/pages/ai_chat.dart` (ensure secure handling for production).

4. Run the application:
   ```bash
   flutter run
   ```

## Project Structure

- `lib/pages/`: Contains all primary UI screens (Home, Recent, Analytics, AI Chat).
- `lib/services/`: Backend logic and storage services.
- `lib/main.dart`: Application entry point and configuration.
- `fonts/`: Custom typography assets.

## Documentation

Detailed technical documentation and architectural diagrams can be found in [documentation.md](./documentation.md).
