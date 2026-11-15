unit Ot.BridgeApi;

interface

uses System.SysUtils, Ot.Types;

const OT_ABI_VERSION = 2;

type
  TOtMetaInfoRaw = record
    Total: Int64;
    Files, Trackers: Integer;
    Name: array[0..511] of AnsiChar;
    Comment: array[0..1023] of AnsiChar;
  end;
  TOtMetaFileRaw = record
    Size: Int64;
    Path: array[0..4095] of AnsiChar;
  end;
  TOtMetaExtraRaw = record
    Created: Int64;
    Pieces, PieceLength: Integer;
    Creator, Publisher: array[0..511] of AnsiChar;
    PublisherURL: array[0..2047] of AnsiChar;
    Hash: array[0..31] of Byte;
    WebSeeds: array[0..4095] of AnsiChar;
  end;
  TOtVersion = function: Integer; cdecl;
  TOtCreate = function(Options: Pointer; UserAgent: PAnsiChar): Pointer; cdecl;
  TOtDestroy = procedure(Session: Pointer); cdecl;
  TOtAdd = function(Session: Pointer; FileName, SavePath: PAnsiChar): Integer; cdecl;
  TOtSnapshotProc = function(Session: Pointer; Id: Integer; out Value: TOtSnapshot): Integer; cdecl;
  TOtSnapshotUploaded = function(Session: Pointer; Id: Integer; out Value: TOtSnapshot; out Bytes: Int64): Integer; cdecl;
  TOtCommand = function(Session: Pointer; Id, Command: Integer): Integer; cdecl;
  TOtError = function: PAnsiChar; cdecl;
  TOtMetaOpen = function(FileName: PAnsiChar): Pointer; cdecl;
  TOtMetaClose = procedure(Metadata: Pointer); cdecl;
  TOtMetaInfoProc = function(Metadata: Pointer; out Info: TOtMetaInfoRaw): Integer; cdecl;
  TOtMetaFileProc = function(Metadata: Pointer; Index: Integer; out Info: TOtMetaFileRaw): Integer; cdecl;
  TOtMetaTracker = function(Metadata: Pointer; Index: Integer; Buffer: PAnsiChar; Capacity: Integer): Integer; cdecl;
  TOtAddSelected = function(Session: Pointer; FileName, SavePath: PAnsiChar;
    Priorities: PInteger; Count, Start: Integer): Integer; cdecl;
  TOtConfigure = function(Session: Pointer; Port, DownKiB, UpKiB, Connections: Integer): Integer; cdecl;
  TOtMetaExtraProc = function(Metadata: Pointer; Data: PByte; Length: Integer; out Info: TOtMetaExtraRaw): Integer; cdecl;
  PPOtAnsiChar = ^PAnsiChar;
  TOtAddPrepared = function(Session: Pointer; FileName, Path: PAnsiChar;
    Priorities: PInteger; Count, Start, Sequential, DownloadBytes, UploadBytes: Integer;
    Paths, Trackers: PPOtAnsiChar; TrackerCount: Integer): Integer; cdecl;
  TOtPieceOpen = function(Session: Pointer; Id: Integer; out Header: TOtPieceHeader): Pointer; cdecl;
  TOtPieceBits = function(State: Pointer; Buffer: PByte; Capacity: Integer): Integer; cdecl;
  TOtPieceBlocks = function(State: Pointer; Buffer: Pointer; Capacity: Integer): Integer; cdecl;
  TOtPieceClose = procedure(State: Pointer); cdecl;
  TOtLibraryVersion = function: PAnsiChar; cdecl;
  TOtResumeRequest = function(Session: Pointer; Id, Flush: Integer): Integer; cdecl;
  TOtResumePoll = function(Session: Pointer; out Id, Status, Length: Integer): Pointer; cdecl;
  TOtBlobCopy = function(Blob: Pointer; Buffer: PByte; Capacity: Integer): Integer; cdecl;
  TOtBlobClose = procedure(Blob: Pointer); cdecl;
  TOtAddPreparedResume = function(Session: Pointer; FileName, Path: PAnsiChar;
    Priorities: PInteger; Count, Start, Sequential, DownloadBytes, UploadBytes: Integer;
    Paths, Trackers: PPOtAnsiChar; TrackerCount: Integer; Resume: PByte;
    ResumeLength: Integer; out ResumeUsed: Integer): Integer; cdecl;

implementation

end.
