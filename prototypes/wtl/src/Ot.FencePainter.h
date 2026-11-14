#pragma once
#include <windows.h>
#include <array>

namespace ot {
void PaintFence(HDC dc, RECT bounds, const std::array<bool, 256>& blocks,
    COLORREF background, COLORREF foreground, int scale);
}
