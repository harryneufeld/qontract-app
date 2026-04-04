# Issue #1: Frontend: Flutter Contract Management App

## Overview
Build a Flutter-based mobile/web application for contract management with authentication and document handling.

## Goals
- Create an intuitive UI for managing contracts
- Implement secure user authentication
- Enable document upload/view/download
- Provide dashboard for contract overview
- Cross-platform support (iOS, Android, Web)

## Requirements

### Features

#### Authentication
- Login screen with email/password
- JWT token storage and refresh
- Session management
- Logout functionality
- Password reset flow (optional phase 2)

#### Dashboard
- Contract overview list
- Search and filter capabilities
- Contract status indicators (color-coded)
- Upcoming expiry alerts
- Quick stats (total contracts, value, etc.)

#### Contract Management
- View contract details
- Create new contract form
- Edit existing contracts
- Delete contracts (with confirmation)
- Bulk actions (optional)

#### Document Management
- View documents attached to contract
- Upload documents (multiple file support)
- Download/view documents
- Delete documents (with confirmation)
- Document preview (PDF, images)

## UI/UX Requirements
- Clean, modern design
- Responsive layout (mobile-first)
- Loading states and error handling
- Toast notifications for actions
- Empty states for no data
- Pull-to-refresh on lists
- Offline support (optional phase 2)

## Technical Stack
- **Framework**: Flutter 3.x
- **State Management**: Provider/Bloc/Riverpod (choose one)
- **HTTP Client**: dio package
- **Authentication**: jwt_decode, shared_preferences
- **File Handling**: file_picker, path_provider
- **PDF Preview**: pdf_viewer package
- **UI Components**: material_design or custom
- **Theme**: Light/Dark mode support

## Project Structure
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
├── services/
│   ├── auth_service.dart
│   ├── api_service.dart
│   └── storage_service.dart
├── providers/
└── utils/
```

## API Integration
- Base URL: (backend endpoint from qontract-backend)
- Auth headers with JWT
- Error handling for 401/403/500
- Retry logic for failed requests

## Tasks
- [ ] Set up Flutter project with dependencies
- [ ] Implement authentication flow
- [ ] Build dashboard screen
- [ ] Create contract CRUD screens
- [ ] Implement document management
- [ ] Add search/filter functionality
- [ ] Implement error handling
- [ ] Add loading states
- [ ] Write unit/widget tests
- [ ] Polish UI/UX
- [ ] Prepare for deployment

## Notes
- Consider using existing UI kits like Flutter Admin Template
- Plan for scalability - may need to handle many contracts
- Security: Validate file types, limit upload sizes
- Add analytics tracking (optional)
