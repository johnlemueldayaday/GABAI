# Grocery Wallet

Grocery Wallet is a professional Flutter-based mobile application designed for efficient grocery management, budget tracking, and intelligent meal planning. It integrates advanced AI capabilities to provide users with personalized cooking suggestions and financial insights based on their shopping habits.

## Core Features

- **Shopping Management**: Real-time tracking of grocery items with categorized organization and status updates.
- **Budget Tracking**: Dynamic monitoring of expenditures against set budgets, featuring visual progress indicators and over-budget alerts.
- **Intelligent Analytics**: Comprehensive data visualization of spending trends, category distributions, and historical budget performance.
- **AI Assistant**: A specialized chatbot that defaults to a local offline OpenAI-compatible model, offering meal suggestions from bought ingredients, budget advice, and Filipino recipe guidance.
- **Grocery History**: Detailed archival of past shopping trips with the ability to instantly replicate previous lists.

## Technology Stack

- **Framework**: Flutter (Dart)
- **State Management**: In-memory AppState with static list management.
- **Data Visualization**: fl_chart for analytical representation.
- **AI Integration**: Local OpenAI-compatible chat API via Ollama/llama.cpp, with optional Gemini fallback.
- **Local Storage**: SharedPreferences for persistent chat history.
- **Design System**: Custom design system utilizing Google Fonts (Plus Jakarta Sans) and HSL-based color tokens.

## Getting Started

### Prerequisites

- Flutter SDK (v3.11.0 or higher)
- Android Studio / Xcode for mobile simulation
- Ollama or llama.cpp server for offline Ramsey chat
- Optional Google Gemini API key for Gemini mode or AI image scanning

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
   Copy `.env.example` to `.env`. Ramsey defaults to `AI_PROVIDER=local`, `LOCAL_AI_BASE_URL=http://localhost:11434/v1`, and `LOCAL_AI_MODEL=llama3.2:3b`.

4. Install and prepare a local model with Ollama:
   ```bash
   ollama pull llama3.2:3b
   ```

5. Run the application:
   ```bash
   ./scripts/flutter_with_env.sh run
   ```

   On PowerShell:
   ```powershell
   .\scripts\flutter_with_env.ps1 run
   ```

For builds, use the same wrapper so the API key stays out of the source tree:

```bash
./scripts/flutter_with_env.sh build apk
```

On PowerShell:

```powershell
.\scripts\flutter_with_env.ps1 build apk
```

For Android emulator builds that call Ollama on your computer, set:

```bash
LOCAL_AI_BASE_URL=http://10.0.2.2:11434/v1
```

## Project Structure

- `lib/pages/`: Contains all primary UI screens (Home, Recent, Analytics, AI Chat).
- `lib/services/`: Backend logic and storage services.
- `lib/main.dart`: Application entry point and configuration.
- `fonts/`: Custom typography assets.

## Documentation

Detailed technical documentation and architectural diagrams can be found in [documentation.md](./documentation.md).
