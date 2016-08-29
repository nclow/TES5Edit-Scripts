{
  Assigns selected records to levelled lists, and outputs those changes to the 
  .esp file you select.

  If you run any other mod that touches loot at all, you will REALLY want to 
  make a Bashed Patch after doing this, to merge the changes to the leveled 
  lists, or you will have overwrite problems and won't get the loot you expect.

  There are hundreds of leveled lists, so this script looks at the Keywords (KWDA) 
  and if the record (usually an ARMO or WEAP) matches a set of keywords, it gets 
  added to the leveled lists for those keywords.

  EXAMPLE: An ARMO record has the keyword 'ArmorBoots' and also the keyword 'ArmorLight'
  so it gets added to the 'LItemArmorBootsLight' leveled list so it will show up in 
  treasure chests in the world.

  More mappings can be added below. 
  
}
unit userscript;

var targetKeywords : TStringList;
var leveledLists : TStringList;
var init : boolean;
var outFile : IInterface;
var thisFile : IInterface;

function Initialize: integer;
  var t, l : TStringList;
begin
  AddMessage('-------------------');
  t := TStringList.Create;
  l := TStringList.Create;

  // The LItemArmor[Slot][Light|Heavy] tend to be what is found in chests.
  // For NPC equipment loot, look for the LItem[NPCType][Slot] lists
  // e.g. LItemBanditCuirass
  // https://dl.dropboxusercontent.com/u/1785058/SkyrimMods/SkyrimLeveledListReference.txt

  //t.add() // If the record has all of these keywords (KWDA)
  //l.add() // then add the record to these levelled lists (LVLI)

  t.add('ArmorBoots,ArmorLight');
  l.add('LItemArmorBootsLight'); 

  t.add('ArmorBoots,ArmorHeavy');
  l.add('LItemArmorBootsHeavy'); 

  t.add('ArmorCuirass,ArmorLight');
  l.add('LItemArmorCuirassLight');

  t.add('ArmorCuirass,ArmorHeavy');
  l.add('LItemArmorCuirassHeavy'); 

  t.add('ArmorGauntlets,ArmorLight');
  l.add('LItemArmorGauntletsLight');

  t.add('ArmorGauntlets,ArmorHeavy');
  l.add('LItemArmorGauntletsHeavy'); 

  t.add('ArmorHelmet,ArmorLight');
  l.add('LItemArmorHelmetLight');

  t.add('ArmorHelmet,ArmorHeavy');
  l.add('LItemArmorHelmetHeavy'); 

  t.add('VendorItemJewelry');
  l.add('LItemJewelryAll'); 

  // t.add('ArmorCuirass');
  // l.add('testxxx, testyyy'); 
  
  targetKeywords := t;
  leveledLists := l;
  Result := 0;
end;

//one time only, with record
function InitOnce(e: IInterface): integer; 
  var i,j : integer;
  var llList : TStringList;
begin
  if init then Exit;

  thisFile := GetFile(e);
  FileSelectDlg(e); // Set up the target file

  //Copy the specified leveled lists
  for i := 0 to Pred(leveledLists.Count) do begin
    llList := TStringList.Create;
    llList.CommaText := leveledLists[i];
    for j := 0 to Pred(llList.Count) do begin
      CopyLeveledListFromMaster(llList[j]);
    end;
  end;
  init := True;

end;

function HasAllKeywords(rec : IInterface; keywords : TStringList): boolean;
  var i : integer;
begin
  Result := True;
  for i := 0 to Pred(keywords.Count) do begin
    if not HasKeyword(rec, keywords[i]) then Result := False;
  end;
end;

function HasKeyword(rec : IInterface; keyword : string): boolean;
  var keywords, el : IInterface;
  var i : integer;
begin
  Result := False;
  keywords := ElementByPath(rec, 'KWDA');

  for i := 0 to Pred(ElementCount(keywords)) do begin
    el := ElementByIndex(keywords, i);
    //AddMessage(keyword + '=' +  GetEditValue(el) );
    if BeginsWith(keyword, GetEditValue(el))
    then begin
      Result := True;
      break;
    end;
  end;
  //AddMessage('HasKeyword: ' + keyword + ' ' + BoolToStr(Result));
