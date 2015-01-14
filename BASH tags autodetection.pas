{
	Purpose: Bash Tagger
	Game: FO3/FNV/TESV
	Author: fireundubh <fireundubh@gmail.com>
	Version: 1.3.8 (based on "BASH tags autodetection.pas" v1.0)

	Description: This script detects up to 49 bash tags in FO3, FNV, and Skyrim plugins.
		Tags automatically replace the Description in the File Header. Wrye Bash/Flash can
		then use these tags to help you create more intelligent bashed patches.

	Requires mteFunctions (by matortheeternal):
		https://github.com/matortheeternal/TES5EditScripts/blob/master/trunk/Edit%20Scripts/mteFunctions.pas

	Not implemented:
		Creatures.Blood, Deactivate, Deflst, Filter, NoMerge, Npc.EyesOnly, Npc.HairOnly,
		R.Attributes-F, R.Attributes-M, R.AddSpells, R.ChangeSpells

	Future plans:
		Support Oblivion
		Allow user to run script on all plugins at once
}

unit BashTagsDetector;

uses mteFunctions;

var
	fi: IwbFile;
	slTags, slMasters: TStringList;
	fn, tag, game: string;
	optionSelected: integer;

{==================================================================}
{Returns True if the string is uppercase and False if not}
function IsUppercase(x: string): boolean;
begin
	Result := (x = Uppercase(x));
end;

{==================================================================}
// Universal ElementBy
function GetElement(e: IInterface; x: string): IInterface;
var
	i: integer;
