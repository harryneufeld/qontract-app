# Development Plan for Qontract Frontend

## Current Status
✅ Git repo cloned to `C:\Users\mail\source\repos\qontract-app`
✅ Issue #1 created with full requirements
⚠️ Flutter CLI not installed on this machine

## Next Steps Required

### Phase 1: Environment Setup
1. **Install Flutter SDK** (v3.x)
   - Download from https://flutter.dev
   - Run `flutter doctor` to verify dependencies (Android Studio, Xcode, etc.)

2. **Initialize Flutter Project**
   ```bash
   flutter create --org harryneufeld --project-name qontract_app .
   cd qontract_app
   flutter pub get
   ```

3. **Add Dependencies** to `pubspec.yaml`
   ```yaml
   dependencies:
     flutter:
       sdk: flutter
     provider: ^6.0.0        # or bloc/riverpod
     dio: ^5.0.0             # HTTP client
     shared_preferences: ^2.0.0
     jwt_decoder: ^2.0.0     # JWT token handling
     file_picker: ^5.0.0     # File selection
     path_provider: ^2.0.0   # File paths
     pdf_viewer: ^1.0.0      # PDF preview (or custom solution)
     intl: ^0.18.0           # Date formatting
     flutter_local_notifications: ^^+16.0.0  # Push notifications
   ```

### Phase 2: Project Structure
Create the following directory structure:
```
lib/
├── main.dart
├── models/
│   ├── contract.dart
│   ├── document.dart
│   └── user.dart
├── screens/
│   ├── login/
│   ├── dashboard/
│   ├── contract/
│   └── document/
├── widgets/
│   ├── common/
│   └── custom/
├── services/
│   ├── auth_service.dart
│   ├── api_service.dart
│   └── storage_service.dart
├── providers/
│   ├── auth_provider.dart
│   ├── contract_provider.dart
│   └── document_provider.dart
└── utils/
    ├── constants.dart
    ├── validators.dart
    └── formatters.dart
```

### Phase 3: Implementation Order

1. **Authentication Flow** (Priority: HIGH)
   - Login screen with JWT storage
   - Session management
   - Logout functionality
   - Backend integration with qontract-backend

2. **Dashboard** (Priority: HIGH)
   - Contract list with search/filter
   - Status indicators
   - Expiry alerts
   - Quick statistics

3. **Contract Management** (Priority: MEDIUM)
   - View contract details
   - Create/Edit forms
   - Delete with confirmation

4. **Document Management** (Priority: MEDIUM)
   - Upload/download/view documents
   - PDF preview
   - Document deletion

5. **Polish & Tests** (Priority: MEDIUM)
   - Error handling
   - Loading states
   - Toast notifications
   - Unit/widget tests

### Technical Decisions Needed
- **State Management**: I recommend using Provider for simplicity, or Bloc for more complex state management
- **PDF Preview**: Consider `html_to_pdf` or custom WebView solution
- **Images**: Use cached_network_image for document previews

### Files to Create First
1. `pubspec.yaml` with all dependencies
2. `lib/models/contract.dart`
3. `lib/models/document.dart`
4. `lib/models/user.dart`
5. `lib/services/api_service.dart`
6. `lib/services/auth_service.dart`
7. `lib/screens/login/login_screen.dart`

---
**Next Action**: Install Flutter SDK or let me know if you want me to proceed with a different approach.