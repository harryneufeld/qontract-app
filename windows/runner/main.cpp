#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>

#include <winrt/Windows.UI.Core.h>
#include <flutter/windows/flutter_view_controller.h>

#include <optional>
#include <windows.h>
#include <shellapi.h>

#include "flutter_window.h"

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  // Attach to console when present (e.g., during 'flutter run')
  if (AttachConsole(ATTACH_PARENT_PROCESS)) {
    freopen_s(
        reinterpret_cast<FILE **>(std::calloc(1, sizeof(FILE*))),
        "CONOUT$", "w", stdout);
    freopen_s(
        reinterpret_cast<FILE **>(std::calloc(1, sizeof(FILE*))),
        "CONOUT$", "w", stderr);
    std::setvbuf(stderr, nullptr, _IONBF, 0);
  }

  // Initialize COM, so that it is available for use in the library and/or plug-in
  // code.
  CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  flutter::DartProject project(L"data");

  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(10, 10);
  Win32Window::Size size(1280, 720);

  if (!window.Create(L"qontract_app", origin, size)) {
    return EXIT_FAILURE;
  }

  window.SetQuitOnClose(true);

  MSG msg;
  while (GetMessage(&msg, nullptr, 0, 0)) {
    TranslateMessage(&msg);
    DispatchMessage(&msg);
  }

  CoUninitialize();
  return EXIT_SUCCESS;
}