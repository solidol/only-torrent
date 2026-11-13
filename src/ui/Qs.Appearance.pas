unit Qs.Appearance;

interface

uses Vcl.Controls, Vcl.Graphics, System.Types, Qs.Types;

procedure ApplyAppearance(Control: TWinControl; SystemTheme: Boolean);
procedure DrawBlockFence(Canvas: TCanvas; const Bounds: TRect; const Map: TQsBlockMap;
  Selected: Boolean; const Caption: string);
function SizeText(Value: Int64): string;
function StateText(Value: Integer): string;

implementation

uses Winapi.Windows, Winapi.UxTheme, Winapi.CommCtrl, System.SysUtils,
  System.Math, Vcl.ComCtrls, Vcl.StdCtrls, Vcl.Themes, Qs.BlockMap;

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

procedure DrawBlockFence(Canvas: TCanvas; const Bounds: TRect; const Map: TQsBlockMap;
  Selected: Boolean; const Caption: string);
var R, Plot, Bar, Fill, TextBounds: TRect; I, Count: Integer;
  DisplayMap: TQsBlockMap; VerifiedColor, ReceivedColor: TColor;
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
    0: Result := 'У черзі';
    1: Result := 'Перевірка';
    2: Result := 'Метадані';
    3: Result := 'Завантаження';
    4: Result := 'Завершено';
    5: Result := 'Роздача';
    6: Result := 'Виділення місця';
    7: Result := 'Перевірка стану';
    8: Result := 'Призупинено';
    9: Result := 'Помилка';
  else Result := 'Очікування';
  end;
end;

end.
