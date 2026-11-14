unit Ot.DarkPalette;

interface

uses Vcl.Themes;

procedure ApplyDarkPalette(Style: TCustomStyleServices);

implementation

uses Winapi.Windows, System.Math, Vcl.Graphics, Vcl.Styles,
  Vcl.StyleAPI, Vcl.StyleBitmap;

type
  TOtStyleAccess = class(TCustomStyle)
    procedure ApplyPalette;
  end;

function SoftColor(Color: TColor): TColor;
var R, G, B, Value: Integer;
begin
  Result := Color;
  if Color < 0 then Exit;
  R := GetRValue(Color); G := GetGValue(Color); B := GetBValue(Color);
  // Preserve colored accents; lift dark neutral surfaces and soften white text.
  if Max(R, Max(G, B)) - Min(R, Min(G, B)) > 16 then Exit;
  Value := (R + G + B) div 3;
  if Value <= 32 then Value := 30 + Value * 7 div 32
  else Value := 37 + (Value - 32) * 175 div 223;
  Result := RGB(Value, Value, Value);
end;

procedure TOtStyleAccess.ApplyPalette;
var Engine: TSeStyle; Source: TSeStyleSource; Bitmap: TSeBitmap;
  I, X, Y: Integer; Pixel: PRGBQuad; Color: TColor;
  StyleColor: TSeStyleColor; StyleFont: TSeStyleFont;
  procedure SystemColor(Index: TColor; Value: TColor);
  begin
    Engine.SysColors[Index] := Value;
    Source.SysColors[Index] := Value;
  end;
begin
  Engine := TSeStyle(FSource);
  Source := Engine.StyleSource;
  for StyleColor := Low(TSeStyleColor) to High(TSeStyleColor) do
  begin
    Engine.Colors[StyleColor] := SoftColor(Engine.Colors[StyleColor]);
    Source.Colors[StyleColor] := SoftColor(Source.Colors[StyleColor]);
  end;
  for StyleFont := Low(TSeStyleFont) to High(TSeStyleFont) do
  begin
    Engine.Fonts[StyleFont].Color := SoftColor(Engine.Fonts[StyleFont].Color);
    Source.Fonts[StyleFont].Color := SoftColor(Source.Fonts[StyleFont].Color);
  end;
  SystemColor(clWindow, RGB(30, 30, 30));
  SystemColor(clBtnFace, RGB(37, 37, 38));
  SystemColor(clMenu, RGB(37, 37, 38));
  SystemColor(clWindowText, RGB(212, 212, 212));
  SystemColor(clBtnText, RGB(204, 204, 204));
  SystemColor(clMenuText, RGB(204, 204, 204));
  SystemColor(clHighlight, RGB(9, 71, 113));
  SystemColor(clHighlightText, RGB(230, 230, 230));
  SystemColor(clGrayText, RGB(133, 133, 133));
  SystemColor(clBtnShadow, RGB(60, 60, 60));
  SystemColor(clBtnHighlight, RGB(69, 69, 69));
  SystemColor(clInfoBk, RGB(37, 37, 38));
  SystemColor(clInfoText, RGB(204, 204, 204));
  SystemColor(clHotLight, RGB(78, 148, 206));
  // VCL styles also use bitmap atlases for borders and button states. Recolor
  // them once, before registration and before DPI-specific bitmaps are cached.
  for I := 0 to Source.Bitmaps.Count - 1 do
  begin
    Bitmap := Source.Bitmaps[I];
    if Bitmap.PixelFormat <> pf32bit then Bitmap.PixelFormat := pf32bit;
    for Y := 0 to Bitmap.Height - 1 do
    begin
      Pixel := Bitmap.ScanLine[Y];
      for X := 0 to Bitmap.Width - 1 do
      begin
        // Leave transparent/antialiased pixels unchanged (premultiplied alpha).
        if not Bitmap.AlphaBlend or (Pixel.rgbReserved = 255) then
        begin
          Color := SoftColor(RGB(Pixel.rgbRed, Pixel.rgbGreen, Pixel.rgbBlue));
          Pixel.rgbRed := GetRValue(Color);
          Pixel.rgbGreen := GetGValue(Color);
          Pixel.rgbBlue := GetBValue(Color);
        end;
        Inc(Pixel);
      end;
    end;
  end;
end;

procedure ApplyDarkPalette(Style: TCustomStyleServices);
begin
  TOtStyleAccess(Style).ApplyPalette;
end;

end.
