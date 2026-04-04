#pragma once

#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>

#include <optional>
#include <windows.h>

class FlutterWindow : public Win32Window {
 public:
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

  bool Initialize();

 protected:
  void OnDestroy() override;
  LRESULT MessageHandler(HWND hwnd, UINT message, WPARAM wparam,
                         LPARAM lparam) override;

 private:
  const flutter::DartProject project_;
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;
};