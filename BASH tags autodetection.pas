{
	Purpose: Bash Tagger
	Game: FO3/FNV/TESV
	Author: fireundubh <fireundubh@gmail.com>
	Version: 1.3.9.1 (based on "BASH tags autodetection.pas" v1.0)

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
	f: IwbFile;
	slTags: TStringList;
	fn, tag, game: string;
	optionSelected: integer;

// ******************************************************************
// FUNCTIONS
// ******************************************************************

// ==================================================================
// Returns True if the flags set are different and False if not
function CompareFlags(x, y: IInterface; f: string): boolean;
begin
	Result := (HasFlag(x, f) <> HasFlag(y, f));
end;

// ==================================================================
// Returns True if the flags set are different and False if not
function CompareFlagsEx(x, y: IInterface; p, f: string): boolean;
begin
	Result := (HasFlag(GetElement(x, p), f) <> HasFlag(GetElement(y, p), f));
end;

// ==================================================================
// Returns True if the any two flags are set and False if not
function CompareFlagsOr(x, y: IInterface; p, f: string): boolean;
begin
	Result := (HasFlag(GetElement(x, p), f) or HasFlag(GetElement(y, p), f));
end;

// ==================================================================
// Returns True if the edit values are different and False if not
function CompareEditValues(x, y: IInterface; s: string): boolean;
begin
	Result := (GetEditValue(GetElement(x, s)) <> GetEditValue(GetElement(y, s)));
end;

// ==================================================================
// Returns True if the native values are different and False if not
function CompareNativeValues(x, y: IInterface; s: string): boolean;
begin
	Result := (GetNativeValue(GetElement(x, s)) <> GetNativeValue(GetElement(y, s)));
end;

// ==================================================================
// Universal ElementBy
function GetElement(x: IInterface; s: string): IInterface;
begin
	if (pos('[', s) > 0) then
		Result := ElementByIP(x, s)
	else if (pos('\', s) > 0) then
		Result := ElementByPath(x, s)
	else if IsUppercase(s) then
		Result := ElementBySignature(x, s)
	else
		Result := ElementByName(x, s);
end;

// ==================================================================
// Get element from list by some value
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

// ==================================================================
// Return True if specific flag is set and False if not
function HasFlag(f: IInterface; s: string): boolean;
var
	flags: TStringList;
	i: integer;
begin
	flags := TStringList.Create;
	flags.DelimitedText := lowercase('"Use Traits=1", "Use Stats=2", "Use Factions=4", "Use Actor Effect List=8", "Use AI Data=16", "Use AI Packages=32", "Use Model/Animation=64", "Use Base Data=128", "Use Inventory=256", "Use Script=512", "Is Interior Cell=1", "Has Water=2", "Behave Like Exterior=128", "ESM=1", "Deleted=32", "Border Region=64", "Turn Off Fire=128", "Casts Shadows=512", "Quest Item=1024", "Persistent Reference=1024", "Initially Disabled=2048", "Ignored=4096", "VWD=32768", "Visible When Distant=32768", "Dangerous=131072", "Compressed=262144", "Cant Wait=524288"');
	i := StrToInt(lowercase(flags.Values[s]));
	flags.Free;
	Result := (GetNativeValue(f) and i > 0);
end;

// ==================================================================
// Returns True if the x signature is in the y list of signatures
function InSignatureList(x, y: string): boolean;
var
	signatures: TStringList;
	i: integer;
begin
	signatures := TStringList.Create;
	signatures.DelimitedText := y;
	i := signatures.IndexOf(x);
	signatures.Free;
	Result := (i > -1);
end;

// ==================================================================
// Return true if the loaded game is Fallout 3
function IsFallout3(game: string): boolean;
begin
	Result := (game = 'Fallout3.esm');
end;

// ==================================================================
// Return true if the loaded game is Fallout: New Vegas
function IsFalloutNV(const game: string): boolean;
begin
	Result := (game = 'FalloutNV.esm');
end;

// ==================================================================
// Return true if the loaded game is TES4: Oblivion
function IsOblivion(const game: string): boolean;
begin
	Result := (game = 'Oblivion.esm');
end;

// ==================================================================
// Return true if the loaded game is TES4: Skyrim
function IsSkyrim(const game: string): boolean;
begin
	Result := (game = 'Skyrim.esm');
end;

// ==================================================================
// Returns True if the string is uppercase and False if not
function IsUppercase(x: string): boolean;
begin
	Result := (x = Uppercase(x));
end;

// ==================================================================
// Check if the tag already exists
function TagExists(t: string): boolean;
begin
	Result := (slTags.IndexOf(t) <> -1);
end;

// ******************************************************************
// PROCEDURES
// ******************************************************************

// ==================================================================
// Add the tag if the tag does not exist
procedure AddTag(t: string);
begin
	if not TagExists(t) then begin
		slTags.Add(t);
		exit;
	end;
end;

// ==================================================================
// Evaluate
// Determines whether two elements are different and suggests tags
// Not to be used when you need to know how two elements differ
procedure Evaluate(x, y: IInterface; tag: string; debug: boolean);
var
	i, j, k, l, m: integer;
begin
	// Exit if the tag already exists
	if TagExists(tag) then
		exit;

	// Suggest tag if one element exists while the other does not
	if Assigned(x) <> Assigned(y) then begin
		if debug then begin
			AddMessage('[Assigned] ' + tag + ':' + FullPath(x));
			AddMessage('[Assigned] ' + tag + ':' + FullPath(y));
		end;
		AddTag(tag);
	end;

	// exit if the first element does not exist
	if not Assigned(x) then
		exit;

	// Suggest tag if the two elements are different
	if ElementCount(x) <> ElementCount(y) then begin
		if debug then begin
			AddMessage('[ElementCount] ' + tag + ':' + FullPath(x));
			AddMessage('[ElementCount] ' + tag + ':' + FullPath(y));
		end;
		AddTag(tag);
	end;

	// suggest tag if the edit values of the two elements are different
	if GetEditValue(x) <> GetEditValue(y) then begin
		if debug then begin
			AddMessage('[GetEditValue] ' + tag + ':' + FullPath(x));
			AddMessage('[GetEditValue] ' + tag + ':' + FullPath(y));
		end;
		AddTag(tag);
	end;

	// compare any number of elements with SortKeys
	if SortKey(x, true) <> SortKey(y, true) then begin
		if debug then begin
			AddMessage('[SortKey] ' + tag + ':' + FullPath(x));
			AddMessage('[SortKey] ' + tag + ':' + FullPath(y));
		end;
		AddTag(tag);
	end;
end;

// ==================================================================
// EvaluateEx
// Improved Evaluate with GetElement
procedure EvaluateEx(x, y: IInterface; z: string; tag: string; debug: boolean);
begin
	Evaluate(GetElement(x, z), GetElement(y, z), tag, debug);
end;

// ==================================================================
// v1.3.3 - Actors.ACBS
procedure CheckActorsACBS(e, m: IInterface; debug: boolean);
var
	f, fm: IInterface;
begin
	tag := 'Actors.ACBS';
	if TagExists(tag) then
		exit;

	// get ACBS element
	f := GetElement(e, 'ACBS');
	fm := GetElement(m, 'ACBS');

	// If the Use Base Data flag is not set, then check Flags
	if not CompareFlagsOr(f, fm, 'Template Flags', 'Use Base Data') then begin
		if CompareNativeValues(f, fm, 'Flags') then begin
			if debug then PrintDebugS(f, fm, 'Flags', tag);
			AddTag(tag);
		end;
	end;

	// Validators
	EvaluateEx(f, fm, 'Fatigue', tag, debug);
	EvaluateEx(f, fm, 'Level', tag, debug);
	EvaluateEx(f, fm, 'Calc min', tag, debug);
	EvaluateEx(f, fm, 'Calc max', tag, debug);
	EvaluateEx(f, fm, 'Speed Multiplier', tag, debug);
	EvaluateEx(e, m, 'DATA\Base Health', tag, debug);

	// If the Use AI Data (0x16) template is not set, validate ACBS\Barter gold
	if not CompareFlagsOr(f, fm, 'Template Flags', 'Use AI Data') then
		EvaluateEx(f, fm, 'Barter gold', tag, debug);
end;

// ==================================================================
// Actors.AIData
procedure CheckActorsAIData(e, m: IInterface; debug: boolean);
var
	a, am: IInterface;
begin
	tag := 'Actors.AIData';
	if TagExists(tag) then
		exit;

	// get ACBS element
	a := GetElement(e, 'AIDT');
	am := GetElement(m, 'AIDT');

	// Validators
	EvaluateEx(a, am, 'Aggression', tag, debug);
	EvaluateEx(a, am, 'Confidence', tag, debug);
	EvaluateEx(a, am, 'Energy level', tag, debug);
	EvaluateEx(a, am, 'Responsibility', tag, debug);

	// v1.3.3 - More flags
	if CompareNativeValues(a, am, 'Buys/Sells and Services') then begin
		if debug then PrintDebugS(a, am, 'Buys/Sells and Services', tag);
		AddTag(tag);
	end;

	EvaluateEx(a, am, 'Teaches', tag, debug);
	EvaluateEx(a, am, 'Maximum training level', tag, debug);
end;

// ==================================================================
// Actors.AIPackages
procedure CheckActorsAIPackages(e, m: IInterface; debug: boolean);
begin
	tag := 'Actors.AIPackages';
	if TagExists(tag) then
		exit;
	EvaluateEx(e, m, 'Packages', tag, debug);
end;

// ==================================================================
// Factions
procedure CheckActorsFactions(e, m: IInterface; debug: boolean);
var
	f, fm: IInterface;
begin
	tag := 'Factions';
	if TagExists(tag) then
		exit;

	f := GetElement(e, 'Factions');
	fm := GetElement(m, 'Factions');

	if Assigned(f) <> Assigned(fm) then begin
		if debug then PrintDebugE(e, m, tag);
		AddTag(tag);
	end;

	if not Assigned(f) then
		exit;

	if SortKey(f, true) <> SortKey(fm, true) then begin
		if debug then PrintDebugE(f, fm, tag);
		AddTag(tag);
	end;
end;

// ==================================================================
// Actors.Skeleton
procedure CheckActorsSkeleton(e, m: IInterface; debug: boolean);
var
	x, y: IInterface;
begin
	tag := 'Actors.Skeleton';
	if TagExists(tag) then
		exit;

	// get model objects
	x := GetElement(e, 'Model');
	y := GetElement(m, 'Model');

	// A fix that might cause problems... We'll see!
	if not Assigned(x) then
		exit;

	EvaluateEx(x, y, 'MODL', tag, debug);
	EvaluateEx(x, y, 'MODB', tag, debug);
	EvaluateEx(x, y, 'MODT', tag, debug);
end;

// ==================================================================
// Actors.Stats
procedure CheckActorsStats(e, m: IInterface; debug: boolean);
var
	d, dm: IInterface;
	sig: string;
begin
	tag := 'Actors.Stats';
	if TagExists(tag) then
		exit;

	// get record signature
	sig := Signature(e);

	// get data objects
	d := GetElement(e, 'DATA');
	dm := GetElement(m, 'DATA');

	// validators
	// creatures
	if (sig = 'CREA') then begin
		EvaluateEx(d, dm, 'Health', tag, debug);
		EvaluateEx(d, dm, 'Combat Skill', tag, debug);
		EvaluateEx(d, dm, 'Magic Skill', tag, debug);
		EvaluateEx(d, dm, 'Stealth Skill', tag, debug);
		EvaluateEx(d, dm, 'Attributes', tag, debug);
	end;

	// non-player characters
	if (sig = 'NPC_') then begin
		EvaluateEx(d, dm, 'Base Health', tag, debug);
		EvaluateEx(d, dm, 'Attributes', tag, debug);
		EvaluateEx(e, m, 'DNAM\Skill Values', tag, debug);
		EvaluateEx(e, m, 'DNAM\Skill Offsets', tag, debug);
	end;
end;

// ==================================================================
// C.Climate
procedure CheckCellClimate(e, m: IInterface; debug: boolean);
var
	d, dm: IInterface;
begin
	tag := 'C.Climate';
	if TagExists(tag) then
		exit;

	// If the Behave like exterior (0x128) flag is set in one record but not in the other, suggest tag
	if CompareFlagsEx(e, m, 'DATA', 'Behave Like Exterior') then begin
		if debug then PrintDebugS(e, m, 'DATA', tag);
		AddTag(tag);
	end;

	EvaluateEx(e, m , 'XCCM', tag, debug);
end;


// ==================================================================
// C.RecordFlags
procedure CheckCellRecordFlags(e, m: IInterface; debug: boolean);
var
	f, fm: IInterface;
begin
	tag := 'C.RecordFlags';
	if TagExists(tag) then
		exit;

	f  := GetElement(e, 'Record Header\Record Flags');
	fm := GetElement(m, 'Record Header\Record Flags');

	if CompareFlags(f, fm, 'ESM')
	or CompareFlags(f, fm, 'Deleted')
	or CompareFlags(f, fm, 'Border Region')
	or CompareFlags(f, fm, 'Turn Off Fire')
	or CompareFlags(f, fm, 'Casts Shadows')
	or CompareFlags(f, fm, 'Persistent Reference')
	or CompareFlags(f, fm, 'Initially Disabled')
	or CompareFlags(f, fm, 'Ignored')
	or CompareFlags(f, fm, 'Visible When Distant')
	or CompareFlags(f, fm, 'Dangerous')
	or CompareFlags(f, fm, 'Compressed')
	or CompareFlags(f, fm, 'Cant Wait') then
		AddTag(tag);
end;

// ==================================================================
// C.Water
procedure CheckCellWater(e, m: IInterface; debug: boolean);
var
	d, dm: IInterface;
begin
	tag := 'C.Water';
	if TagExists(tag) then
		exit;

	// If the Has water (0x2) flag is set in one record but not in the other, suggest tag and exit
	if CompareFlagsEx(e, m, 'DATA', 'Has Water') then begin
		if debug then PrintDebugS(e, m, 'DATA', tag);
		AddTag(tag);
	end;
	
	if CompareFlagsOr(e, m, 'DATA', 'Is Interior Cell') then
		exit;

	EvaluateEx(e, m, 'XCLW', tag, debug);
	EvaluateEx(e, m, 'XCWT', tag, debug);
end;

// ==================================================================
// Delev, Relev (written by the xEdit team)
procedure CheckDelevRelev(e, m: IInterface; debug: boolean);
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
	if not Assigned(entries)
	or not Assigned(entriesmaster) then
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
			if Assigned(coed) then
				s1 := SortKey(coed, True) else s1 := '';
			if Assigned(coedm) then
				s2 := SortKey(coedm, True) else s2 := '';
			
			if CompareNativeValues(ent, entm, 'LVLO\Level')
			or CompareNativeValues(ent, entm, 'LVLO\Count')
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

// ==================================================================
// Destructible
procedure CheckDestructible(e, m: IInterface; debug: boolean);
var
	d, dm: IInterface;
begin
	tag := 'Destructible';
	if TagExists(tag) then
		exit;

	d := ElementByName(e, 'Destructable');
	dm := ElementByName(m, 'Destructable');

	if Assigned(d) <> Assigned(dm) then
		AddTag(tag);

	EvaluateEx(d, dm, 'DEST\Health', tag, debug);
	EvaluateEx(d, dm, 'DEST\Count', tag, debug);

	if CompareNativeValues(d, dm, 'DEST\Flags') then begin
		if debug then PrintDebugS(d, dm, 'DEST\Flags', tag);
		AddTag(tag);
	end;

	EvaluateEx(d, dm, 'Stages', tag, debug);
end;

// ==================================================================
// Graphics
procedure CheckGraphics(e, m: IInterface; debug: boolean);
var
	icon, iconm, modl, modlm: IInterface;
	sig: string;
	i: integer;
begin
	tag := 'Graphics';
	if TagExists(tag) then
		exit;
	
	sig := Signature(e);

	if InSignatureList(sig, 'ALCH, AMMO, BOOK, CLAS, INGR, KEYM, LIGH, LSCR, LTEX, MGEF, MISC, REGN, TREE, WEAP') then
		EvaluateEx(e, m, 'Icon', tag, debug);

	if InSignatureList(sig, 'ACTI, ALCH, AMMO, BOOK, DOOR, FLOR, FURN, GRAS, INGR, KEYM, LIGH, MGEF, MISC, STAT, TREE, WEAP') then
		EvaluateEx(e, m, 'Model', tag, debug);

	if (sig = 'ARMO') then begin
		EvaluateEx(e, m, 'ICON', tag, debug);
		EvaluateEx(e, m, 'ICO2', tag, debug);
		EvaluateEx(e, m, 'Male biped model\MODL', tag, debug);
		EvaluateEx(e, m, 'Male biped model\MODT', tag, debug);
		EvaluateEx(e, m, 'Male world model\MOD2', tag, debug);
		EvaluateEx(e, m, 'Female biped model\MOD3', tag, debug);
		EvaluateEx(e, m, 'Female biped model\MO3T', tag, debug);
		EvaluateEx(e, m, 'Female world model\MOD4', tag, debug);
		if CompareNativeValues(e, m, 'BMDT\Biped Flags') then
			if debug then PrintDebugS(e, m, 'BMDT\Biped Flags', tag);
			AddTag(tag);
	end;

	if (sig ='CREA') then begin
		EvaluateEx(e, m, 'NIFZ', tag, debug);
		EvaluateEx(e, m, 'NIFT', tag, debug);
	end;

	// 1.2 improved efsh validation
	if (sig = 'EFSH') then begin
		if CompareNativeValues(e, m, 'Record Header\Record Flags') then begin
			if debug then PrintDebugS(e, m, 'Record Header\Record Flags', tag);
			AddTag(tag);
		end;
		EvaluateEx(e, m, 'ICON', tag, debug);
		EvaluateEx(e, m, 'ICO2', tag, debug);
		EvaluateEx(e, m, 'NAM7', tag, debug);
		if IsSkyrim(game) then begin
			EvaluateEx(e, m, 'NAM8', tag, debug);
			EvaluateEx(e, m, 'NAM9', tag, debug);
		end;
		EvaluateEx(e, m, 'DATA', tag, debug);
	end;

	// 1.3.8 - added static material
	if (sig = 'STAT') then
		EvaluateEx(e, m, 'DNAM\Material', tag, debug)

end;

// ==================================================================
// Invent (written by the xEdit team)
procedure CheckInvent(e, m: IInterface; debug: boolean);
var
	items, itemsmaster: IInterface;
begin
	tag := 'Invent';
	if TagExists(tag) then
		exit;

	items := GetElement(e, 'Items');
	itemsmaster := GetElement(m, 'Items');

	if Assigned(items) <> Assigned(itemsmaster) then begin
		if debug then PrintDebugE(e, m, tag);
		AddTag(tag);
	end;

	if not Assigned(items) then
		exit;

	// Items are sorted, so we don't need to compare by individual item
	// SortKey combines all the items data
	if SortKey(items, True) <> SortKey(itemsmaster, True) then begin
		if debug then PrintDebugE(items, itemsmaster, tag);
		AddTag(tag);
	end;
end;

// ==================================================================
// NpcFaces
procedure CheckNPCFaces(e, m: IInterface; debug: boolean);
begin
	tag := 'NpcFaces';
	if TagExists(tag) then
		exit;
	EvaluateEx(e, m, 'HNAM', tag, debug);
	EvaluateEx(e, m, 'LNAM', tag, debug);
	EvaluateEx(e, m, 'ENAM', tag, debug);
	EvaluateEx(e, m, 'HCLR', tag, debug);
	EvaluateEx(e, m, 'FaceGen Data', tag, debug);
end;

// ==================================================================
// Body-F
// Body-M
// Body-Size-F
// Body-Size-M
procedure CheckRaceBody(e, m: IInterface; tag: string; debug: boolean);
begin
	if TagExists(tag) then
		exit;
	if (tag = 'Body-F') then		
		EvaluateEx(e, m, 'Body Data\Female Body Data\Parts', tag, debug);
	if (tag = 'Body-M') then
		EvaluateEx(e, m, 'Body Data\Male Body Data\Parts', tag, debug);
	if (tag = 'Body-Size-F') then begin
		EvaluateEx(e, m, 'DATA\Female Height', tag, debug);
		EvaluateEx(e, m, 'DATA\Female Weight', tag, debug);
	end;
	if (tag = 'Body-Size-M') then begin
		EvaluateEx(e, m, 'DATA\Male Height', tag, debug);
		EvaluateEx(e, m, 'DATA\Male Weight', tag, debug);
	end;
end;

// ==================================================================
// R.Ears
// R.Head (disabled due to Wrye Flash NV bug)
// R.Mouth
// R.Teeth
procedure CheckRaceHead(e, m: IInterface; tag: string; debug: boolean);
begin
	if TagExists(tag) then
		exit;
	if (tag = 'R.Head') then begin
		EvaluateEx(e, m, 'Head Data\Male Head Data\Parts\[0]', tag, debug);
		EvaluateEx(e, m, 'Head Data\Female Head Data\Parts\[0]', tag, debug);
		EvaluateEx(e, m, 'FaceGen Data', tag, debug);
	end;
	if (tag = 'R.Ears') then begin
		EvaluateEx(e, m, 'Head Data\Male Head Data\Parts\[1]', tag, debug);
		EvaluateEx(e, m, 'Head Data\Female Head Data\Parts\[1]', tag, debug);
	end;
	if (tag = 'R.Mouth') then begin
		EvaluateEx(e, m, 'Head Data\Male Head Data\Parts\[2]', tag, debug);
		EvaluateEx(e, m, 'Head Data\Female Head Data\Parts\[2]', tag, debug);
	end;
	if (tag = 'R.Teeth') then begin
		EvaluateEx(e, m, 'Head Data\Male Head Data\Parts\[3]', tag, debug);
		EvaluateEx(e, m, 'Head Data\Female Head Data\Parts\[3]', tag, debug);
		if IsFallout3(game) then begin
			EvaluateEx(e, m, 'Head Data\Male Head Data\Parts\[4]', tag, debug);
			EvaluateEx(e, m, 'Head Data\Female Head Data\Parts\[4]', tag, debug);
		end;
	end;
end;

// ==================================================================
// Sound
procedure CheckSound(e, m: IInterface; debug: boolean);
var
	sig: string;
begin
	tag := 'Sound';
	if TagExists(tag) then
			exit;
	
	sig := Signature(e);

	// Activators, Containers, Doors, and Lights
	if InSignatureList(sig, 'ACTI, CONT, DOOR, LIGH') then
		EvaluateEx(e, m, 'SNAM', tag, debug);

	// Activators
	if (sig = 'ACTI') then
		EvaluateEx(e, m, 'VNAM', tag, debug);

	// Containers
	if (sig = 'CONT') then begin
		EvaluateEx(e, m, 'QNAM', tag, debug);
		if not IsFallout3(game) then
			EvaluateEx(e, m, 'RNAM', tag, debug); // fo3 doesn't have this element
	end;

	// Creatures
	if (sig = 'CREA') then begin
		EvaluateEx(e, m, 'WNAM', tag, debug);
		EvaluateEx(e, m, 'CSCR', tag, debug);
		EvaluateEx(e, m, 'Sound Types', tag, debug);
	end;

	// Doors
	if (sig = 'DOOR') then begin
		EvaluateEx(e, m, 'ANAM', tag, debug);
		EvaluateEx(e, m, 'BNAM', tag, debug);
	end;

	// Magic Effects
	if (sig = 'MGEF') then begin
		EvaluateEx(e, m, 'DATA\Effect sound', tag, debug);
		EvaluateEx(e, m, 'DATA\Bolt sound', tag, debug);
		EvaluateEx(e, m, 'DATA\Hit sound', tag, debug);
		EvaluateEx(e, m, 'DATA\Area sound', tag, debug);
	end;

	// Weather
	if (sig = 'WTHR') then
		EvaluateEx(e, m, 'Sounds', tag, debug);
end;

// ==================================================================
// SpellStats
procedure CheckSpellStats(e, m: IInterface; debug: boolean);
begin
	tag := 'SpellStats';
	if TagExists(tag) then
			exit;
	EvaluateEx(e, m, 'FULL', tag, debug);
	EvaluateEx(e, m, 'SPIT', tag, debug);
end;

// ==================================================================
// Stats
procedure CheckStats(e, m: IInterface; debug: boolean);
var
	d, dm: IInterface;
	sig: string;
begin
	tag := 'Stats';
	if TagExists(tag) then
			exit;

	// get record signature
	sig := Signature(e);

	// Ingestibles, Ammunition, Armor, Books, Keys, Lights, Misc. Items, Weapons
	if InSignatureList(sig, 'ALCH, AMMO, ARMO, BOOK, KEYM, LIGH, MISC, WEAP') then
		EvaluateEx(e, m, 'DATA', tag, debug);

	// Ammunition
	if (sig = 'AMMO') then
		if not IsFallout3(game) then
			EvaluateEx(e, m, 'DAT2', tag, debug); // fo3 doesn't have this element

	// Armor
	if (sig = 'ARMO') then
		EvaluateEx(e, m, 'DNAM', tag, debug);
end;

// ==================================================================
// Debug Message
procedure PrintDebugE(x, y: IInterface; t: string);
begin
	AddMessage(t + ': ' + FullPath(x));
	AddMessage(t + ': ' + FullPath(y));
end;

// ==================================================================
// Debug Message
procedure PrintDebugS(x, y: IInterface; p, t: string);
begin
	AddMessage(t + ': ' + FullPath(GetElement(x, p)));
	AddMessage(t + ': ' + FullPath(GetElement(y, p)));
end;


// ******************************************************************
// PROCESSOR
// ******************************************************************

// ==================================================================
// Main
function Initialize: integer;
var
	tmplLoaded: string;
begin
	// prompt to write tags to file header
	optionSelected := MessageDlg('Do you want to write any found tags to the file header?', mtConfirmation, [mbYes, mbNo, mbAbort], 0);
	if optionSelected = mrAbort then
		exit;

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

// ==================================================================
// Process
function Process(e: IInterface): integer;
var
	o: IInterface; // master record
	sig, fm: string;
	i: integer;
begin

	// exit conditions
	if (optionSelected = mrAbort)								// user aborted
	or (Signature(e) = 'TES4')									// record is the file header
	or (ConflictAllString(e) = 'caUnknown')			// unknown conflict status
	or (ConflictAllString(e) = 'caOnlyOne')			// record neither conflicts nor overrides
	or (ConflictAllString(e) = 'caNoConflict')	// no conflict
	then exit;

	// get file and file name
	f := GetFile(e);
	fn := GetFileName(f);

	// get master record
	o := Master(e);
	if not Assigned(o) then
		exit;

	// if record overrides several masters, then get the last one
	if OverrideCount(o) > 1 then
		o := OverrideByIndex(o, OverrideCount(o) - 2);

	// v1.3.4 - Stop processing deleted records to avoid errors
	if GetIsDeleted(e) or GetIsDeleted(o) then
		exit;

	// get record signature
	sig := Signature(e);


	// Fallout 3, Fallout: New Vegas, Skyrim
	// ---------------------------------------------------------------------------
	if IsFallout3(game) or IsFalloutNV(game) or IsSkyrim(game) then begin

		// Cell Record Type

		if (sig = 'CELL') then begin
			EvaluateEx(e, o, 'XCAS', 'C.Acoustic', false);		// C.Acoustic
			CheckCellClimate(e, o, false);										// C.Climate
			EvaluateEx(e, o, 'XEZN', 'C.Encounter', false);		// C.Encounter
			EvaluateEx(e, o, 'XCIM', 'C.ImageSpace', false);	// C.ImageSpace
			EvaluateEx(e, o, 'XCLL', 'C.Light', false);				// C.Light
			EvaluateEx(e, o, 'XCMO', 'C.Music', false);				// C.Music
			EvaluateEx(e, o, 'FULL', 'C.Name', false);				// C.Name
			EvaluateEx(e, o, 'Ownership', 'C.Owner', false);	// C.Owner
			CheckCellRecordFlags(e, o, false);								// C.RecordFlags
			CheckCellWater(e, o, false);											// C.Water
			if IsSkyrim(game) then
				EvaluateEx(e, o, 'XLCN', 'C.Location', false);	// C.Location
		end;

		// Leveled List Record Types

		if InSignatureList(sig, 'LVLC, LVLI, LVLN, LVSP') then
			CheckDelevRelev(e, o, false);

		// Actor and Container Record Types

		if (sig = 'CONT') then
			CheckInvent(e, o, false);

		if InSignatureList(sig, 'CREA, NPC_') then begin
			if not CompareFlagsOr(e, o, 'ACBS\Template Flags', 'Use Inventory') then
				CheckInvent(e, o, false);									// Invent - special handling for CREA and NPC_ record types

			if not CompareFlagsOr(e, o, 'ACBS\Template Flags', 'Use Base Data') then
				EvaluateEx(e, o, 'FULL', 'Names', false);	// Names - special handling for CREA and NPC_ record types

			if (sig = 'CREA') then
				if not CompareFlagsOr(e, o, 'ACBS\Template Flags', 'Use Model/Animation') then
					CheckSound(e, o, false);								// Sound - special handling for CREA record type
		end;

		// Various Record Types

		if InSignatureList(sig, 'ACTI, ALCH, AMMO, BOOK, CLAS, DOOR, FLOR, FURN, GRAS, INGR, KEYM, LIGH, LSCR, LTEX, MGEF, MISC, REGN, STAT, TREE, WEAP') then
			CheckGraphics(e, o, false);

		if InSignatureList(sig, 'ACHR, CELL, CREA, NAVM, NPC_, REFR') then
			EvaluateEx(e, o, 'FULL', 'Names', false);

		if InSignatureList(sig, 'ACTI, CONT, DOOR, LIGH, MGEF, WTHR') then
			CheckSound(e, o, false);

		if InSignatureList(sig, 'ALCH, AMMO, ARMO, BOOK, KEYM, LIGH, MISC, WEAP') then
			CheckStats(e, o, false);
	end;


	// Fallout 3, Fallout: New Vegas
	// ---------------------------------------------------------------------------
	if IsFallout3(game) or IsFalloutNV(game) then begin

		// Actor Record Types

		if InSignatureList(sig, 'CREA, NPC_') then begin
			if not CompareFlagsOr(e, o, 'ACBS\Template Flags', 'Use Stats') then
				CheckActorsACBS(e, o, false);

			if not CompareFlagsOr(e, o, 'ACBS\Template Flags', 'Use AI Data') then
				CheckActorsAIData(e, o, false);

			if not CompareFlagsOr(e, o, 'ACBS\Template Flags', 'Use AI Packages') then
				CheckActorsAIPackages(e, o, false);

			if not CompareFlagsOr(e, o, 'ACBS\Template Flags', 'Use Model/Animation') then begin
				CheckActorsSkeleton(e, o, false);
				CheckDestructible(e, o, false);	// Destructible - special handling for CREA and NPC_ record types
			end;

			if not CompareFlagsOr(e, o, 'ACBS\Template Flags', 'Use Traits') then begin
				EvaluateEx(e, o, 'ZNAM', 'Actors.CombatStyle', false);
				EvaluateEx(e, o, 'INAM', 'Actors.DeathItem', false);
			end;

			if not CompareFlagsOr(e, o, 'ACBS\Template Flags', 'Use Stats') then
				CheckActorsStats(e, o, false);

			if not CompareFlagsOr(e, o, 'ACBS\Template Flags', 'Use Factions') then
				CheckActorsFactions(e, o, false);

			if not CompareFlagsOr(e, o, 'ACBS\Template Flags', 'Use Script') then
				EvaluateEx(e, o, 'SCRI', 'Scripts', false);
			
			// CREA Only
			// -------------------------------------------------------------------------
			if (sig = 'CREA') then
				if not CompareFlagsOr(e, o, 'ACBS\Template Flags', 'Use Model/Animation') then
					EvaluateEx(e, o, 'KFFZ', 'Actors.Anims', false);

			// NPC_ Only
			// -------------------------------------------------------------------------
			if (sig = 'NPC_') then begin
				if not CompareFlagsOr(e, o, 'ACBS\Template Flags', 'Use Traits') then begin
					EvaluateEx(e, o, 'CNAM', 'NPC.Class', false);
					EvaluateEx(e, o, 'RNAM', 'NPC.Race', false);
				end;

				if not CompareFlagsOr(e, o, 'ACBS\Template Flags', 'Use Model/Animation') then
					CheckNPCFaces(e, o, false);
			end;

		end;

		// Faction Record Type

		if (sig = 'FACT') then
			EvaluateEx(e, o, 'Relations', 'Relations', false);

		// Race Record Type

		if (sig = 'RACE') then begin
			CheckRaceBody(e, o, 'Body-F', false); 												// Body-F
			CheckRaceBody(e, o, 'Body-M', false); 												// Body-M
			CheckRaceBody(e, o, 'Body-Size-F', false); 										// Body-Size-F
			CheckRaceBody(e, o, 'Body-Size-M', false); 										// Body-Size-M
			EvaluateEx(e, o, 'ENAM', 'Eyes', false); 											// Eyes
			EvaluateEx(e, o, 'HNAM', 'Hair', false); 											// Hair
			EvaluateEx(e, o, 'DESC', 'R.Description', false);							// R.Description
			CheckRaceHead(e, o, 'R.Ears', false);													// R.Ears
			CheckRaceHead(e, o, 'R.Head', false);													// R.Head
			CheckRaceHead(e, o, 'R.Mouth', false);												// R.Mouth
			EvaluateEx(e, o, 'Relations', 'R.Relations', false);					// R.Relations
			EvaluateEx(e, o, 'DATA\Skill Boosts', 'R.Skills', false);			// R.Skills
			CheckRaceHead(e, o, 'R.Teeth', false);												// R.Teeth
			EvaluateEx(e, o, 'VTCK\Voice #1 (Female)', 'Voice-F', false);	// Voice-F
			EvaluateEx(e, o, 'VTCK\Voice #0 (Male)', 'Voice-M', false);		// Voice-M
		end;

		// Spell (Actor Effect) Record Type

		if (sig = 'SPEL') then
			CheckSpellStats(e, o, false);

		// Weapon Record Type

		if (sig = 'WEAP') then
			EvaluateEx(e, o, 'Weapon Mods', 'WeaponMods', false);

		// Various Record Types

		if InSignatureList(sig, 'ACTI, ALCH, AMMO, BOOK, CONT, DOOR, FURN, IMOD, KEYM, MISC, MSTT, PROJ, TACT, TERM, WEAP') then
			CheckDestructible(e, o, false);

		if InSignatureList(sig, 'ACTI, ALCH, ARMO, CONT, DOOR, FLOR, FURN, INGR, KEYM, LIGH, LVLC, MISC, QUST, WEAP') then
			EvaluateEx(e, o, 'SCRI', 'Scripts', false);
	end;
end;

// ==================================================================
// Finalize
function Finalize: integer;
var
	hdr, desc: IInterface;
begin
	// exit conditions
	if (optionSelected = mrAbort)
	or (not Assigned(slTags))
	or (not Assigned(fn)) then
		exit;

	// sort list of tags
	slTags.Sort;

	// output file name
	AddMessage(#13#10 + fn);

	// if any tags were generated
	if (slTags.Count > 0) then begin
		if (optionSelected = 6) then begin
			hdr := GetElement(f, 'TES4');

			// add tags to description element
			if Assigned(hdr) then begin
				desc := GetElement(hdr, 'SNAM');
				if not Assigned(desc) then
					desc := Add(hdr, 'SNAM', false);
				SetEditValue(desc, Format('{{BASH:%s}}', [slTags.DelimitedText]));
				AddMessage('Added ' + IntToStr(slTags.Count) + ' tags to file header: ' + #13#10 + Format('{{BASH:%s}}', [slTags.DelimitedText]));
			end;
		end
		else if (optionSelected = 7) then
			AddMessage('Suggesting ' + IntToStr(slTags.Count) + ' tags: ' + #13#10 + Format('{{BASH:%s}}', [slTags.DelimitedText]));
	end
	
	// if no tags were generated
	else begin
		AddMessage('No tags suggested');
		
		// remove description element
		desc := GetElement(GetElement(f, 'TES4'), 'SNAM');
		if (optionSelected = 6) and Assigned(desc) then
			Remove(desc);
	end;

	AddMessage(#13#10 + '-------------------------------------------------------------------------------' + #13#10);

	slTags.Free;
end;

end.