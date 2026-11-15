unit Ot.StatusIcons;

interface

uses System.Types, Vcl.Graphics;

const OtIconCount = 18;

function TorrentStateIcon(State: Integer; Uploading, Deleting: Boolean): Integer;
function TorrentStatusIcon(State: Integer; Uploading, Deleting: Boolean): Integer;
procedure DrawAppIcon(Canvas: TCanvas; const Bounds: TRect; Index: Integer);
procedure DrawTorrentStatus(Canvas: TCanvas; const Bounds: TRect;
  State, IconSize: Integer; Uploading, Deleting, Selected: Boolean);

implementation

uses Winapi.Windows, System.Math, Ot.Appearance;

function TorrentStatusIcon(State: Integer; Uploading, Deleting: Boolean): Integer;
begin
  if Deleting then Exit(6);
  case State of
    1,7: Result := 9;
    2: Result := 10;
    3: if Uploading then Result := 15 else Result := 11;
    4: Result := 12;
    5: Result := 13;
    6: Result := 14;
    8: Result := 3;
    9: Result := 1;
  else Result := 8;
  end;
end;

function TorrentStateIcon(State: Integer; Uploading, Deleting: Boolean): Integer;
begin
  Result := TorrentStatusIcon(State,Uploading,Deleting);
  // Retain the original blue download glyph in the leading icon column.
  if Result = 11 then Result := 16 else if Result = 15 then Result := 17;
end;

procedure DrawAppIcon(Canvas: TCanvas; const Bounds: TRect; Index: Integer);
var Size, X, Y: Integer; Green, Blue, Red, Neutral: TColor;
  function P(A, B: Integer): TPoint;
  begin Result := Point(X + MulDiv(A,Size,20),Y + MulDiv(B,Size,20)); end;
  procedure Line(A,B,C,D: Integer);
  begin Canvas.MoveTo(P(A,B).X,P(A,B).Y); Canvas.LineTo(P(C,D).X,P(C,D).Y); end;
  procedure Box(A,B,C,D: Integer);
  begin Canvas.Rectangle(P(A,B).X,P(A,B).Y,P(C,D).X,P(C,D).Y); end;
  procedure Oval(A,B,C,D: Integer);
  begin Canvas.Ellipse(P(A,B).X,P(A,B).Y,P(C,D).X,P(C,D).Y); end;
  procedure Triangle(Up: Boolean; Left, Top, Width, Height: Integer; Color: TColor);
  begin
    Canvas.Pen.Color := Color; Canvas.Brush.Color := Color;
    if Up then Canvas.Polygon([P(Left,Top+Height),P(Left+Width div 2,Top),P(Left+Width,Top+Height)])
    else Canvas.Polygon([P(Left,Top),P(Left+Width,Top),P(Left+Width div 2,Top+Height)]);
  end;
begin
  Size := Min(Bounds.Width,Bounds.Height);
  X := Bounds.Left + (Bounds.Width-Size) div 2; Y := Bounds.Top + (Bounds.Height-Size) div 2;
  Green := ThemeColor(clGreen); Blue := ThemeColor(clHotLight);
  Red := ThemeColor(clMaroon); Neutral := ThemeColor(clGrayText);
  Canvas.Pen.Style := psSolid; Canvas.Pen.Width := Max(1,MulDiv(2,Size,20));
  Canvas.Brush.Style := bsSolid; Canvas.Pen.Color := Neutral;
  case Index of
    0: begin
      Canvas.Brush.Color := ThemeColor(clWindow); Box(3,2,14,18);
      Canvas.Brush.Color := Green;
      Canvas.FillRect(TRect.Create(P(10,10),P(19,13)));
      Canvas.FillRect(TRect.Create(P(13,7),P(16,17)));
    end;
    1: begin Canvas.Pen.Color := Red; Line(4,4,16,16); Line(16,4,4,16); end;
    2: begin Canvas.Pen.Color := Green; Canvas.Brush.Color := Green;
      Canvas.Polygon([P(5,3),P(16,10),P(5,17)]); end;
    3: begin
      Canvas.Brush.Color := Blue;
      Canvas.FillRect(TRect.Create(P(4,3),P(8,17)));
      Canvas.FillRect(TRect.Create(P(12,3),P(16,17)));
    end;
    4: begin
      Canvas.Brush.Color := ThemeColor(clBtnFace); Oval(2,2,18,18); Oval(7,7,13,13);
      Line(10,0,10,4); Line(10,16,10,20); Line(0,10,4,10); Line(16,10,20,10);
    end;
    5: begin Canvas.Brush.Color := ThemeColor(clInfoBk); Box(2,5,10,9); Box(2,8,18,17); end;
    6: begin Canvas.Pen.Color := Red; Canvas.Brush.Color := ThemeColor(clWindow);
      Box(4,5,16,18); Line(2,3,18,3); Line(7,1,13,1); Line(8,8,8,15); Line(12,8,12,15); end;
    7: begin Canvas.Pen.Color := ThemeColor(clWindowText); Canvas.Brush.Color := ThemeColor(clHighlight);
      Oval(2,2,18,18); Canvas.Brush.Color := ThemeColor(clBtnFace);
      Canvas.Pie(P(2,2).X,P(2,2).Y,P(18,18).X,P(18,18).Y,P(10,2).X,P(10,2).Y,P(10,18).X,P(10,18).Y); end;
    8: begin Canvas.Brush.Style := bsClear; Oval(2,2,18,18); Line(10,5,10,10); Line(10,10,14,12); end;
    9: begin Canvas.Pen.Color := Blue; Canvas.Brush.Style := bsClear;
      Oval(2,2,14,14); Line(12,12,18,18); Line(5,8,7,10); Line(7,10,11,5); end;
    10: begin Triangle(False,2,3,16,12,Blue); Canvas.Pen.Color := ThemeColor(clWindow);
      Line(7,7,13,7); Line(8,10,12,10); end;
    11: Triangle(False,1,3,18,14,Blue);
    12: begin Canvas.Pen.Color := Green; Line(3,10,8,16); Line(8,16,18,3); end;
    13: Triangle(True,1,2,18,16,Green);
    14: begin Canvas.Brush.Color := Blue; Box(2,4,18,16);
      Canvas.Pen.Color := ThemeColor(clWindow); Line(5,12,15,12); end;
    15: begin Triangle(True,0,3,8,14,Green); Triangle(False,12,3,8,14,Blue); end;
    16: Triangle(False,1,3,18,14,Red);
    17: begin Triangle(True,0,3,8,14,Green); Triangle(False,12,3,8,14,Red); end;
  end;
  Canvas.Brush.Style := bsSolid; Canvas.Pen.Width := 1;
end;

procedure DrawTorrentStatus(Canvas: TCanvas; const Bounds: TRect;
  State, IconSize: Integer; Uploading, Deleting, Selected: Boolean);
var Size, X, Y: Integer;
begin
  Canvas.Brush.Style := bsSolid;
  if Selected then Canvas.Brush.Color := ThemeColor(clHighlight)
  else Canvas.Brush.Color := ThemeColor(clWindow);
  Canvas.FillRect(Bounds);
  Size := Min(IconSize,Min(Bounds.Width-4,Bounds.Height-2));
  if Size < 8 then Exit;
  X := Bounds.Left+(Bounds.Width-Size) div 2; Y := Bounds.Top+(Bounds.Height-Size) div 2;
  DrawAppIcon(Canvas,Rect(X,Y,X+Size,Y+Size),TorrentStateIcon(State,Uploading,Deleting));
end;

end.
