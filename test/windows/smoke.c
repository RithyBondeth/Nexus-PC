// SPDX-License-Identifier: MIT
// Small original Windows target-click game for the Phase 0 runtime proof.
#include <windows.h>
#include <stdio.h>

static int score = 0;
static HWND game;
static void record(const char *message) {
    FILE *file = fopen("C:\\nexus-evidence.txt", "a");
    if (file) { fprintf(file, "%s\n", message); fclose(file); }
}
static LRESULT CALLBACK procedure(HWND window, UINT message, WPARAM w, LPARAM l) {
    switch (message) {
    case WM_CREATE:
        record("WINDOW_CREATED");
        SetTimer(window, 1, 60000, NULL);
        return 0;
    case WM_LBUTTONDOWN:
        score++;
        record("POINTER_INPUT_RECEIVED");
        InvalidateRect(window, NULL, TRUE);
        return 0;
    case WM_KEYDOWN:
        if (w == VK_ESCAPE) { record("ESCAPE_RECEIVED"); DestroyWindow(window); }
        return 0;
    case WM_TIMER:
        record("TIMEOUT_NO_INPUT");
        DestroyWindow(window);
        return 0;
    case WM_PAINT: {
        PAINTSTRUCT paint;
        HDC dc = BeginPaint(window, &paint);
        RECT rect;
        GetClientRect(window, &rect);
        HBRUSH brush = CreateSolidBrush(RGB(24, 66, 132));
        FillRect(dc, &rect, brush);
        DeleteObject(brush);
        SetBkMode(dc, TRANSPARENT);
        SetTextColor(dc, RGB(255, 255, 255));
        char label[128];
        snprintf(label, sizeof(label), "Nexus-PC Windows game | Targets hit: %d", score);
        TextOutA(dc, 30, 30, label, (int)strlen(label));
        TextOutA(dc, 30, 65, "Click the play area. ESC exits cleanly.", 38);
        EndPaint(window, &paint);
        record("FRAME_PAINTED");
        return 0;
    }
    case WM_DESTROY:
        record("CLEAN_SHUTDOWN");
        PostQuitMessage(0);
        return 0;
    default: return DefWindowProcA(window, message, w, l);
    }
}
int WINAPI WinMain(HINSTANCE instance, HINSTANCE previous, LPSTR command, int show) {
    (void)previous; (void)command; (void)show;
    WNDCLASSA klass = {0};
    klass.lpfnWndProc = procedure;
    klass.hInstance = instance;
    klass.lpszClassName = "NexusSmoke";
    klass.hCursor = LoadCursor(NULL, IDC_ARROW);
    if (!RegisterClassA(&klass)) return 1;
    game = CreateWindowA("NexusSmoke", "Nexus-PC smoke game", WS_OVERLAPPEDWINDOW,
                         50, 50, 700, 450, NULL, NULL, instance, NULL);
    if (!game) return 2;
    ShowWindow(game, SW_SHOW);
    MSG event;
    int status;
    while ((status = GetMessageA(&event, NULL, 0, 0)) > 0) {
        TranslateMessage(&event); DispatchMessageA(&event);
    }
    record(status < 0 ? "PROCESS_EXIT_3" : "PROCESS_EXIT_0");
    return status < 0 ? 3 : 0;
}
