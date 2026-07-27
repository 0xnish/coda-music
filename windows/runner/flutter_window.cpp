#include "flutter_window.h"

#include <optional>
#include <windowsx.h>
#include <dwmapi.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>

#include "flutter/generated_plugin_registrant.h"

namespace {

flutter::FlutterViewController* g_flutter_controller = nullptr;

void HandleMethodCall(const flutter::MethodCall<flutter::EncodableValue>& call,
                      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (call.method_name() == "minimize") {
    HWND hwnd = g_flutter_controller ? GetAncestor(g_flutter_controller->view()->GetNativeWindow(), GA_ROOT) : nullptr;
    if (hwnd) ShowWindow(hwnd, SW_MINIMIZE);
    result->Success();
  } else if (call.method_name() == "maximize") {
    HWND hwnd = g_flutter_controller ? GetAncestor(g_flutter_controller->view()->GetNativeWindow(), GA_ROOT) : nullptr;
    if (hwnd) {
      ShowWindow(hwnd, SW_MAXIMIZE);
    }
    result->Success();
  } else if (call.method_name() == "close") {
    HWND hwnd = g_flutter_controller ? GetAncestor(g_flutter_controller->view()->GetNativeWindow(), GA_ROOT) : nullptr;
    if (hwnd) PostMessage(hwnd, WM_CLOSE, 0, 0);
    result->Success();
  } else {
    result->NotImplemented();
  }
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // Store global reference for method channel
  g_flutter_controller = flutter_controller_.get();

  // Register method channel for window operations
  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "coda_music/window",
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler(HandleMethodCall);

  // Extend frame for window shadow
  MARGINS margins = {0, 0, 0, 0};
  DwmExtendFrameIntoClientArea(GetHandle(), &margins);

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    ShowWindow(this->GetHandle(), SW_SHOWMAXIMIZED);
  });

  // Remove native frame so Flutter handles all chrome.
  // WS_THICKFRAME causes white border flash on Alt+Tab — custom WM_NCHITTEST handles resize.
  LONG style = GetWindowLong(GetHandle(), GWL_STYLE);
  style &= ~(WS_CAPTION | WS_SYSMENU | WS_THICKFRAME | WS_BORDER);
  SetWindowLong(GetHandle(), GWL_STYLE, style);

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
    case WM_NCCALCSIZE: {
      if (wparam == TRUE && IsMaximized(hwnd)) {
        NCCALCSIZE_PARAMS* p = reinterpret_cast<NCCALCSIZE_PARAMS*>(lparam);
        RECT workArea{0};
        SystemParametersInfo(SPI_GETWORKAREA, 0, &workArea, 0);
        p->rgrc[0] = workArea;
      }
      return 0;
    }
    case WM_GETMINMAXINFO: {
      MINMAXINFO* mmi = reinterpret_cast<MINMAXINFO*>(lparam);
      RECT workArea{0};
      if (SystemParametersInfo(SPI_GETWORKAREA, 0, &workArea, 0)) {
        mmi->ptMaxPosition.x = workArea.left;
        mmi->ptMaxPosition.y = workArea.top;
        mmi->ptMaxSize.x = workArea.right - workArea.left;
        mmi->ptMaxSize.y = workArea.bottom - workArea.top;
      }
      return 0;
    }
    case WM_NCHITTEST: {
      POINT pt;
      pt.x = GET_X_LPARAM(lparam);
      pt.y = GET_Y_LPARAM(lparam);
      RECT rc;
      GetWindowRect(hwnd, &rc);
      const int edge = 8;
      LONG x = pt.x - rc.left;
      LONG y = pt.y - rc.top;
      LONG w = rc.right - rc.left;
      LONG h = rc.bottom - rc.top;
      if (!IsMaximized(hwnd) && !IsIconic(hwnd)) {
        if (x < edge && y < edge) return HTTOPLEFT;
        if (x >= w - edge && y < edge) return HTTOPRIGHT;
        if (x < edge && y >= h - edge) return HTBOTTOMLEFT;
        if (x >= w - edge && y >= h - edge) return HTBOTTOMRIGHT;
        if (x < edge) return HTLEFT;
        if (x >= w - edge) return HTRIGHT;
        if (y < edge) return HTTOP;
        if (y >= h - edge) return HTBOTTOM;
      }
      return HTCLIENT;
    }
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
