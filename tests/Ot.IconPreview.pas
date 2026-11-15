unit Ot.IconPreview;

interface
uses System.Types, Vcl.Graphics, Vcl.ImgList;
procedure DrawAppIcon(Canvas: TCanvas; const Bounds: TRect; Index: Integer; Images: TCustomImageList);
procedure DrawTorrentStatus(Canvas: TCanvas; const Bounds: TRect;
  State, IconSize: Integer; Uploading, Deleting, Selected: Boolean; Images: TCustomImageList);
implementation
uses Winapi.CommCtrl, Ot.Appearance, Ot.StatusIcons;
procedure DrawAppIcon(Canvas: TCanvas; const Bounds: TRect; Index: Integer; Images: TCustomImageList);
var Params: TImageListDrawParams;
begin
  Params := Default(TImageListDrawParams); Params.cbSize := SizeOf(Params);
  Params.himl := Images.Handle; Params.i := Index; Params.hdcDst := Canvas.Handle;
  Params.x := Bounds.Left; Params.y := Bounds.Top;
  Params.cx := Bounds.Width; Params.cy := Bounds.Height;
  Params.fStyle := ILD_TRANSPARENT or ILD_SCALE;
  ImageList_DrawIndirect(@Params);
end;
procedure DrawTorrentStatus(Canvas: TCanvas; const Bounds: TRect;
  State, IconSize: Integer; Uploading, Deleting, Selected: Boolean; Images: TCustomImageList);
var X,Y: Integer;
begin
  if Selected then Canvas.Brush.Color := ThemeColor(clHighlight)
  else Canvas.Brush.Color := ThemeColor(clWindow);
  Canvas.FillRect(Bounds);
  X := Bounds.Left+(Bounds.Width-IconSize) div 2; Y := Bounds.Top+(Bounds.Height-IconSize) div 2;
  DrawAppIcon(Canvas,Rect(X,Y,X+IconSize,Y+IconSize),TorrentStateIcon(State,Uploading,Deleting),Images);
end;
end.