end;

function BeginsWith(substr : string; str : string): boolean;
var p : integer;
begin
	p := Pos(substr, str);
	Result := p = 1;
end;

//Thanks Delphi/JVCL. You're great.
function BoolToStr(b : boolean) : string;
begin
  if b then Result := 'True' else Result := 'False';
end;

//from 'Copy as override.pas'
function FileSelectDlg(e: IInterface): integer;
var
  i: integer;
  frm: TForm;
  clb: TCheckListBox;
begin
  if Signature(e) = 'TES4' then
    Exit;
    
  if not Assigned(outFile) then begin
    frm := frmFileSelect;
    try
      frm.Caption := 'Select a plugin';
      clb := TCheckListBox(frm.FindComponent('CheckListBox1'));
      clb.Items.Add('<new file>');
      for i := Pred(FileCount) downto 0 do
        if GetFileName(e) <> GetFileName(FileByIndex(i)) then
          clb.Items.InsertObject(1, GetFileName(FileByIndex(i)), FileByIndex(i))
        else
          Break;
      if frm.ShowModal <> mrOk then begin
        Result := 1;
        Exit;
      end;
      for i := 0 to Pred(clb.Items.Count) do
        if clb.Checked[i] then begin
          if i = 0 then outFile := AddNewFile else
            outFile := ObjectToElement(clb.Items.Objects[i]);
          Break;
        end;
    finally
      frm.Free;
    end;
    if not Assigned(outFile) then begin
      Result := 1;
      Exit;
    end;
  end;
  AddRequiredElementMasters(e, outFile, False);
  //wbCopyElementToFile(e, ToFile, False, True);
end;

function AddToLeveledList(armoRecord : IInterface; listName : string): integer;
  var list, container, newEntry : IInterface;
begin
  //get new record from output file
  list := MainRecordByEditorID(GroupBySignature(outfile, 'LVLI'), listName);
  
  //append new entry
  container := ElementByPath(list, 'Leveled List Entries');  
  newEntry := ElementByIndex(container, 0);
  ElementAssign(container, HighInteger, newEntry, False);
  //try to set ref value
  SetElementEditValues(newEntry, 'LVLO\Reference', Name(armoRecord));

  AddMessage('Added ' + Name(armoRecord) + ' => ' + listName);
end;

function CopyLeveledListFromMaster(listName : string): integer;
  var master, rec : IInterface;
begin
  //Get Skyrim.esm
  master := FileByIndex(0);
  //Copy leveled list from skyrim.esm
  rec := MainRecordByEditorID(GroupBySignature(master, 'LVLI'), listName);

  If not Assigned(rec) then
    AddMessage('Warning! List ' + listName + ' not found in ' + GetFileName(master));

  wbCopyElementToFile(rec, outFile, False, True);
  AddMessage('Copied leveled list ' + listName + ' from Skyrim.esm to ' + GetFileName(outFile));
end;


// called for every record selected in xEdit
function Process(e: IInterface): integer;
  var s, formId : string;
  var i,j : integer;
  var el, keyword, keywords, outFile : IInterface;
  var kwList, llList : TStringList;
  var matched : boolean;

begin
  matched := False;
  InitOnce(e);

  //TODO: set level and count??

  // Go through our keyword/list map and add stuff
  // Exploding out the sublist is because I've tried 20 different ways to have 
  // a list of lists or any kind of structured data and failed. Supports only 
  // insanely small and old subset of delphi.
  for i := 0 to Pred(targetKeywords.Count) do 
  begin
    //AddMessage('Checking for keywords: ' + targetKeywords[i]);
    kwList := TStringList.Create;
    kwList.CommaText := targetKeywords[i];
    if HasAllKeywords(e, kwList) then begin
      matched := True;
      llList := TStringList.Create;
      llList.CommaText := leveledLists[i];
      for j := 0 to Pred(llList.Count) do begin
        AddToLeveledList(e, llList[j]);
      end;
    end
  end;
  if not matched then AddMessage('Couldn''t match ' + Name(e) + '. Not copied.');
end;

end.
