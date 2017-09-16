unit ThreadPoolUnit;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ExtCtrls;

type
  TForm3 = class(TForm)
    PaintBox1: TPaintBox;
    Button1: TButton;
    ListBox1: TListBox;
    procedure Button1Click(Sender: TObject);
  private
    type
      TWorkerColor = class
        FThreadID: Integer;
        FColor: TColor;
        FForm: TForm3;
        procedure PaintLines(Sender: TObject);
        procedure PaintLine;
        constructor Create(AForm: TForm3; AColor: TColor);
      end;
    var
      FIndex: Integer;
  public
    { Public declarations }
  end;

  TObjectHelper = class helper for TObject

  end;

  TThreadPool = class
  strict protected
    class function InternalThreadFunction(lpThreadParameter: Pointer): Integer; stdcall; static;
  private
    type
      TUserWorkItem = class
        FSender: TObject;
        FWorkerEvent: TNotifyEvent;
      end;
    class procedure QueueWorkItem(Sender: TObject; WorkerEvent: TNotifyEvent; Flags: ULONG); overload; static;
  public
    class procedure QueueWorkItem(Sender: TObject; WorkerEvent: TNotifyEvent); overload; static;
    class procedure QueueIOWorkItem(Sender: TObject; WorkerEvent: TNotifyEvent); static;
    class procedure QueueUIWorkItem(Sender: TObject; WorkerEvent: TNotifyEvent); static;
  end;

var
  Form3: TForm3;
  ThreadPool: TThreadPool;

implementation

{$R *.dfm}

const
  WT_EXECUTEDEFAULT       = ULONG($00000000);
  WT_EXECUTEINIOTHREAD    = ULONG($00000001);
  WT_EXECUTEINUITHREAD    = ULONG($00000002);
  WT_EXECUTEINWAITTHREAD  = ULONG($00000004);
  WT_EXECUTEONLYONCE      = ULONG($00000008);
  WT_EXECUTEINTIMERTHREAD = ULONG($00000020);
  WT_EXECUTELONGFUNCTION  = ULONG($00000010);
  WT_EXECUTEINPERSISTENTIOTHREAD  = ULONG($00000040);
  WT_EXECUTEINPERSISTENTTHREAD = ULONG($00000080);
  WT_TRANSFER_IMPERSONATION = ULONG($00000100);

function QueueUserWorkItem (func: TThreadStartRoutine; Context: Pointer; Flags: ULONG): BOOL; stdcall; external kernel32 name 'QueueUserWorkItem';

class function TThreadPool.InternalThreadFunction(lpThreadParameter: Pointer): Integer;
begin
  Result := 0;
  try
    try
      with TThreadPool.TUserWorkItem(lpThreadParameter) do
        if Assigned(FWorkerEvent) then
          FWorkerEvent(FSender);
    finally
      TThreadPool.TUserWorkItem(lpThreadParameter).Free;
    end;
  except

  end;
end;

{ TThreadPool }

class procedure TThreadPool.QueueWorkItem(Sender: TObject; WorkerEvent: TNotifyEvent);
begin
  QueueWorkItem(Sender, WorkerEvent, WT_EXECUTEDEFAULT);
end;

class procedure TThreadPool.QueueIOWorkItem(Sender: TObject; WorkerEvent: TNotifyEvent);
begin
  QueueWorkItem(Sender, WorkerEvent, WT_EXECUTEINIOTHREAD);
end;

class procedure TThreadPool.QueueUIWorkItem(Sender: TObject; WorkerEvent: TNotifyEvent);
begin
  QueueWorkItem(Sender, WorkerEvent, WT_EXECUTEINUITHREAD);
end;

class procedure TThreadPool.QueueWorkItem(Sender: TObject; WorkerEvent: TNotifyEvent; Flags: ULONG);
var
  WorkItem: TUserWorkItem;
begin
  if Assigned(WorkerEvent) then
  begin
    IsMultiThread := True;
    WorkItem := TUserWorkItem.Create;
    try
      WorkItem.FWorkerEvent := WorkerEvent;
      WorkItem.FSender := Sender;
      if not QueueUserWorkItem(InternalThreadFunction, WorkItem, Flags) then
        RaiseLastOSError;
    except
      WorkItem.Free;
      raise;
    end;
 end;
end;

procedure TForm3.Button1Click(Sender: TObject);
begin
  FIndex := PaintBox1.Height;
  PaintBox1.Repaint;
  ListBox1.Items.Clear;
  TWorkerColor.Create(Self, clBlue);
  TWorkerColor.Create(Self, clRed);
  TWorkerColor.Create(Self, clYellow);
  TWorkerColor.Create(Self, clLime);
  TWorkerColor.Create(Self, clFuchsia);
  TWorkerColor.Create(Self, clTeal);
end;

{ TForm3.TWorkerColor }

constructor TForm3.TWorkerColor.Create(AForm: TForm3; AColor: TColor);
begin
  FForm := AForm;
  FColor := AColor;
  TThreadPool.QueueWorkItem(Self, PaintLines);
end;

procedure TForm3.TWorkerColor.PaintLines(Sender: TObject);
var
  I: Integer;
begin
  FThreadID := GetCurrentThreadID;
  for I := 0 to 9 do
  begin
    PaintLine;
    //TThread.Synchronize(nil, PaintLine);
//    Sleep(100);
  end;
  Destroy;
end;

procedure TForm3.TWorkerColor.PaintLine;
begin
  FForm.PaintBox1.Canvas.Lock;
  try
    FForm.ListBox1.Items.Add(IntToStr(FThreadID));
    with FForm.PaintBox1 do
    begin
      Canvas.Pen.Color := FColor;
      Canvas.Polyline([Point(0, FForm.FIndex), Point(Width, FForm.FIndex)]);
      Dec(FForm.FIndex);
      if FForm.FIndex <= 0 then
        FForm.FIndex := 0;
    end;
  finally
    FForm.PaintBox1.Canvas.Unlock;
  end;
end;

end.