begin
	if (pos('[', x) > 0) then i := 1
	else if (pos('\', x) > 0) then i := 3
	else if IsUppercase(x) then i := 2
	else if not IsUpperCase(x) then i := 4
	else i := 5;
	
	case i of
		1 : Result := ElementByIP(e, x);
		2 : Result := ElementBySignature(e, x);
		3 : Result := ElementByPath(e, x);
		4 : Result := ElementByName(e, x);
	else
		Result := ElementByPath(e, x);
	end;
end;

{==================================================================}
// Debug Message
function ShowDebugMessageFromElement(x, y: IInterface; t: string): integer;
begin
	AddMessage(t + ': ' + FullPath(x));
	AddMessage(t + ': ' + FullPath(y));
end;

{==================================================================}
// Debug Message
function ShowDebugMessageFromString(x, y: IInterface; p, t: string): integer;
begin
	AddMessage(t + ': ' + FullPath(GetElement(x, p)));
	AddMessage(t + ': ' + FullPath(GetElement(y, p)));
end;

{==================================================================}
{Return true if the loaded game is Fallout 3}
function IsFallout3(game: string): boolean;
begin
	Result := (game = 'Fallout3.esm');
end;

{==================================================================}
{Return true if the loaded game is Fallout: New Vegas}
function IsFalloutNV(const game: string): boolean;
begin
	Result := (game = 'FalloutNV.esm');
end;

{==================================================================}
{Return true if the loaded game is TES4: Oblivion}
function IsOblivion(const game: string): boolean;
begin
	Result := (game = 'Oblivion.esm');
end;

{==================================================================}
{Return true if the loaded game is TES4: Skyrim}
function IsSkyrim(const game: string): boolean;
begin
	Result := (game = 'Skyrim.esm');
end;

{==================================================================}
{Alias for GetEditValue}
function gev(x: IInterface): string;
begin
	Result := GetEditValue(x);
end;

{==================================================================}
{Alias for GetEditValue}
function gnv(x: IInterface): string;
begin
	Result := GetNativeValue(x);
end;

{==================================================================}
{Check if the tag already exists}
function TagExists(t: string): boolean;
begin
	Result := (slTags.IndexOf(t) <> -1);
end;

{==================================================================}
{Add the tag if the tag does not exist}
procedure AddTag(t: string);
begin
	if not TagExists(t) then
		slTags.Add(t);
end;

{==================================================================}
{Get element from list by some value}
function GetElementByValue(el: IInterface; smth, somevalue: string): IInterface;
var
	i: integer;
	entry: IInterface;
begin
	Result := nil;
	for i := 0 to ElementCount(el) - 1 do begin
		entry := ElementByIndex(el, i);
		if geev(entry, smth) = somevalue then begin
			Result := entry;
			exit;
		end;
	end;
end;

//{==================================================================}
//{Returns True if the element has a any flags and False if not}
//function HasAnyFlag(x: IInterface): boolean;
//var
//	f: TStringList;
//begin
//	f := TStringList.Create;
//	f.Text := FlagValues(x);
//	Result := (f.Count <> 0);
//	f.Free;
//end;

//{==================================================================}
//{Returns True if the element has a specific flag and False if not}
//function HasFlag(x: IInterface; y: string): boolean;
//var
//	f: TStringList;
//begin
//	f := TStringList.Create;
//	f.Text := FlagValues(x);
//	Result := (f.IndexOf(y) <> -1);
//	f.Free;
//end;

{==================================================================}
{Return True if specific flag is set and False if not}
function IsFlagSet(f: IInterface; s: string): boolean;
var
	flags: TStringList;
	i: integer;
begin
	flags := TStringList.Create;
	flags.DelimitedText := '"Use Traits=1", "Use Stats=2", "Use Factions=4", "Use Actor Effect List=8", "Use AI Data=16", "Use AI Packages=32", "Use Model/Animation=64", "Use Base Data=128", "Use Inventory=256", "Use Script=512", "Is Interior Cell=1", "Has water=2", "Behave like exterior=128", "ESM=1", "Deleted=32", "Dangerous=131072"';
	i := StrToInt(flags.Values[s]);
	flags.Free;
	Result := (gnv(f) and i > 0);
end;

{==================================================================}
// Validate
{Determines whether two elements are different and suggests tags}
{Not to be used when you need to know how two elements differ}
function Validate(x, y: IInterface; tag: string; debug: boolean): integer;
var
	i, j, k, l, m: integer;
begin	
	{Exit if the conflict isn't worth the effort}
	if (ConflictAllForElements(x, y, false, IsInjected(Master(y))) = caUnknown)
	or (ConflictAllForElements(x, y, false, IsInjected(Master(y))) = caConflict)
	or (ConflictAllForElements(x, y, false, IsInjected(Master(y))) = caConflictCritical) then
		exit;

	{Exit if the tag already exists}
	if TagExists(tag) then
		exit;

	{Suggest tag if one element exists while the other does not}
	if Assigned(x) <> Assigned(y) then begin
		if debug then AddMessage('[0] ' + tag + ': ' + FullPath(x));
		if debug then AddMessage('[0] ' + tag + ': ' + FullPath(y));
		AddTag(tag);
		exit;
	end;
	
	if not Assigned(x) then
		exit;

	{Suggest tag if the two elements are different}
	if ElementCount(x) <> ElementCount(y) then begin
		if debug then AddMessage('[1] ' + tag + ': ' + FullPath(x));
		if debug then AddMessage('[1] ' + tag + ': ' + FullPath(y));
		AddTag(tag);
		exit;
	end;
	
	if gev(x) <> gev(y) then begin
		AddTag(tag);
		exit;
	end;

	{Iterate through elements, down five levels if needed, and suggest tags}
	for i := 0 to ElementCount(x) - 1 do begin
		if ElementCount(ElementByIndex(x, i)) = 0 then begin
			if gev(ElementByIndex(x, i)) <> gev(ElementByIndex(y, i)) then begin
				if debug then AddMessage('[2] ' + tag + ': ' + FullPath(x));
				if debug then AddMessage('[2] ' + tag + ': ' + FullPath(y));
				AddTag(tag);
				exit;
			end;
		end
		else begin
			for j := 0 to ElementCount(ElementByIndex(x, i)) - 1 do begin
				if ElementCount(ElementByIndex(ElementByIndex(x, i), j)) = 0 then begin
					if gev(ElementByIndex(ElementByIndex(x, i), j)) <> gev(ElementByIndex(ElementByIndex(y, i), j)) then begin
						if debug then AddMessage('[3] ' + tag + ': ' + FullPath(x));
						if debug then AddMessage('[3] ' + tag + ': ' + FullPath(y));
						AddTag(tag);
						exit;
					end;
				end
				else begin
					for k := 0 to ElementCount(ElementByIndex(x, j)) - 1 do begin
						if ElementCount(ElementByIndex(ElementByIndex(x, j), k)) = 0 then begin
							if gev(ElementByIndex(ElementByIndex(x, j), k)) <> gev(ElementByIndex(ElementByIndex(y, j), k)) then begin
								if debug then AddMessage('[4] ' + tag + ': ' + FullPath(x));
								if debug then AddMessage('[4] ' + tag + ': ' + FullPath(y));
								AddTag(tag);
								exit;
							end;
						end
						else begin
							for l := 0 to ElementCount(ElementByIndex(x, k)) - 1 do begin
								if ElementCount(ElementByIndex(ElementByIndex(x, k), l)) = 0 then begin
									if gev(ElementByIndex(ElementByIndex(x, k), l)) <> gev(ElementByIndex(ElementByIndex(y, k), l)) then begin
										if debug then AddMessage('[5] ' + tag + ': ' + FullPath(x));
										if debug then AddMessage('[5] ' + tag + ': ' + FullPath(y));
										AddTag(tag);
										exit;
									end;
								end
								else begin
									for m := 0 to ElementCount(ElementByIndex(x, l)) - 1 do begin
										if ElementCount(ElementByIndex(ElementByIndex(x, l), m)) = 0 then begin
											if gev(ElementByIndex(ElementByIndex(x, l), m)) <> gev(ElementByIndex(ElementByIndex(y, l), m)) then begin
												if debug then AddMessage('[6] ' + tag + ': ' + FullPath(x));
												if debug then AddMessage('[6] ' + tag + ': ' + FullPath(y));
												AddTag(tag);
												exit;
											end;
										end;
									end;
								end;
							end;
						end;
					end;
				end;
			end;
		end;
	end;
end;

{==================================================================}
// Validate Aliases
function Evaluate(x, y: IInterface; z: string; tag: string; debug: boolean): integer;
begin
	Validate(GetElement(x, z), GetElement(y, z), tag, debug);
end;

{==================================================================}
// Delev, Relev (written by the xEdit team)
function CheckDelevRelev(e, m: IInterface; debug: boolean): integer;
var
	i, matched: integer;
	entries, entriesmaster: IInterface; // leveled list entries
	ent, entm: IInterface; // leveled list entry
	coed, coedm: IInterface; // extra data
	s1, s2: string; // sortkeys for extra data, sortkey is a compact text representation of element's values
begin
	// nothing to do if already tagged
	if TagExists('Delev') and TagExists('Relev') then
		exit;

	// get Leveled List Entries
	entries := GetElement(e, 'Leveled List Entries');
	entriesmaster := GetElement(m, 'Leveled List Entries');
	if not Assigned(entries) or not Assigned(entriesmaster) then
		exit;

	// count matched on reference entries
	matched := 0;
	// iterate through all entries
	for i := 0 to ElementCount(entries) - 1 do begin
		ent := ElementByIndex(entries, i);
		// find the same entry in master
		entm := GetElementByValue(entriesmaster, 'LVLO\Reference', geev(ent, 'LVLO\Reference'));
		if Assigned(entm) then begin
			Inc(matched);
			// Relev check for changed level, count, extra data
			coed := GetElement(ent, 'COED');
			coedm := GetElement(entm, 'COED');
			if Assigned(coed) then s1 := SortKey(coed, True) else s1 := '';
			if Assigned(coedm) then s2 := SortKey(coedm, True) else s2 := '';
			if (genv(ent, 'LVLO\Level') <> genv(entm, 'LVLO\Level'))
			or (genv(ent, 'LVLO\Count') <> genv(entm, 'LVLO\Count'))
			or (s1 <> s2) then begin
				if debug then AddMessage('Relev: ' + FullPath(e));
				AddTag('Relev');
			end;
		end;
	end;

	// if number of matched entries less than in master list
	if matched < ElementCount(entriesmaster) then begin
		if debug then AddMessage('Delev: ' + FullPath(entries));
		AddTag('Delev');
	end;
end;

{==================================================================}
// Invent (written by the xEdit team)
function CheckInvent(e, m: IInterface; debug: boolean): integer;
var
	items, itemsmaster: IInterface;
begin
	tag := 'Invent';

	if TagExists(tag) then
		exit;

	items := GetElement(e, 'Items');
	itemsmaster := GetElement(m, 'Items');

	if Assigned(items) <> Assigned(itemsmaster) then begin
		if debug then ShowDebugMessageFromElement(e, m, tag);
		AddTag(tag);
		exit;
	end;

	if not Assigned(items) then
		exit;

	// Items are sorted, so we don't need to compare by individual item
	// SortKey combines all the items data
	if SortKey(items, True) <> SortKey(itemsmaster, True) then begin
		if debug then ShowDebugMessageFromElement(items, itemsmaster, tag);
		AddTag(tag);
	end;
end;

{==================================================================}
// v1.3.3 - Actors.ACBS
function CheckActorsACBS(e, m: IInterface; debug: boolean): integer;
var
	f, fm, t, tm: IInterface;
begin
	tag := 'Actors.ACBS';

	// get ACBS element
	f := GetElement(e, 'ACBS');
	fm := GetElement(m, 'ACBS');
	
	t := GetElement(f, 'Template Flags');
	tm := GetElement(fm, 'Template Flags');
	
	// If the Use Stats (0x2) template flag is set, don't bother
	if IsFlagSet(t, 'Use Stats') or IsFlagSet(tm, 'Use Stats') then
		exit;

	// If the Use Base Data flag is not set, then check Flags
	if not IsFlagSet(t, 'Use Base Data') or not IsFlagSet(tm, 'Use Base Data') then begin
		if gnv(GetElement(f, 'Flags')) <> gnv(GetElement(fm, 'Flags')) then begin
			if debug then ShowDebugMessageFromString(e, m, 'ACBS\Flags', tag);
			AddTag(tag);
			exit;
		end;
	end;

	// Validators
	Evaluate(f, fm, 'Fatigue', tag, debug);
	Evaluate(f, fm, 'Level', tag, debug);
	Evaluate(f, fm, 'Calc min', tag, debug);
	Evaluate(f, fm, 'Calc max', tag, debug);
	Evaluate(f, fm, 'Speed Multiplier', tag, debug);
	Evaluate(e, m, 'DATA\Base Health', tag, debug);

	// If the Use AI Data (0x16) template is not set, validate ACBS\Barter gold
	if not IsFlagSet(t, 'Use AI Data') or not IsFlagSet(tm, 'Use AI Data') then
		Evaluate(f, fm, 'Barter gold', tag, debug);

end;

{==================================================================}
// Actors.AIData
function CheckActorsAIData(e, m: IInterface; debug: boolean): integer;
var
	a, am: IInterface;
begin
	tag := 'Actors.AIData';
	
	// get ACBS element
	a := GetElement(e, 'AIDT');
	am := GetElement(m, 'AIDT');
	
	// Validators
	Evaluate(a, am, 'Aggression', tag, debug);
	Evaluate(a, am, 'Confidence', tag, debug);
	Evaluate(a, am, 'Energy level', tag, debug);
	Evaluate(a, am, 'Responsibility', tag, debug);

	// v1.3.3 - More flags
	if gnv(GetElement(a, 'Buys/Sells and Services')) <> gnv(GetElement(am, 'Buys/Sells and Services')) then begin
		if debug then ShowDebugMessageFromString(a, am, 'Buys/Sells and Services', tag);
		AddTag(tag);
		exit;
	end;

	Evaluate(a, am, 'Teaches', tag, debug);
	Evaluate(a, am, 'Maximum training level', tag, debug);
end;

{==================================================================}
// Actors.AIPackages
function CheckActorsAIPackages(e, m: IInterface; debug: boolean): integer;
begin
	tag := 'Actors.AIPackages';
	Evaluate(e, m, 'Packages', tag, debug);
end;

{==================================================================}
// Actors.Skeleton
function CheckActorsSkeleton(e, m: IInterface; debug: boolean): integer;
var
	model, modelm: IInterface;
begin
	tag := 'Actors.Skeleton';

	// get model objects
	model := GetElement(e, 'Model');
	modelm := GetElement(m, 'Model');

	// A fix that might cause problems... We'll see!
	if not Assigned(model) then
		exit;

	// Validators
	Evaluate(model, modelm, 'MODL', tag, debug);
	Evaluate(model, modelm, 'MODB', tag, debug);
	Evaluate(model, modelm, 'MODT', tag, debug);
end;

{==================================================================}
// Actors.Stats
function CheckActorsStats(e, m: IInterface; debug: boolean): integer;
var
	d, dm: IInterface;
	sig: string;
begin
	tag := 'Actors.Stats';

	// get record signature
	sig := Signature(e);

	// get data objects
	d := GetElement(e, 'DATA');
	dm := GetElement(m, 'DATA');

	// validators
	// creatures
	if (sig = 'CREA') then begin
		Evaluate(d, dm, 'Health', tag, debug);
		Evaluate(d, dm, 'Combat Skill', tag, debug);
		Evaluate(d, dm, 'Magic Skill', tag, debug);
		Evaluate(d, dm, 'Stealth Skill', tag, debug);
		Evaluate(d, dm, 'Attributes', tag, debug);
	end;

	// non-player characters
	if (sig = 'NPC_') then begin
		Evaluate(d, dm, 'Base Health', tag, debug);
		Evaluate(d, dm, 'Attributes', tag, debug);
		Evaluate(e, m, 'DNAM\Skill Values', tag, debug);
		Evaluate(e, m, 'DNAM\Skill Offsets', tag, debug);
	end;
end;

{==================================================================}
// Factions
function CheckActorsFactions(e, m: IInterface; debug: boolean): integer;
var
	f, fm: IInterface;
begin
	tag := 'Factions';
	
	if TagExists(tag) then
		exit;

	f := GetElement(e, 'Factions');
	fm := GetElement(m, 'Factions');

	if Assigned(f) <> Assigned(fm) then begin
		if debug then ShowDebugMessageFromElement(e, m, tag);
		AddTag(tag);
		exit;
	end;

	if not Assigned(f) then
		exit;

	if SortKey(f, True) <> SortKey(fm, True) then begin
		if debug then ShowDebugMessageFromElement(f, fm, tag);
		AddTag(tag);
	end;
end;

{==================================================================}
// NpcFaces
function CheckNPCFaces(e, m: IInterface; debug: boolean): integer;
begin
	tag := 'NpcFaces';
	
	// validators
	Evaluate(e, m, 'HNAM', tag, debug);
	Evaluate(e, m, 'LNAM', tag, debug);
	Evaluate(e, m, 'ENAM', tag, debug);
	Evaluate(e, m, 'HCLR', tag, debug);
	Evaluate(e, m, 'FaceGen Data', tag, debug);
end;

{==================================================================}
// Body-F
// Body-M
// Body-Size-F
// Body-Size-M
function CheckRaceBody(e, m: IInterface; tag: string; debug: boolean): integer;
begin
	if (tag = 'Body-F') then
		Evaluate(e, m, 'Body Data\Female Body Data\Parts', tag, debug);
	
	if (tag = 'Body-M') then
		Evaluate(e, m, 'Body Data\Male Body Data\Parts', tag, debug);
	
	if (tag = 'Body-Size-F') then begin
		Evaluate(e, m, 'DATA\Female Height', tag, debug);
		Evaluate(e, m, 'DATA\Female Weight', tag, debug);
	end;
	
	if (tag = 'Body-Size-M') then begin
		Evaluate(e, m, 'DATA\Male Height', tag, debug);
		Evaluate(e, m, 'DATA\Male Weight', tag, debug);
	end;
end;

{==================================================================}
// R.Ears
// R.Head (disabled due to Wrye Flash NV bug)
// R.Mouth
// R.Teeth
function CheckRaceHead(e, m: IInterface; tag: string; debug: boolean): integer;
begin

	if (tag = 'R.Head') then begin
		Evaluate(e, m, 'Head Data\Male Head Data\Parts\[0]', tag, debug);
		Evaluate(e, m, 'Head Data\Female Head Data\Parts\[0]', tag, debug);
		Evaluate(e, m, 'FaceGen Data', tag, debug);
	end;

	if (tag = 'R.Ears') then begin
		Evaluate(e, m, 'Head Data\Male Head Data\Parts\[1]', tag, debug);
		Evaluate(e, m, 'Head Data\Female Head Data\Parts\[1]', tag, debug);
	end;

	if (tag = 'R.Mouth') then begin
		Evaluate(e, m, 'Head Data\Male Head Data\Parts\[2]', tag, debug);
		Evaluate(e, m, 'Head Data\Female Head Data\Parts\[2]', tag, debug);
	end;

	if (tag = 'R.Teeth') then begin
		Evaluate(e, m, 'Head Data\Male Head Data\Parts\[3]', tag, debug);
		Evaluate(e, m, 'Head Data\Female Head Data\Parts\[3]', tag, debug);
		if IsFallout3(game) then begin
			Evaluate(e, m, 'Head Data\Male Head Data\Parts\[4]', tag, debug);
			Evaluate(e, m, 'Head Data\Female Head Data\Parts\[4]', tag, debug);
		end;
	end;

end;

{==================================================================}
// C.Climate
function CheckCellClimate(e, m: IInterface; debug: boolean): integer;
var
	d, dm: IInterface;
begin
	tag := 'C.Climate';

	// If the Behave like exterior (0x128) flag is set in one record but not in the other, suggest tag
	d := GetElement(e, 'DATA');
	dm := GetElement(m, 'DATA');
	
	if IsFlagSet(d, 'Behave like exterior') <> IsFlagSet(dm, 'Behave like exterior') then begin
		if debug then ShowDebugMessageFromString(e, m, 'DATA', tag);
		AddTag(tag);
		exit;
	end;

	Evaluate(e, m , 'XCCM', tag, debug);
end;

{==================================================================}
// C.RecordFlags
function CheckCellRecordFlags(e, m: IInterface; debug: boolean): integer;
var
	f, fm: IInterface;
begin
	tag := 'C.RecordFlags';

	f  := GetElement(e, 'Record Header\Record Flags');
	fm := GetElement(m, 'Record Header\Record Flags');

	if gnv(f) <> gnv(fm) then
		AddTag(tag);
end;

{==================================================================}
// C.Water
function CheckCellWater(e, m: IInterface; debug: boolean): integer;
var
	d, dm: IInterface;
begin
	tag := 'C.Water';

	// If the Has water (0x2) flag is set in one record but not in the other, suggest tag and exit
	d := GetElement(e, 'DATA');
	dm := GetElement(m, 'DATA');
	
	if IsFlagSet(d, 'Has water') <> IsFlagSet(dm, 'Has water') then begin
		if debug then ShowDebugMessageFromString(e, m, 'DATA', tag);
		AddTag(tag);
		exit;
	end;

	Evaluate(e, m, 'XCLW', tag, debug);
	Evaluate(e, m, 'XCWT', tag, debug);
end;

{==================================================================}
// Destructible
function CheckDestructible(e, m: IInterface; debug: boolean): integer;
var
	d, dm, f, fm: IInterface;
begin
	tag := 'Destructible';

	d := ElementByName(e, 'Destructable');
	dm := ElementByName(m, 'Destructable');

	if Assigned(d) <> Assigned(dm) then begin
		AddTag(tag);		
		exit;
	end;
	
	Evaluate(d, dm, 'DEST\Health', tag, debug);
	Evaluate(d, dm, 'DEST\Count', tag, debug);
	
	f := GetElement(d, 'DEST\Flags');
	fm := GetElement(dm, 'DEST\Flags');

	if gnv(f) <> gnv(fm) then begin
		if debug then ShowDebugMessageFromString(d, dm, 'DEST\Flags', tag);
		AddTag(tag);
		exit;
	end;

	Evaluate(d, dm, 'Stages', tag, debug);
end;

{==================================================================}
// Graphics
function CheckGraphics(e, m: IInterface; debug: boolean): integer;
var
	icon, iconm, modl, modlm: IInterface;
	sig: string;
	i: integer;
begin
	tag := 'Graphics';
	sig := Signature(e);

	if (sig = 'ALCH') or (sig = 'AMMO')	or (sig = 'BOOK')
	or (sig = 'CLAS')	or (sig = 'INGR')	or (sig = 'KEYM')
	or (sig = 'LIGH')	or (sig = 'LSCR') or (sig = 'LTEX')
	or (sig = 'MGEF') or (sig = 'MISC')	or (sig = 'REGN')
	or (sig = 'TREE')	or (sig = 'WEAP') then
		Evaluate(e, m, 'Icon', tag, debug);

	if (sig = 'ACTI')	or (sig = 'ALCH')	or (sig = 'AMMO')
	or (sig = 'BOOK')	or (sig = 'DOOR')	or (sig = 'FLOR')
	or (sig = 'FURN')	or (sig = 'GRAS')	or (sig = 'INGR')
	or (sig = 'KEYM')	or (sig = 'LIGH')	or (sig = 'MGEF')
	or (sig = 'MISC')	or (sig = 'STAT')	or (sig = 'TREE')
	or (sig = 'WEAP') then
		Evaluate(e, m, 'Model', tag, debug);

	if (sig = 'ARMO') then begin
		Evaluate(e, m, 'ICON', tag, debug);
		Evaluate(e, m, 'ICO2', tag, debug);
		Evaluate(e, m, 'Male biped model\MODL', tag, debug);
		Evaluate(e, m, 'Male biped model\MODT', tag, debug);
		Evaluate(e, m, 'Male world model\MOD2', tag, debug);
		Evaluate(e, m, 'Female biped model\MOD3', tag, debug);
		Evaluate(e, m, 'Female biped model\MO3T', tag, debug);
		Evaluate(e, m, 'Female world model\MOD4', tag, debug);
		if gnv(GetElement(e, 'BMDT\Biped Flags')) <> gnv(GetElement(m, 'BMDT\Biped Flags')) then
			if debug then ShowDebugMessageFromString(e, m, 'BMDT\Biped Flags', tag);
			AddTag(tag);
	end;

	if (sig ='CREA') then begin
		Validate(GetElement(e, 'NIFZ'), GetElement(m, 'NIFZ'), tag, debug);
		Validate(GetElement(e, 'NIFT'), GetElement(m, 'NIFT'), tag, debug);
	end;

	// 1.2 improved efsh validation
	if (sig = 'EFSH') then begin
		if gnv(GetElement(e, 'Record Header\Record Flags')) <> gnv(GetElement(m, 'Record Header\Record Flags')) then begin
			if debug then ShowDebugMessageFromString(e, m, 'Record Header\Record Flags', tag);
			AddTag(tag);
			exit;
		end;
		Evaluate(e, m, 'ICON', tag, debug);
		Evaluate(e, m, 'ICO2', tag, debug);
		Evaluate(e, m, 'NAM7', tag, debug);
		if IsSkyrim(game) then begin
			Evaluate(e, m, 'NAM8', tag, debug);
			Evaluate(e, m, 'NAM9', tag, debug);
		end;
		Evaluate(e, m, 'DATA', tag, debug);
	end;

	// 1.3.8 - added static material
	if (sig = 'STAT') then
		Evaluate(e, m, 'DNAM\Material', tag, debug)
	
end;

{==================================================================}
// SpellStats
function CheckSpellStats(e, m: IInterface; debug: boolean): integer;
begin
	tag := 'SpellStats';
	Evaluate(e, m, 'FULL', tag, debug);
	Evaluate(e, m, 'SPIT', tag, debug);
end;

{==================================================================}
// Sound
function CheckSound(e, m: IInterface; debug: boolean): integer;
var
	sig: string;
begin
	tag := 'Sound';
	sig := Signature(e);

	// Activators, Containers, Doors, and Lights
	if (sig = 'ACTI') or (sig = 'CONT') or (sig = 'DOOR')
	or (sig = 'LIGH') then
		Evaluate(e, m, 'SNAM', tag, debug);
	
	// Activators
	if (sig = 'ACTI') then
		Evaluate(e, m, 'VNAM', tag, debug);

	// Containers
	if (sig = 'CONT') then begin
		Evaluate(e, m, 'QNAM', tag, debug);
		if not IsFallout3(game) then
			Evaluate(e, m, 'RNAM', tag, debug); // fo3 doesn't have this element
	end;

	// Creatures
	if (sig = 'CREA') then begin
		Evaluate(e, m, 'WNAM', tag, debug);
		Evaluate(e, m, 'CSCR', tag, debug);
		Evaluate(e, m, 'Sound Types', tag, debug);
	end;

	// Doors
	if (sig = 'DOOR') then begin
		Evaluate(e, m, 'ANAM', tag, debug);
		Evaluate(e, m, 'BNAM', tag, debug);
	end;
	
	// Magic Effects
	if (sig = 'MGEF') then begin
		Evaluate(e, m, 'DATA\Effect sound', tag, debug);
		Evaluate(e, m, 'DATA\Bolt sound', tag, debug);
		Evaluate(e, m, 'DATA\Hit sound', tag, debug);
		Evaluate(e, m, 'DATA\Area sound', tag, debug);
	end;

	// Weather
	if (sig = 'WTHR') then
		Evaluate(e, m, 'Sounds', tag, debug);

end;

{==================================================================}
// Stats
function CheckStats(e, m: IInterface; debug: boolean): integer;
var
	d, dm: IInterface;
	sig: string;
begin
	tag := 'Stats';
	
	// get record signature
	sig := Signature(e);

	// Ingestibles, Ammunition, Armor, Books, Keys, Lights, Misc. Items, Weapons
	if (sig = 'ALCH')	or (sig = 'AMMO')	or (sig = 'ARMO')
	or (sig = 'BOOK')	or (sig = 'KEYM') or (sig = 'LIGH')
	or (sig = 'MISC')	or (sig = 'WEAP')	then
		Evaluate(e, m, 'DATA', tag, debug);

	// Ammunition
	if (sig = 'AMMO') then
		if not IsFallout3(game) then
			Evaluate(e, m, 'DAT2', tag, debug); // fo3 doesn't have this element

	// Armor
	if (sig = 'ARMO') then
		Evaluate(e, m, 'DNAM', tag, debug);
end;

{==================================================================}
{Main}
function Initialize: integer;
var
	tmplLoaded: string;
  caName: array [0..6] of string;
begin
	optionSelected := MessageDlg('Do you want to write any found tags to the file header?', mtConfirmation, [mbYes, mbNo, mbAbort], 0);
	if optionSelected = mrAbort then
		exit;
		
  // Conflict names and their background colors when viewed in xEdit

  // conflict status not initialized
  caName[caUnknown]          := 'Unknown';

  // only 1 elements in comparison, usually a master record without overrides (white)
  caName[caOnlyOne]          := 'OnlyOne';

  // same data, identical to master ITM (green)
  caName[caNoConflict]       := 'NoConflict';

  // data differs, but the changes don't affect the game so treated as ITM too (yellow)
  caName[caConflictBenign]   := 'ConflictBenign';

  // different data, basically what mods do (yellow)
  caName[caOverride]         := 'Override';

  // changed data is changed by later loading mods (red)
  caName[caConflict]         := 'Conflict';

  // changed critical game data is changed by later loading mods (fuchsia)
  caName[caConflictCritical] := 'ConflictCritical';
	
	// list of tags
	slTags := TStringList.Create;
	slTags.Delimiter := ','; // separated by comma

	// what game is loaded
	game := GetFileName(FileByLoadOrder(00));
	
	// reusable strings
	tmplLoaded := 'Using record structure for ';

	AddMessage(#13#10 + '-------------------------------------------------------------------------------');
	if IsFallout3(game) then AddMessage(tmplLoaded + 'Fallout 3');
	if IsFalloutNV(game) then AddMessage(tmplLoaded + 'Fallout: New Vegas');
	if IsOblivion(game) then AddMessage(tmplLoaded + 'The Elder Scrolls IV: Oblivion');
	if IsSkyrim(game) then AddMessage(tmplLoaded + 'The Elder Scrolls V: Skyrim');
	AddMessage('-------------------------------------------------------------------------------');
end;

{==================================================================}
{Process}
function Process(e: IInterface): integer;
var
	o: IInterface; // master record
	sig, fm: string;
	i: integer;
begin
	
	{Ignore file header records}
	if Signature(e) = 'TES4' then
		exit;
	
	{DEBUG}
	//AddMessage(SmallName(e));
	
	{get file and file name}
	fi := GetFile(e);
	fn := GetFileName(fi);
	
	{Exit if the user aborted, or the record is identical to master}
	if (optionSelected = mrAbort) then
		exit;
	
	{Exit if the conflict isn't worth the effort}
	if (ConflictAllForMainRecord(e) = caUnknown)
	or (ConflictAllForMainRecord(e) = caConflict)
	or (ConflictAllForMainRecord(e) = caConflictCritical) then
		exit;

	{get master record}
	o := Master(e);
	if not Assigned(o) then
		exit;
	
	{if record overrides several masters, then get the last one}
	if OverrideCount(o) > 1 then
		o := OverrideByIndex(o, OverrideCount(o) - 2);

	{v1.3.4 Stop processing deleted records to avoid errors}
	if GetIsDeleted(e) or GetIsDeleted(o) then
		exit;

	// get record signature
	sig := Signature(e);

	//---------------------------------------------------------------------------
	//Fallout 3
	//Fallout: New Vegas
	//Skyrim
	//---------------------------------------------------------------------------
	if IsFallout3(game) or IsFalloutNV(game) or IsSkyrim(game) then begin
		{Deactivate - NOT IMPLEMENTED}
		{Filter -- NOT IMPLEMENTED}
		{NoMerge -- NOT IMPLEMENTED}

		//Cell Record Type
		//---------------------------------------------------------------------------
		{C.Acoustic}
		if (sig = 'CELL') then
			Result := Evaluate(e, o, 'XCAS', 'C.Acoustic', false);
		{C.Climate}
		if (sig = 'CELL') then
			Result := CheckCellClimate(e, o, false);
		{C.Encounter}
		if (sig = 'CELL') then
			Result := Evaluate(e, o, 'XEZN', 'C.Encounter', false);
		{C.ImageSpace}
		if (sig = 'CELL') then
			Result := Evaluate(e, o, 'XCIM', 'C.ImageSpace', false);
		{C.Light}
		if (sig = 'CELL') then
			Result := Evaluate(e, o, 'XCLL', 'C.Light', false);
		{C.Music}
		if (sig = 'CELL') then
			Result := Evaluate(e, o, 'XCMO', 'C.Music', false); // 1.3.7 - was broken
		{C.Name}
		if (sig = 'CELL') then
			Result := Evaluate(e, o, 'FULL', 'C.Name', false); // 1.3.7 - was broken
		{C.Owner}
		if (sig = 'CELL') then
			Result := Evaluate(e, o, 'Ownership', 'C.Owner', false);
		{C.RecordFlags}
		if (sig = 'CELL') then
			Result := CheckCellRecordFlags(e, o, false);
		{C.Water}
		if (sig = 'CELL') then
			Result := CheckCellWater(e, o, false);

		//Leveled List Record Types
		//---------------------------------------------------------------------------
		{Delev/Relev}
		if (sig = 'LVLI') or (sig = 'LVLC') or (sig = 'LVLN') or (sig = 'LVSP') then
			Result := CheckDelevRelev(e, o, false);

		//Actor and Container Record Types
		//---------------------------------------------------------------------------
		{Invent}
		if (sig = 'CONT') then
			Result := CheckInvent(e, o, false);

		{Invent - special handling for CREA and NPC_ record types}
		if (sig = 'NPC_') or (sig = 'CREA') then begin
			// If the Use Inventory (0x256) template flag is set, skip record to handle inheritance
			if Assigned(GetElement(e, 'ACBS\Template Flags')) then
				if IsFlagSet(GetElement(e, 'ACBS\Template Flags'), 'Use Inventory') then
					exit;
			if Assigned(GetElement(o, 'ACBS\Template Flags')) then
				if IsFlagSet(GetElement(o, 'ACBS\Template Flags'), 'Use Inventory') then
					exit;
			Result := CheckInvent(e, o, false);
		end;

		//Various Record Types
		//---------------------------------------------------------------------------
		{Graphics}
		if (sig = 'ACTI') or (sig = 'ALCH') or (sig = 'AMMO')
		or (sig = 'BOOK') or (sig = 'CLAS') or (sig = 'DOOR')
		or (sig = 'FLOR') or (sig = 'FURN') or (sig = 'GRAS')
		or (sig = 'INGR') or (sig = 'KEYM') or (sig = 'LIGH')
		or (sig = 'LSCR') or (sig = 'LTEX') or (sig = 'MGEF')
		or (sig = 'MISC') or (sig = 'REGN') or (sig = 'STAT')
		or (sig = 'TREE') or (sig = 'WEAP') then
			Result := CheckGraphics(e, o, false);

		{Names}
		if (sig <> 'CELL') and (sig <> 'REFR') and (sig <> 'ACHR') and (sig <> 'NAVM') and (sig <> 'CREA') and (sig <> 'NPC_') then
			Result := Evaluate(e, o, 'FULL', 'Names', false);

		{Names - special handling for CREA and NPC_ record types}
		if (sig = 'CREA') or (sig = 'NPC_') then begin
			// If the Use Base Data (0x128) template flag is set, skip record to handle inheritance
			if Assigned(GetElement(e, 'ACBS\Template Flags')) then
				if IsFlagSet(GetElement(e, 'ACBS\Template Flags'), 'Use Base Data') then
					exit;
			if Assigned(GetElement(o, 'ACBS\Template Flags')) then
				if IsFlagSet(GetElement(o, 'ACBS\Template Flags'), 'Use Base Data') then
					exit;
			Result := Evaluate(e, o, 'FULL', 'Names', false);
		end;

		{Sound}
		if (sig = 'ACTI') or (sig = 'CONT') or (sig = 'DOOR')
		or (sig = 'LIGH') or (sig = 'MGEF') or (sig = 'WTHR') then
			Result := CheckSound(e, o, false);

		{Sound - special handling for CREA record type}
		if (sig = 'CREA') then begin
			// If the Use Model/Animation (0x64) template flag is set, skip record to handle inheritance
			if Assigned(GetElement(e, 'ACBS\Template Flags')) then
				if IsFlagSet(GetElement(e, 'ACBS\Template Flags'), 'Use Model/Animation') then
					exit;
			if Assigned(GetElement(o, 'ACBS\Template Flags')) then
				if IsFlagSet(GetElement(o, 'ACBS\Template Flags'), 'Use Model/Animation') then
					exit;
			Result := CheckSound(e, o, false);
		end;

		{Stats}
		if (sig = 'ALCH') or (sig = 'AMMO') or (sig = 'ARMO')
		or (sig = 'BOOK') or (sig = 'KEYM') or (sig = 'LIGH')
		or (sig = 'MISC') or (sig = 'WEAP') then
			Result := CheckStats(e, o, false);
	end;

	//---------------------------------------------------------------------------
	//Fallout 3
	//Fallout: New Vegas
	//---------------------------------------------------------------------------
	if IsFallout3(game) or IsFalloutNV(game) then begin
		{Deflst -- NOT IMPLEMENTED}

		//Actor Record Types
		//---------------------------------------------------------------------------
		{Actors.ACBS}
		if (sig = 'NPC_') or (sig = 'CREA') then begin
			// v1.3.3 flag checks are implemented in the function
			Result := CheckActorsACBS(e, o, false);
		end;

		{Actors.AIData}
		if (sig = 'NPC_') or (sig = 'CREA') then begin
			// If the Use AI Data (0x16) template flag is set, skip record to handle inheritance
			if Assigned(GetElement(e, 'ACBS\Template Flags')) then
				if IsFlagSet(GetElement(e, 'ACBS\Template Flags'), 'Use AI Data') then
					exit;
			if Assigned(GetElement(o, 'ACBS\Template Flags')) then
				if IsFlagSet(GetElement(o, 'ACBS\Template Flags'), 'Use AI Data') then
					exit;
			Result := CheckActorsAIData(e, o, false);
		end;

		{Actors.AIPackages}
		if (sig = 'NPC_') or (sig = 'CREA') then begin
			// If the Use AI Packages (0x32) template flag is set, skip record to handle inheritance
			if Assigned(GetElement(e, 'ACBS\Template Flags')) then
				if IsFlagSet(GetElement(e, 'ACBS\Template Flags'), 'Use AI Packages') then
					exit;
			if Assigned(GetElement(o, 'ACBS\Template Flags')) then
				if IsFlagSet(GetElement(o, 'ACBS\Template Flags'), 'Use AI Packages') then
					exit;
			Result := CheckActorsAIPackages(e, o, false);
		end;

		{Actors.Anims}
		if (sig = 'CREA') then begin
			// If the Use Model/Animation (0x64) template flag is set, skip record to handle inheritance
			if Assigned(GetElement(e, 'ACBS\Template Flags')) then
				if IsFlagSet(GetElement(e, 'ACBS\Template Flags'), 'Use Model/Animation') then
					exit;
			if Assigned(GetElement(o, 'ACBS\Template Flags')) then
				if IsFlagSet(GetElement(o, 'ACBS\Template Flags'), 'Use Model/Animation') then
					exit;
			Result := Evaluate(e, o, 'KFFZ', 'Actors.Anims', false);
		end;

		{Actors.CombatStyle}
		if (sig = 'NPC_') or (sig = 'CREA') then begin
			// If the Use Traits (0x1) template flag is set, skip record to handle inheritance
			if IsFlagSet(GetElement(e, 'ACBS\Template Flags'), 'Use Traits')
			or IsFlagSet(GetElement(o, 'ACBS\Template Flags'), 'Use Traits') then
				exit;
			Result := Evaluate(e, o, 'ZNAM', 'Actors.CombatStyle', false);
		end;

		{Actors.DeathItem}
		if (sig = 'NPC_') or (sig = 'CREA') then begin
			// If the Use Traits (0x1) template flag is set, skip record to handle inheritance
			if IsFlagSet(GetElement(e, 'ACBS\Template Flags'),'Use Traits')
			or IsFlagSet(GetElement(o, 'ACBS\Template Flags'), 'Use Traits') then
				exit;
			Result := Evaluate(e, o, 'INAM', 'Actors.DeathItem', false);
		end;

		{Actors.Skeleton}
		if (sig = 'NPC_') or (sig = 'CREA') then begin
			// If the Use Model/Animation (0x64) template flag is set, skip record to handle inheritance
			if Assigned(GetElement(e, 'ACBS\Template Flags')) then
				if IsFlagSet(GetElement(e, 'ACBS\Template Flags'), 'Use Model/Animation') then
					exit;
			if Assigned(GetElement(o, 'ACBS\Template Flags')) then
				if IsFlagSet(GetElement(o, 'ACBS\Template Flags'), 'Use Model/Animation') then
					exit;
			Result := CheckActorsSkeleton(e, o, false);
		end;

		{Actors.Stats}
		if (sig = 'NPC_') or (sig = 'CREA') then begin
			// If the Use Stats (0x2) template flag is set, skip record to handle inheritance
			if Assigned(GetElement(e, 'ACBS\Template Flags')) then
				if IsFlagSet(GetElement(e, 'ACBS\Template Flags'), 'Use Stats') then
					exit;
			if Assigned(GetElement(o, 'ACBS\Template Flags')) then
				if IsFlagSet(GetElement(o, 'ACBS\Template Flags'), 'Use Stats') then
					exit;
			Result := CheckActorsStats(e, o, false);
		end;

		{Factions}
		if (sig = 'NPC_') or (sig = 'CREA') then begin
			// If the Use Factions (0x4) template flag is set, skip record to handle inheritance
			if Assigned(GetElement(e, 'ACBS\Template Flags')) then
				if IsFlagSet(GetElement(e, 'ACBS\Template Flags'), 'Use Factions') then
					exit;
			if Assigned(GetElement(o, 'ACBS\Template Flags')) then
				if IsFlagSet(GetElement(o, 'ACBS\Template Flags'), 'Use Factions') then
					exit;
			Result := CheckActorsFactions(e, o, false);
		end;

		{NPC.Class}
		if (sig = 'NPC_') then begin
			// If the Use Traits (0x1) template flag is set, skip record to handle inheritance
			if Assigned(GetElement(e, 'ACBS\Template Flags')) then
				if IsFlagSet(GetElement(e, 'ACBS\Template Flags'), 'Use Traits') then
					exit;
			if Assigned(GetElement(o, 'ACBS\Template Flags')) then
				if IsFlagSet(GetElement(o, 'ACBS\Template Flags'), 'Use Traits') then
					exit;
			Result := Evaluate(e, o, 'CNAM', 'NPC.Class', false);
		end;

		{NPC.Race}
		if (sig = 'NPC_') then begin
			// If the Use Traits (0x1) template flag is set, skip record to handle inheritance
			if Assigned(GetElement(e, 'ACBS\Template Flags')) then
				if IsFlagSet(GetElement(e, 'ACBS\Template Flags'), 'Use Traits') then
					exit;
			if Assigned(GetElement(o, 'ACBS\Template Flags')) then
				if IsFlagSet(GetElement(o, 'ACBS\Template Flags'), 'Use Traits') then
					exit;
			Result := Evaluate(e, o, 'RNAM', 'NPC.Race', false);
		end;

		{NPCFaces}
		if (sig = 'NPC_') then begin
			// If the Use Model/Animation (0x64) template flag is set, skip record to handle inheritance
			if Assigned(GetElement(e, 'ACBS\Template Flags')) then
				if IsFlagSet(GetElement(e, 'ACBS\Template Flags'), 'Use Model/Animation') then
					exit;
			if Assigned(GetElement(o, 'ACBS\Template Flags')) then
				if IsFlagSet(GetElement(o, 'ACBS\Template Flags'), 'Use Model/Animation') then
					exit;
			Result := CheckNPCFaces(e, o, false);
		end;

		//Faction Record Type
		//---------------------------------------------------------------------------
		{Relations}
		if (sig = 'FACT') then
			Result := Evaluate(e, o, 'Relations', 'Relations', false);

		//Race Record Type
		//---------------------------------------------------------------------------
		{Body-F}
		if (sig = 'RACE') then
			Result := CheckRaceBody(e, o, 'Body-F', false);
		{Body-M}
		if (sig = 'RACE') then
			Result := CheckRaceBody(e, o, 'Body-M', false);
		{Body-Size-F}
		if (sig = 'RACE') then
			Result := CheckRaceBody(e, o, 'Body-Size-F', false);
		{Body-Size-M}
		if (sig = 'RACE') then
			Result := CheckRaceBody(e, o, 'Body-Size-M', false);
		{Eyes}
		if (sig = 'RACE') then
			Result := Evaluate(e, o, 'ENAM', 'Eyes', false);
		{Hair}
		if (sig = 'RACE') then
			Result := Evaluate(e, o, 'HNAM', 'Hair', false);
		{R.Description}
		if (sig = 'RACE') then
			Result := Evaluate(e, o, 'DESC', 'R.Description', false);
		{R.Ears}
		if (sig = 'RACE') then
			Result := CheckRaceHead(e, o, 'R.Ears', false);
		{R.Head}
		if (sig = 'RACE') then
			Result := CheckRaceHead(e, o, 'R.Head', false);
		{R.Mouth}
		if (sig = 'RACE') then
			Result := CheckRaceHead(e, o, 'R.Mouth', false);
		{R.Relations}
		if (sig = 'RACE') then
			Result := Evaluate(e, o, 'Relations', 'R.Relations', false);
		{R.Skills}
		if (sig = 'RACE') then
			Result := Evaluate(e, o, 'DATA\Skill Boosts', 'R.Skills', false);
		{R.Teeth}
		if (sig = 'RACE') then
			Result := CheckRaceHead(e, o, 'R.Teeth', false);
		{Voice-F}
		if (sig = 'RACE') then
			Result := Evaluate(e, o, 'VTCK\Voice #1 (Female)', 'Voice-F', false);
		{Voice-M}
		if (sig = 'RACE') then
			Result := Evaluate(e, o, 'VTCK\Voice #0 (Male)', 'Voice-M', false);

		//Spell (Actor Effect) Record Type
		//---------------------------------------------------------------------------
		{SpellStats}
		if (sig = 'SPEL') then
			Result := CheckSpellStats(e, o, false);

		//Various Record Types
		//---------------------------------------------------------------------------
		{Destructible}
		if (sig = 'ACTI') or (sig = 'ALCH') or (sig = 'AMMO')
		or (sig = 'BOOK') or (sig = 'CONT') or (sig = 'DOOR')
		or (sig = 'FURN') or (sig = 'IMOD') or (sig = 'KEYM')
		or (sig = 'MISC') or (sig = 'MSTT') or (sig = 'PROJ')
		or (sig = 'TACT') or (sig = 'TERM') or (sig = 'WEAP') then
			Result := CheckDestructible(e, o, false);

		{Destructible - special handling for CREA and NPC_ record types}
		if (sig = 'CREA') or (sig = 'NPC_') then begin
			// If the Use Model/Animation (0x64) template flag is set, skip record to handle inheritance
			if Assigned(GetElement(e, 'ACBS\Template Flags')) then
				if IsFlagSet(GetElement(e, 'ACBS\Template Flags'), 'Use Model/Animation') then
					exit;
			if Assigned(GetElement(o, 'ACBS\Template Flags')) then
				if IsFlagSet(GetElement(o, 'ACBS\Template Flags'), 'Use Model/Animation') then
					exit;
			Result := CheckDestructible(e, o, false);
		end;

		{Scripts}
		if (sig = 'ACTI') or (sig = 'ALCH') or (sig = 'ARMO')
		or (sig = 'CONT') or (sig = 'DOOR') or (sig = 'FLOR')
		or (sig = 'FURN') or (sig = 'INGR') or (sig = 'KEYM')
		or (sig = 'LIGH') or (sig = 'LVLC') or (sig = 'MISC')
		or (sig = 'QUST') or (sig = 'WEAP') then
			Result := Evaluate(e, o, 'SCRI', 'Scripts', false);

		{Scripts - special handling for CREA and NPC_ record types}
		if (sig = 'CREA') or (sig = 'NPC_') then begin
			// If the Use Script (0x512) template flag is set, skip record to handle inheritance
			if Assigned(GetElement(e, 'ACBS\Template Flags')) then
				if IsFlagSet(GetElement(e, 'ACBS\Template Flags'), 'Use Script') then
					exit;
			if Assigned(GetElement(o, 'ACBS\Template Flags')) then
				if IsFlagSet(GetElement(o, 'ACBS\Template Flags'), 'Use Script') then
					exit;
			Result := Evaluate(e, o, 'SCRI', 'Scripts', false);
		end;

	end;

	//---------------------------------------------------------------------------
	//Fallout: New Vegas
	//---------------------------------------------------------------------------
	if IsFalloutNV(game) then begin
		//Weapon Record Type
		//---------------------------------------------------------------------------
		{WeaponMods}
		if (sig = 'WEAP') then
			Result := Evaluate(e, o, 'Weapon Mods', 'WeaponMods', false);
	end;

	//---------------------------------------------------------------------------
	//Skyrim
	//---------------------------------------------------------------------------
	if IsSkyrim(game) then begin
		{C.Location}
		if (sig = 'CELL') then
			Result := Evaluate(e, o, 'XLCN', 'C.Location', false);
	end;
	
end;

function Finalize: integer;
var
	hdr, desc: IInterface;
begin
	if (optionSelected = mrAbort) or (not Assigned(slTags)) or (not Assigned(fn)) then
		exit;

	slTags.Sort;

	AddMessage(#13#10 + fn + ':');

	if slTags.Count > 0 then begin
		
		if optionSelected = 6 then begin
			AddMessage('Added tags to file header: ' + #13#10 + Format('{{BASH:%s}}', [slTags.DelimitedText]));
			hdr := GetElement(fi, 'TES4');
			if Assigned(hdr) then begin
				desc := GetElement(hdr, 'SNAM');
				if not Assigned(desc) then
					desc := Add(hdr, 'SNAM', false);
				SetEditValue(desc, Format('{{BASH:%s}}', [slTags.DelimitedText]));
			end;
		end
		else if optionSelected = 7 then
			AddMessage('Suggested tags: ' + #13#10 + Format('{{BASH:%s}}', [slTags.DelimitedText]));
	
	end;

	if slTags.Count = 0 then begin
		AddMessage('No tags suggested');
		
		desc := GetElement(GetElement(fi, 'TES4'), 'SNAM');
		if (optionSelected = 6) and Assigned(desc) then
			Remove(desc);
	end;

	AddMessage(#13#10 + '-------------------------------------------------------------------------------' + #13#10);

	slTags.Free;
end;

end.