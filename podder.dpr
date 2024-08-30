program podder;

// the program parameters are:
// -e (for adding episode nr)
// -h (for halting upon string found)

{$APPTYPE CONSOLE}

uses
  SysUtils, URLMon, Classes, StrUtils, System;

var
  rss_link, input_file, stripped_file, cwdPath: string;
  n: Integer;

function touch(s: string): Boolean;
var
  f: textfile;
begin
  // Make path to the file to be created
  cwdPath := ExtractFilePath(ParamStr(0)) + s;

  // Create file
  AssignFile(f, cwdPath);
{$I-}
  Rewrite(f);
{$I+}
  Result := IOResult = 0;
  CloseFile(f);
end;

function fixfilename(s: string): string;
var
  i: Integer;
  oldname: string;
begin
  Result := '';
  oldname := '_.tmp';
  touch(oldname);
  i := 1;
  while i <= Length(S) do
  begin
    if (S[i] in
      ['A'..'Z','a'..'z','0'..'9','_','-',' ','.',',','''',
       '(', ')','[', ']','{', '}','#','&','$','@','!','+','^']) then
      Result := Result + S[i] else
    begin
      if RenameFile(oldName, Result + S[i] + '.tmp') then
        Result := Result + S[i]
      else
        Result := Result + '_';
    end;
    oldname := Result + '.tmp';
    inc(i);
  end;
  if Length(s) = 0 then Result := '';
  DeleteFile(oldname);
  DeleteFile('_.tmp');
end;

function DownloadFile(SourceFile, DestFile: string): Boolean;
begin
  try
    Result := UrlDownloadToFile(nil, PChar(SourceFile), PChar(DestFile), 0, nil) = 0;
  except
    Result := False;
  end;
end;

procedure Strip;
var
  FText_in, FText_out: TStringList;
  i: integer;
begin
  FText_in := TStringList.Create;
  FText_out := TStringList.Create;
  try
    FText_in.LoadFromFile(input_file);

  //read the lines
    for i := 0 to FText_in.Count - 1 do
    begin
      if
        (AnsiPos(AnsiLowerCase('<item>'), AnsiLowerCase(FText_in[i])) > 0) or
        (AnsiPos(AnsiLowerCase('</item>'), AnsiLowerCase(FText_in[i])) > 0) or
        (AnsiPos(AnsiLowerCase('<title>'), AnsiLowerCase(FText_in[i])) > 0) or
        (AnsiPos(AnsiLowerCase('episode>'), AnsiLowerCase(FText_in[i])) > 0)
        then FText_out.Add(Trim(FText_in[i]));
      if
        (AnsiPos(AnsiLowerCase('url='), AnsiLowerCase(FText_in[i])) > 0) then
        begin
        FText_in[i] := '<enclosure ' + AnsiRightStr(FText_in[i],Length(FText_in[i]) -
        AnsiPos('url=',FText_in[i])+1);
        FText_out.Add(AnsiLeftStr(FText_in[i], AnsiPos('.mp3', FText_in[i]) + 3) + '">');
        end;
    end;
    FText_out.SaveToFile(stripped_file);

  finally
    FText_in.Free;
    FText_out.Free;
  end;
end;

procedure Get;
var
  FText_in: TStringList;
  Str, Episode, Title, URL: string;
  i, m: integer;
begin
  FText_in := TStringList.Create;
  m := 0;
  Title := '';
  Episode := '';
  URL := '';
  try
    FText_in.LoadFromFile(stripped_file);

  //read the lines
    for i := 0 to FText_in.Count - 1 do
    begin
      if (AnsiPos(AnsiLowerCase('<item>'), AnsiLowerCase(FText_in[i])) > 0)
        then m := m + 1;
      if (AnsiPos(AnsiLowerCase('title>'), AnsiLowerCase(FText_in[i])) > 0)
        then
      begin
        FText_in[i] := AnsiRightStr(FText_in[i],Length(FText_in[i]) -
        AnsiPos('title>',FText_in[i])-5);
        FText_in[i] := AnsiLeftStr(FText_in[i], AnsiPos('</',FText_in[i])-1);
        Title := FText_in[i];
      end;
      if (AnsiPos(AnsiLowerCase('episode>'), AnsiLowerCase(FText_in[i])) > 0)
        then
      begin
        FText_in[i] := AnsiRightStr(FText_in[i],Length(FText_in[i]) -
        AnsiPos('episode>',FText_in[i])-7);
        FText_in[i] := AnsiLeftStr(FText_in[i], AnsiPos('</',FText_in[i])-1);
        Episode := FText_in[i];
      end;
      if (AnsiPos(AnsiLowerCase('<enclosure url='), AnsiLowerCase(FText_in[i])) > 0)
        then
      begin
        FText_in[i] := AnsiRightStr(FText_in[i],Length(FText_in[i]) -
        AnsiPos('url=',FText_in[i])-4);
        FText_in[i] := AnsiLeftStr(FText_in[i], AnsiPos('>',FText_in[i])-2);
        URL := FText_in[i];
      end;
      if (AnsiPos(AnsiLowerCase('</item>'), AnsiLowerCase(FText_in[i])) > 0)
      and (Title <> '') and (URL <> '') then
      begin
        Str := Title;
        if FindCmdLineSwitch('e', True) then Str:= Episode + ' - ' + Title;
        Str := fixfilename(Str) + '.mp3';
        Episode := '';
        Title := '';
        if not FileExists(Str) then
        begin
          if DownloadFile(URL, PChar(ExtractFilePath(ParamStr(0)) + Str)) then
          begin
            if FileExists(Str) then Writeln('FILE IS DOWNLOADED: ', Str)
            else Writeln('FILE DOWNLOAD ERROR: ', Str);
            URL := '';
          end;
        end
        else
        begin
          Write('FILE ALREADY FOUND: ');
          Writeln(Str);
          Str := '';
          if FindCmdLineSwitch('h', True) then exit;
        end;
      end;
    end;
  finally
    FText_in.Free;
  end;
end;

begin
  rss_link := '';
  input_file := 'rss.txt';
  stripped_file := 'rss_strip.txt';
  for n := 1 to ParamCount do
    if not (ParamStr(n)[1] in ['-','/']) then rss_link := ParamStr(n);
  if rss_link <> '' then
  begin
  Writeln('Downloading RSS file: ', rss_link);
  if (DownloadFile(rss_link, PChar(ExtractFilePath(ParamStr(0)) + input_file)))
  then Writeln('Done!') else Writeln('Could not download!');
  Writeln;
  end;
  if FileExists(input_file) then
    begin
    Writeln('Downloading files...');
    Writeln;
    Strip;
    Get;
    end else
    Writeln('No ', input_file, ' file found in the program path! Exiting.');
end.

