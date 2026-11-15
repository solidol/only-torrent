unit Ot.StatusIcons;

interface

uses System.Types, Vcl.Graphics;

procedure DrawTorrentStatus(Canvas: TCanvas; const Bounds: TRect;
  State, IconSize: Integer; Uploading, Deleting, Selected: Boolean);

implementation

uses Winapi.Windows, System.Math, Ot.Appearance;

procedure DrawTorrentStatus(Canvas: TCanvas; const Bounds: TRect;
  State, IconSize: Integer; Uploading, Deleting, Selected: Boolean);
var X, Y, Size: Integer; SoftForeground: Boolean;
  function P(A, B: Integer): TPoint;
  begin Result := Point(X + MulDiv(A, Size, 20), Y + MulDiv(B, Size, 20)); end;
  procedure Line(A, B, C, D: Integer);
  begin Canvas.MoveTo(P(A,B).X, P(A,B).Y); Canvas.LineTo(P(C,D).X, P(C,D).Y); end;
  procedure Triangle(Up: Boolean; Left, Top, Width, Height: Integer; Color: TColor);
  begin
    Canvas.Pen.Style := psClear; Canvas.Brush.Color := Color;
    if Up then Canvas.Polygon([P(Left,Top+Height),P(Left+Width div 2,Top),P(Left+Width,Top+Height)])
    else Canvas.Polygon([P(Left,Top),P(Left+Width,Top),P(Left+Width div 2,Top+Height)]);
  end;
begin
  Canvas.Brush.Style := bsSolid;
  if Selected then Canvas.Brush.Color := ThemeColor(clHighlight)
  else Canvas.Brush.Color := ThemeColor(clWindow);
  Canvas.FillRect(Bounds);
  Size := Min(IconSize, Min(Bounds.Width-4, Bounds.Height-2));
  if Size < 8 then Exit;
  X := Bounds.Left + (Bounds.Width-Size) div 2;
  Y := Bounds.Top + (Bounds.Height-Size) div 2;
  Canvas.Pen.Style := psSolid; Canvas.Pen.Width := Max(1, Size div 10);
  SoftForeground := Selected or (GetRValue(ColorToRGB(ThemeColor(clWindow))) < 80);
  Canvas.Pen.Color := TColor(RGB(95,110,130));
  if SoftForeground then Canvas.Pen.Color := TColor(RGB(220,225,235));
  if Deleting then
  begin
    Canvas.Brush.Color := TColor(RGB(220,85,65));
    Canvas.Rectangle(P(5,6).X,P(5,6).Y,P(15,18).X,P(15,18).Y);
    Line(3,4,17,4); Line(7,2,13,2);
  end
  else case State of
    3: if Uploading then
      begin Triangle(True,0,3,9,14,TColor(RGB(30,177,74))); Triangle(False,11,3,9,14,TColor(RGB(255,126,43))); end
      else Triangle(False,1,3,18,14,TColor(RGB(255,126,43)));
    5: Triangle(True,1,2,18,16,TColor(RGB(30,177,74)));
    8: begin
      Canvas.Brush.Color := TColor(RGB(68,65,211));
      if SoftForeground then Canvas.Brush.Color := TColor(RGB(174,169,255));
      Canvas.FillRect(TRect.Create(P(3,3),P(8,17))); Canvas.FillRect(TRect.Create(P(12,3),P(17,17)));
    end;
    1,7: begin
      Canvas.Pen.Color := TColor(RGB(139,106,220));
      if SoftForeground then Canvas.Pen.Color := TColor(RGB(200,180,255));
      Canvas.Brush.Style := bsClear;
      Canvas.Ellipse(P(2,2).X,P(2,2).Y,P(14,14).X,P(14,14).Y);
      Line(12,12,18,18); Line(5,8,7,10); Line(7,10,11,5);
    end;
    2: begin
      Triangle(False,2,3,16,12,TColor(RGB(255,126,43)));
      Canvas.Pen.Style := psSolid; Canvas.Pen.Color := ThemeColor(clWindow);
      Line(7,7,13,7); Line(8,10,12,10);
    end;
    4: begin Canvas.Pen.Color := TColor(RGB(30,177,74)); Line(3,10,8,16); Line(8,16,18,3); end;
    6: begin
      Canvas.Brush.Color := TColor(RGB(61,157,180));
      Canvas.Rectangle(P(2,4).X,P(2,4).Y,P(18,16).X,P(18,16).Y);
      Canvas.Pen.Color := ThemeColor(clWindow); Line(5,12,15,12);
    end;
    9: begin
      Canvas.Pen.Color := TColor(RGB(229,83,75)); Line(4,4,16,16); Line(16,4,4,16);
    end;
  else
    Canvas.Brush.Style := bsClear;
    Canvas.Ellipse(P(2,2).X,P(2,2).Y,P(18,18).X,P(18,18).Y);
    Line(10,5,10,10); Line(10,10,14,12);
  end;
  Canvas.Brush.Style := bsSolid; Canvas.Pen.Style := psSolid; Canvas.Pen.Width := 1;
end;

end.
