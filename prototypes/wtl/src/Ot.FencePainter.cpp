#include "Ot.FencePainter.h"
#include <algorithm>

namespace ot {
namespace {
COLORREF Mix(COLORREF a, COLORREF b, unsigned weight) {
    const auto blend = [weight](unsigned x, unsigned y) { return (x * weight + y * (255 - weight)) / 255; };
    return RGB(blend(GetRValue(a), GetRValue(b)), blend(GetGValue(a), GetGValue(b)), blend(GetBValue(a), GetBValue(b)));
}
}
void PaintFence(HDC dc, RECT bounds, const std::array<bool, 256>& blocks,
    COLORREF background, COLORREF foreground, int scale) {
    const int width = bounds.right - bounds.left;
    if (width <= 0 || bounds.bottom <= bounds.top) return;
    const int pitch = std::max(2, MulDiv(4, scale, 96));
    const int columns = std::min(static_cast<int>(blocks.size()), std::max(1, width / pitch));
    const auto old = SelectObject(dc, GetStockObject(DC_BRUSH));
    SetDCBrushColor(dc, background); PatBlt(dc, bounds.left, bounds.top, width, bounds.bottom - bounds.top, PATCOPY);
    for (int x = 0; x < columns; ++x) {
        const auto first = static_cast<std::size_t>(x) * blocks.size() / columns;
        const auto last = static_cast<std::size_t>(x + 1) * blocks.size() / columns;
        unsigned have = 0;
        for (auto i = first; i < last; ++i) have += blocks[i] ? 1 : 0;
        const unsigned density = static_cast<unsigned>(have * 255 / (last - first));
        const auto empty = Mix(GetSysColor(COLOR_GRAYTEXT), background, 45);
        SetDCBrushColor(dc, Mix(foreground, empty, density));
        const int left = bounds.left + x * width / columns;
        const int right = bounds.left + (x + 1) * width / columns - std::max(1, MulDiv(1, scale, 96));
        PatBlt(dc, left, bounds.top, std::max(1, right - left), bounds.bottom - bounds.top, PATCOPY);
    }
    SelectObject(dc, old);
}
}
