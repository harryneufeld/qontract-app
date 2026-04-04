#include "flutter_window.h"

#include <optional>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::Initialize() {
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);

  std::string title = "Qontract App";
  if (!Win32Window::Create(title, origin, size)) {
    return false;
  }

  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      GetHandle(), GetClientAreaSize().GetWidth(),
      GetClientAreaSize().GetHeight());

  // Tell flutter_controller_ that we own the window and that it should call us
  // when we need to resize or redraw.
  flutter_controller_->SetFramelessWindowHandle(this);

  // Initialize the Flutter engine
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }

  RegisterPlugins(flutter_controller_->engine());

  return true;
}

void FlutterWindow::OnDestroy() {
  flutter_controller_ = nullptr;
  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT message, WPARAM wparam,
                               LPARAM lparam) {
  // Give the Flutter controller and framework an opportunity to handle
  // messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleMessage(hwnd, message, wparam, lparam);
    if (result.has_value()) {
      return *result;
    }
  }

  switch (message) {
    case WM_SIZE:
      if (flutter_controller_) {
        RECT rect = GetClientArea();
        flutter_controller_->view()->SetFrame(rect);
      }
      return 0;

    case WM_DPICHANGED: {
      auto* newRect = reinterpret_cast<RECT*>(lparam);
      SetWindowPos(hwnd, nullptr, newRect->left, newRect->top, newRect->right - newRect->left,
                   newRect->bottom - newRect->top, SWP_NOZORDER | SWP_NOACTIVATE);
      return 0;
    }

    case WM_CLOSE:
      PostQuitMessage(0);
      return 0;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}