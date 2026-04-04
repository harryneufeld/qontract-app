# Qontract App

Flutter-based contract management application for the Qontract project.

## Project Structure

```
lib/
├── main.dart                     # Entry point
├── app_routes.dart               # Route definitions
├── models/
│   ├── contract.dart            # Contract model
│   ├── document.dart            # Document model
│   └── user.dart                # User model
├── services/
│   ├── api_service.dart         # API client
│   ├── auth_service.dart        # Authentication service
│   ├── contract_service.dart    # Contract service
│   └── storage_service.dart     # Local storage
├── providers/
│   ├── auth_provider.dart       # Auth state management
│   └── contract_provider.dart   # Contract state management
├── screens/
│   ├── login/
│   │   └── login_screen.dart    # Login screen
│   ├── dashboard/
│   │   └── dashboard_screen.dart # Dashboard
│   ├── contract/
│   │   ├── contract_detail_screen.dart
│   │   └── contract_form_screen.dart
│   └── document/
│       └── document_list_screen.dart
└── widgets/
    ├── contract_list_item.dart
    └── stats_card.dart
```

## Features Implemented

### ✅ Core Features
- User authentication (login/logout)
- JWT token management
- Contract list and detail views
- Create/Edit contract forms
- Document management UI
- Dashboard with statistics
- Search and filter contracts
- Contract status indicators

### 📋 Planned Features
- Document upload/download
- PDF preview
- Offline support
- Password reset flow
- Unit and widget tests
- Push notifications
- Dark/Light mode toggle

## Setup Instructions

### Prerequisites
1. Install Flutter SDK 3.x
2. Install Android Studio or Xcode for mobile development
3. Setup backend API at `http://localhost:8080`

### Getting Started

1. **Install dependencies:**
   ```bash
   flutter pub get
   ```

2. **Run the app:**
   ```bash
   flutter run
   ```

3. **Connect to backend:**
   - Update API base URL in `lib/services/api_service.dart`

## API Integration

The app connects to the Qontract backend API at `http://localhost:8080/api`

### Endpoints Used
- `POST /auth/login` - User login
- `POST /auth/logout` - User logout
- `GET /auth/me` - Get current user
- `GET /contracts` - List all contracts
- `GET /contracts/:id` - Get contract details
- `POST /contracts` - Create contract
- `PUT /contracts/:id` - Update contract
- `DELETE /contracts/:id` - Delete contract

## State Management

The app uses **Provider** for state management:
- `AuthProvider` - Handles user authentication state
- `ContractProvider` - Manages contract data and operations

## Current Status

⚠️ **Note**: Flutter SDK download was interrupted. The project structure is complete but cannot be run until Flutter is installed.

You can download Flutter from: https://flutter.dev/docs/get-started/install/windows

Once Flutter is installed, run:
```bash
cd C:\Users\mail\source\repos\qontract-app
flutter pub get
flutter run
```

## Backend Connection

Make sure your Qontract backend is running at `http://localhost:8080` with the following endpoints implemented:
- Authentication endpoints
- Contract CRUD endpoints
- Document endpoints

## Development Notes

- Uses Material 3 design
- Responsive mobile-first layout
- Error handling and loading states
- Clean, modern UI with proper spacing and typography