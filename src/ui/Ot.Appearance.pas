unit Ot.Appearance;

interface

uses Vcl.Controls, Vcl.Graphics, System.Types, Ot.Types;

procedure ApplyAppearance(Control: TWinControl; SystemTheme: Boolean);
procedure DrawBlockFence(Canvas: TCanvas; const Bounds: TRect; const Map: TOtBlockMap;
  Selected: Boolean; const Caption: string);
function SizeText(Value: Int64): string;
function StateText(Value: Integer): string;

implementation

uses Ot.Localization, Winapi.Windows, Winapi.UxTheme, Winapi.CommCtrl, System.SysUtils,
  System.Math, Vcl.ComCtrls, Vcl.StdCtrls, Vcl.Themes, Ot.BlockMap;

procedure ApplyAppearance(Control: TWinControl; SystemTheme: Boolean);
var I: Integer;
begin
  if SystemTheme then
  begin
    SetWindowTheme(Control.Handle, nil, nil);
    if (Control is TCustomListView) or (Control is TCustomTreeView) then
      SetWindowTheme(Control.Handle, 'Explorer', nil);
  end
  else SetWindowTheme(Control.Handle, ' ', ' ');
  for I := 0 to Control.ControlCount - 1 do
    if Control.Controls[I] is TWinControl then
      ApplyAppearance(TWinControl(Control.Controls[I]), SystemTheme);
  Control.Invalidate;
end;

procedure DrawBlockFence(Canvas: TCanvas; const Bounds: TRect; const Map: TOtBlockMap;
  Selected: Boolean; const Caption: string);
var R, Plot, Bar, Fill, TextBounds: TRect; I, Count: Integer;
  DisplayMap: TOtBlockMap; VerifiedColor, ReceivedColor: TColor;
  Color: Longint; OldMode: Integer;
  procedure Layer(Value: Integer; LayerColor: TColor);
  begin
    if Value <= 0 then Exit;
    Fill := Bar;
    Fill.Top := Fill.Bottom - BlockLayerPixels(Bar.Height, Value);
    Canvas.Brush.Color := LayerColor;
    Canvas.FillRect(Fill);
  end;
begin
  R := Bounds;
  Canvas.Brush.Color := clWindow;
  Canvas.Font.Color := clWindowText;
  if Selected then
  begin
    Canvas.Brush.Color := clHighlight;
    Canvas.Font.Color := clHighlightText;
  end;
  Canvas.FillRect(R);
  Plot := R;
  InflateRect(Plot, -3, -3);
  TextBounds := Plot;
  if Caption <> '' then
  begin
    Plot.Right := Max(Plot.Left, Plot.Right - 52);
    TextBounds.Left := Plot.Right + 3;
  end;
  DisplayMap := ResizeBlockMap(Map, Max(0, Plot.Width div 3));
  Count := Length(DisplayMap.Verified);
  Color := ColorToRGB(clHighlight);
  VerifiedColor := clHighlight;
  if Selected then VerifiedColor := clHighlightText;
  ReceivedColor := RGB((GetRValue(Color) + 255) div 2,
    (GetGValue(Color) + 255) div 2, (GetBValue(Color) + 255) div 2);
  for I := 0 to Count - 1 do
  begin
    Bar := Plot;
    Bar.Left := Plot.Left + MulDiv(Plot.Width, I, Count);
    Bar.Right := Plot.Left + MulDiv(Plot.Width, I + 1, Count) - 1;
    Canvas.Brush.Color := clBtnFace;
    Canvas.FillRect(Bar);
    Layer(DisplayMap.Requested[I], clBtnShadow);
    Layer(DisplayMap.Received[I], ReceivedColor);
    Layer(DisplayMap.Verified[I], VerifiedColor);
  end;
  if Caption <> '' then
  begin
    OldMode := SetBkMode(Canvas.Handle, TRANSPARENT);
    try
      DrawText(Canvas.Handle, PChar(Caption), Length(Caption), TextBounds,
        DT_CENTER or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX);
    finally SetBkMode(Canvas.Handle, OldMode); end;
  end;
end;

function SizeText(Value: Int64): string;
begin
  if Value >= 1073741824 then Result := Format('%.2f GiB', [Value / 1073741824])
  else if Value >= 1048576 then Result := Format('%.1f MiB', [Value / 1048576])
  else Result := Format('%.1f KiB', [Value / 1024]);
end;

function StateText(Value: Integer): string;
begin
  case Value of
    0: Result := L('text.eb3c78969040', 'У черзі');
    1: Result := L('text.d5cb0c3a9162', 'Перевірка');
    2: Result := L('text.c0bae911cb2d', 'Метадані');
    3: Result := L('text.7558ec23b17c', 'Завантаження');
    4: Result := L('text.016bc923f7ff', 'Завершено');
    5: Result := L('text.f241292c115e', 'Роздача');
    6: Result := L('text.caf0e9be4d8f', 'Виділення місця');
    7: Result := L('text.367875e0697b', 'Перевірка стану');
    8: Result := L('text.f43d3611bc11', 'Призупинено');
    9: Result := L('text.57467fc4b91f', 'Помилка');
  else Result := L('text.2bc411600ba1', 'Очікування');
  end;
end;

end.
