unit Ot.Localization;

interface

uses System.SysUtils;

procedure LoadLanguage(const Code: string; const CatalogFolder: string = '');
function L(const Key, Fallback: string): string;
function LF(const Key, Fallback: string; const Args: array of const): string;
function CurrentLanguage: string;
function LanguageWarning: string;

implementation

uses System.Classes, System.IOUtils, System.JSON, System.Generics.Collections;

var Catalog: TDictionary<string, string>;
  SelectedCode, Warning: string;

procedure ReadCatalog(const FileName: string);
var Value: TJSONValue; Pair: TJSONPair; Pending: TDictionary<string, string>; Item: TPair<string, string>;
begin
  if not FileExists(FileName) then raise Exception.Create('Missing language file: ' + FileName);
  if TFile.GetSize(FileName) > 4 * 1024 * 1024 then raise Exception.Create('Language file is too large');
  Value := TJSONObject.ParseJSONValue(TFile.ReadAllText(FileName, TEncoding.UTF8));
  Pending := TDictionary<string, string>.Create;
  try
    if not (Value is TJSONObject) then raise Exception.Create('Invalid language JSON: ' + FileName);
    for Pair in TJSONObject(Value) do
    begin
      if not (Pair.JsonValue is TJSONString) then raise Exception.Create('Language values must be strings');
      Pending.AddOrSetValue(Pair.JsonString.Value, Pair.JsonValue.Value);
    end;
    for Item in Pending do Catalog.AddOrSetValue(Item.Key, Item.Value);
  finally Pending.Free; Value.Free; end;
end;

procedure LoadLanguage(const Code: string; const CatalogFolder: string);
var Folder: string;
begin
  if Catalog = nil then Catalog := TDictionary<string, string>.Create else Catalog.Clear;
  Warning := ''; SelectedCode := 'uk-UA';
  Folder := CatalogFolder;
  if Folder = '' then Folder := TPath.Combine(ExtractFilePath(ParamStr(0)), 'Languages');
  try ReadCatalog(TPath.Combine(Folder, 'uk-UA.json'));
  except on E: Exception do Warning := E.Message; end;
  if (Code = '') or SameText(Code, 'uk-UA') then Exit;
  if not SameText(Code, 'en-US') then begin Warning := 'Unsupported language: ' + Code; Exit; end;
  try
    ReadCatalog(TPath.Combine(Folder, 'en-US.json'));
    SelectedCode := 'en-US';
  except on E: Exception do Warning := E.Message; end;
end;

function L(const Key, Fallback: string): string;
begin
  if (Catalog = nil) or not Catalog.TryGetValue(Key, Result) then Result := Fallback;
end;

function LF(const Key, Fallback: string; const Args: array of const): string;
begin
  try Result := Format(L(Key, Fallback), Args);
  except on E: EConvertError do Result := Format(Fallback, Args); end;
end;

function CurrentLanguage: string;
begin
  Result := SelectedCode;
end;

function LanguageWarning: string;
begin
  Result := Warning;
end;

initialization
finalization
  Catalog.Free;
end.
