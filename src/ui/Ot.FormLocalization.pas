unit Ot.FormLocalization;

interface

uses System.Classes;

procedure TranslateForm(Root: TComponent);

implementation

uses System.TypInfo, System.SysUtils, Vcl.ComCtrls, Ot.Localization;

procedure TranslateForm(Root: TComponent);
var Component: TComponent; I: Integer;
  procedure Translate(Component: TComponent);
  var Prop: PPropInfo; Key, Value: string; J: Integer;
  begin
    for Key in TArray<string>.Create('Caption', 'Hint', 'Title', 'Filter') do
    begin
      Prop := GetPropInfo(Component.ClassInfo, Key);
      if Prop = nil then Continue;
      Value := GetStrProp(Component, Prop);
      SetStrProp(Component, Prop, L(Root.Name + '.' + Component.Name + '.' + Key, Value));
    end;
    if Component is TListView then
      for J := 0 to TListView(Component).Columns.Count - 1 do
      begin
        Value := TListView(Component).Columns[J].Caption;
        TListView(Component).Columns[J].Caption := L(Root.Name + '.' + Component.Name +
          '.Columns.' + IntToStr(J), Value);
      end;
  end;
begin
  Translate(Root);
  for I := 0 to Root.ComponentCount - 1 do
  begin
    Component := Root.Components[I];
    Translate(Component);
  end;
end;

end.
