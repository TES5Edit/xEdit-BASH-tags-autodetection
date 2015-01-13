{
	Purpose: Bash Tagger
	Game: FO3/FNV/TESV
	Author: fireundubh <fireundubh@gmail.com>
	Version: 1.3.6 (based on "BASH tags autodetection.pas" v1.0)

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

{Return true if the loaded game is Fallout 3}
function IsFallout3(game: string): boolean;
begin
	Result := (game = 'Fallout3.esm');
end;

{Return true if the loaded game is Fallout: New Vegas}
function IsFalloutNV(const game: string): boolean;
begin
	Result := (game = 'FalloutNV.esm');
end;

{Return true if the loaded game is TES4: Oblivion}
function IsOblivion(const game: string): boolean;
begin
	Result := (game = 'Oblivion.esm');
end;

{Return true if the loaded game is TES4: Skyrim}
function IsSkyrim(const game: string): boolean;
begin
	Result := (game = 'Skyrim.esm');
end;

{==================================================================}
{Return True if any flags are set and False if not}
function IsAnyFlagSet(f: IInterface): boolean;
begin
	Result := (GetNativeValue(f) > 0);
end;

{==================================================================}
{Return True if specific flag is set and False if not}
function IsFlagSet(f: IInterface; i: integer): boolean;
begin
	Result := (GetNativeValue(f) and i > 0);
end;

{==================================================================}
{Alias for GetEditValue}
function gev(x: IInterface): string;
begin
	Result := GetEditValue(x);
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

{==================================================================}
{Return the integer value of an ACBS template flag}
function GetTemplateFlag(s: string): integer;
var
	templateFlag: TStringList;
begin
	templateFlag := TStringList.Create;
	templateFlag.DelimitedText := '"Use Traits=1", "Use Stats=2", "Use Factions=4", "Use Actor Effect List=8", "Use AI Data=16", "Use AI Packages=32", "Use Model/Animation=64", "Use Base Data=128", "Use Inventory=256", "Use Script=512"';
	Result := StrToInt(templateFlag.Values[s]);
	templateFlag.Free;
end;

{==================================================================}
// Validate
{Determines whether two elements are different and suggests tags}
{Not to be used when you need to know how two elements differ}
function Validate(x, y: IInterface; tag: string; debug: boolean): integer;
var
	i, j, k, l, m: integer;
begin
	{Exit if the tag already exists}
	if TagExists(tag) then
		exit;

	{Exit if the first element doesn't exist}
	if not Assigned(x) then
		exit;

	{Suggest tag if one element exists while the other does not}
	if Assigned(x) <> Assigned(y) then begin
		if debug then AddMessage('[0] ' + tag + ': ' + FullPath(x));
		if debug then AddMessage('[0] ' + tag + ': ' + FullPath(y));
		AddTag(tag);
		exit;
	end;

	{Suggest tag if the two elements are different}
	if ElementCount(x) <> ElementCount(y) then begin
		if debug then AddMessage('[1] ' + tag + ': ' + FullPath(x));
		if debug then AddMessage('[1] ' + tag + ': ' + FullPath(y));
		AddTag(tag);
		exit;
	end;

	{Iterate through elements, down five levels if needed, and suggest tags}
	for i := 0 to ElementCount(x) - 1 do begin
		// v1.3.5 Attempt to eliminate false positives
		if not Assigned(ElementByIndex(x, i)) and not Assigned(ElementByIndex(y, i)) then
				exit;
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
	entries := ElementByName(e, 'Leveled List Entries');
	entriesmaster := ElementByName(m, 'Leveled List Entries');

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
			coed := ElementBySignature(ent, 'COED');
			coedm := ElementBySignature(entm, 'COED');
			if Assigned(coed) then s1 := SortKey(coed, True) else s1 := '';
			if Assigned(coedm) then s2 := SortKey(coedm, True) else s2 := '';
			if (genv(ent, 'LVLO\Level') <> genv(entm, 'LVLO\Level')) or
				 (genv(ent, 'LVLO\Count') <> genv(entm, 'LVLO\Count')) or
				 (s1 <> s2) then begin
				if debug then AddMessage('Relev: ' + FullPath(e));
				AddTag('Relev');
			end;
		end;
	end;

	// if number of matched entries less than in master list
	if matched < ElementCount(entriesmaster) then begin
		if debug then AddMessage('Delev: ' + FullPath(e));
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

	items := ElementByName(e, 'Items');
	itemsmaster := ElementByName(m, 'Items');

	if Assigned(items) <> Assigned(itemsmaster) then begin
		if debug then AddMessage(tag + ': ' + FullPath(e));
		AddTag(tag);
		exit;
	end;

	if not Assigned(items) then
		exit;

	// Items are sorted, so we don't need to compare by individual item
	// SortKey combines all the items data
	if SortKey(items, True) <> SortKey(itemsmaster, True) then begin
		if debug then AddMessage(tag + ': ' + FullPath(e));
		AddTag(tag);
	end;
end;

{==================================================================}
// v1.3.3 - Actors.ACBS
function CheckActorsACBS(e, m: IInterface; debug: boolean): integer;
var
	f, fm: IInterface;
begin
	tag := 'Actors.ACBS';

	f := ElementByPath(e, 'ACBS');
	fm := ElementByPath(m, 'ACBS');

	// If the Use Stats (0x2) template flag is set, don't bother
	if IsFlagSet(ElementByName(f, 'Template Flags'), GetTemplateFlag('Use Stats'))
	or IsFlagSet(ElementByName(fm, 'Template Flags'), GetTemplateFlag('Use Stats')) then
		exit;

	if GetNativeValue(ElementByPath(e, 'ACBS\Flags')) <> GetNativeValue(ElementByPath(m, 'ACBS\Flags')) then begin
		AddTag(tag);
		exit;
	end;

	Validate(ElementByName(f, 'Fatigue'), ElementByName(fm, 'Fatigue'), tag, debug);
	Validate(ElementByName(f, 'Level'), ElementByName(fm, 'Level'), tag, debug);
	Validate(ElementByName(f, 'Calc min'), ElementByName(fm, 'Calc min'), tag, debug);
	Validate(ElementByName(f, 'Calc max'), ElementByName(fm, 'Calc max'), tag, debug);
	Validate(ElementByName(f, 'Speed Multiplier'), ElementByName(fm, 'Speed Multiplier'), tag, debug);
	Validate(ElementByName(e, 'DATA\Base Health'), ElementByName(m, 'DATA\Base Health'), tag, debug);

	// If the Use AI Data (0x16) template if not set, validate ACBS\Barter gold
	if not IsFlagSet(ElementByName(f, 'Template Flags'), GetTemplateFlag('Use AI Data'))
	or not IsFlagSet(ElementByName(fm, 'Template Flags'), GetTemplateFlag('Use AI Data')) then
		Validate(ElementByName(f, 'Barter gold'), ElementByName(fm, 'Barter gold'), tag, debug);

end;

{==================================================================}
// Actors.AIData
function CheckActorsAIData(e, m: IInterface; debug: boolean): integer;
begin
	tag := 'Actors.AIData';
	Validate(ElementByPath(e, 'AIDT\Aggression'), ElementByPath(m, 'AIDT\Aggression'), tag, debug);
	Validate(ElementByPath(e, 'AIDT\Confidence'), ElementByPath(m, 'AIDT\Confidence'), tag, debug);
	Validate(ElementByPath(e, 'AIDT\Energy level'), ElementByPath(m, 'AIDT\Energy level'), tag, debug);
	Validate(ElementByPath(e, 'AIDT\Responsibility'), ElementByPath(m, 'AIDT\Responsibility'), tag, debug);

	// v1.3.3 - More flags
	if GetNativeValue(ElementByPath(e, 'AIDT\Buys/Sells and Services')) <> GetNativeValue(ElementByPath(m, 'AIDT\Buys/Sells and Services')) then begin
		AddTag(tag);
		exit;
	end;

	Validate(ElementByPath(e, 'AIDT\Teaches'), ElementByPath(m, 'AIDT\Teaches'), tag, debug);
	Validate(ElementByPath(e, 'AIDT\Maximum training level'), ElementByPath(m, 'AIDT\Maximum training level'), tag, debug);
end;

{==================================================================}
// Actors.AIPackages
function CheckActorsAIPackages(e, m: IInterface; debug: boolean): integer;
begin
	tag := 'Actors.AIPackages';
	Validate(ElementByName(e, 'Packages'), ElementByName(m, 'Packages'), tag, debug);
end;

{==================================================================}
// Actors.Skeleton
function CheckActorsSkeleton(e, m: IInterface; debug: boolean): integer;
var
	Model, ModelMaster: IInterface;
begin
	tag := 'Actors.Skeleton';

	Model := ElementByName(e, 'Model');
	ModelMaster := ElementByName(m, 'Model');

	// A fix that might cause problems... We'll see!
	if not Assigned(Model) then
		exit;

	Validate(ElementBySignature(Model, 'MODL'), ElementBySignature(ModelMaster, 'MODL'), tag, debug);
	Validate(ElementBySignature(Model, 'MODB'), ElementBySignature(ModelMaster, 'MODB'), tag, debug);
	Validate(ElementBySignature(Model, 'MODT'), ElementBySignature(ModelMaster, 'MODT'), tag, debug);
end;

{==================================================================}
// Actors.Stats
function CheckActorsStats(e, m: IInterface; debug: boolean): integer;
var
	d, dm: IInterface;
	sig: string;
begin
	tag := 'Actors.Stats';

	sig := geev(e, 'Record Header\Signature');

	d := ElementBySignature(e, 'DATA');
	dm := ElementBySignature(m, 'DATA');

	if (sig = 'CREA') then begin

		Validate(ElementByName(d, 'Health'), ElementByName(dm, 'Health'), tag, debug);
		Validate(ElementByName(d, 'Combat Skill'), ElementByName(dm, 'Combat Skill'), tag, debug);
		Validate(ElementByName(d, 'Magic Skill'), ElementByName(dm, 'Magic Skill'), tag, debug);
		Validate(ElementByName(d, 'Stealth Skill'), ElementByName(dm, 'Stealth Skill'), tag, debug);
		Validate(ElementByName(d, 'Attributes'), ElementByName(dm, 'Attributes'), tag, debug);
	end;

	if (sig = 'NPC_') then begin
		Validate(ElementByName(d, 'Base Health'), ElementByName(dm, 'Base Health'), tag, debug);
		Validate(ElementByName(d, 'Attributes'), ElementByName(dm, 'Attributes'), tag, debug);
		Validate(ElementByPath(e, 'DNAM\Skill Values'), ElementByName(m, 'DNAM\Skill Values'), tag, debug);
		Validate(ElementByPath(e, 'DNAM\Skill Offsets'), ElementByName(m, 'DNAM\Skill Offsets'), tag, debug);
	end;
end;

{==================================================================}
// NpcFaces
function CheckNPCFaces(e, m: IInterface; debug: boolean): integer;
begin
	tag := 'NpcFaces';
	Validate(ElementBySignature(e, 'HNAM'), ElementBySignature(m, 'HNAM'), tag, debug);
	Validate(ElementBySignature(e, 'LNAM'), ElementBySignature(m, 'LNAM'), tag, debug);
	Validate(ElementBySignature(e, 'ENAM'), ElementBySignature(m, 'ENAM'), tag, debug);
	Validate(ElementBySignature(e, 'HCLR'), ElementBySignature(m, 'HCLR'), tag, debug);
	Validate(ElementByName(e, 'FaceGen Data'), ElementByName(m, 'FaceGen Data'), tag, debug);
end;

{==================================================================}
// Body-F
// Body-M
// Body-Size-F
// Body-Size-M
function CheckRaceBody(e, m: IInterface; tag: string; debug: boolean): integer;
begin
	if (tag = 'Body-F') then
		Validate(ElementByPath(e, 'Body Data\Female Body Data\Parts'), ElementByPath(m, 'Body Data\Female Body Data\Parts'), tag, debug);
	if (tag = 'Body-M') then
		Validate(ElementByPath(e, 'Body Data\Male Body Data\Parts'), ElementByPath(m, 'Body Data\Male Body Data\Parts'), tag, debug);
	if (tag = 'Body-Size-F') then begin
		Validate(ElementByPath(e, 'DATA\Female Height'), ElementByPath(m, 'DATA\Female Height'), tag, debug);
		Validate(ElementByPath(e, 'DATA\Female Weight'), ElementByPath(m, 'DATA\Female Weight'), tag, debug);
	end;
	if (tag = 'Body-Size-M') then begin
		Validate(ElementByPath(e, 'DATA\Male Height'), ElementByPath(m, 'DATA\Male Height'), tag, debug);
		Validate(ElementByPath(e, 'DATA\Male Weight'), ElementByPath(m, 'DATA\Male Weight'), tag, debug);
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
		Validate(ElementByIP(e, 'Head Data\Male Head Data\Parts\[0]'), ElementByIP(m, 'Head Data\Male Head Data\Parts\[0]'), tag, debug);
		Validate(ElementByIP(e, 'Head Data\Female Head Data\Parts\[0]'), ElementByIP(m, 'Head Data\Female Head Data\Parts\[0]'), tag, debug);
		Validate(ElementByName(e, 'FaceGen Data'), ElementByName(m, 'FaceGen Data'), tag, debug);
	end;

	if (tag = 'R.Ears') then begin
		Validate(ElementByIP(e, 'Head Data\Male Head Data\Parts\[1]'), ElementByIP(m, 'Head Data\Male Head Data\Parts\[1]'), tag, debug);
		Validate(ElementByIP(e, 'Head Data\Female Head Data\Parts\[1]'), ElementByIP(m, 'Head Data\Female Head Data\Parts\[1]'), tag, debug);
	end;

	if (tag = 'R.Mouth') then begin
		Validate(ElementByIP(e, 'Head Data\Male Head Data\Parts\[2]'), ElementByIP(m, 'Head Data\Male Head Data\Parts\[2]'), tag, debug);
		Validate(ElementByIP(e, 'Head Data\Female Head Data\Parts\[2]'), ElementByIP(m, 'Head Data\Female Head Data\Parts\[2]'), tag, debug);
	end;

	if (tag = 'R.Teeth') then begin
		Validate(ElementByIP(e, 'Head Data\Male Head Data\Parts\[3]'), ElementByIP(m, 'Head Data\Male Head Data\Parts\[3]'), tag, debug);
		Validate(ElementByIP(e, 'Head Data\Female Head Data\Parts\[3]'), ElementByIP(m, 'Head Data\Female Head Data\Parts\[3]'), tag, debug);
		if IsFallout3(game) then begin
			Validate(ElementByIP(e, 'Head Data\Male Head Data\Parts\[4]'), ElementByIP(m, 'Head Data\Male Head Data\Parts\[4]'), tag, debug);
			Validate(ElementByIP(e, 'Head Data\Female Head Data\Parts\[4]'), ElementByIP(m, 'Head Data\Female Head Data\Parts\[4]'), tag, debug);
		end;
	end;

end;

{==================================================================}
// C.Climate
function CheckCellClimate(e, m: IInterface; debug: boolean): integer;
begin
	tag := 'C.Climate';

	// If the Behave like exterior (0x128) flag is set in one record but not in the other, suggest tag
	if IsFlagSet(ElementByPath(e, 'DATA'), 128) <> IsFlagSet(ElementByPath(m, 'DATA'), 128) then begin
		AddTag(tag);
		exit;
	end;

	Validate(ElementBySignature(e, 'XCCM'), ElementBySignature(m, 'XCCM'), tag, debug);
end;

{==================================================================}
// C.RecordFlags
function CheckCellRecordFlags(e, m: IInterface; debug: boolean): integer;
var
	f, fm: IInterface;
begin
	tag := 'C.RecordFlags';

	f  := ElementByPath(e, 'Record Header\Record Flags');
	fm := ElementByPath(m, 'Record Header\Record Flags');

	if GetNativeValue(f) <> GetNativeValue(fm) then
		AddTag(tag);
end;

{==================================================================}
// C.Water
function CheckCellWater(e, m: IInterface; debug: boolean): integer;
begin
	tag := 'C.Water';

	// If the Has water (0x2) flag is set in one record but not in the other, suggest tag and exit
	if IsFlagSet(ElementByPath(e, 'DATA'), 2) <> IsFlagSet(ElementByPath(m, 'DATA'), 2) then begin
		AddTag(tag);
		exit;
	end;

	Validate(ElementBySignature(e, 'XCLW'), ElementBySignature(m, 'XCLW'), tag, debug);
	Validate(ElementBySignature(e, 'XCWT'), ElementBySignature(m, 'XCWT'), tag, debug);
end;

{==================================================================}
// Destructible
function CheckDestructible(e, m: IInterface; debug: boolean): integer;
var
	d, dm: IInterface;
begin
	tag := 'Destructible';

	d := ElementByName(e, 'Destructable');
	dm := ElementByName(m, 'Destructable');

	if Assigned(d) <> Assigned(dm) then begin
		AddTag(tag);		
		exit;
	end;
	
	Validate(ElementByPath(d, 'DEST\Health'), ElementByPath(dm, 'DEST\Health'), tag, debug);
	Validate(ElementByPath(d, 'DEST\Count'), ElementByPath(dm, 'DEST\Count'), tag, debug);

	if GetNativeValue(ElementByPath(d, 'DEST\Flags')) <> GetNativeValue(ElementByPath(dm, 'DEST\Flags')) then begin
		AddTag(tag);
		exit;
	end;

	Validate(ElementByPath(d, 'Stages'), ElementByPath(dm, 'Stages'), tag, debug);
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
	sig := geev(e, 'Record Header\Signature');

	if (sig = 'ALCH') or (sig = 'AMMO')	or (sig = 'BOOK')
	or (sig = 'CLAS')	or (sig = 'INGR')	or (sig = 'KEYM')
	or (sig = 'LIGH')	or (sig = 'LSCR') or (sig = 'LTEX')
	or (sig = 'MGEF') or (sig = 'MISC')	or (sig = 'REGN')
	or (sig = 'TREE')	or (sig = 'WEAP') then begin
		Validate(ElementByName(e, 'Icon'), ElementByName(m, 'Icon'), tag, debug);
	end;

	if (sig = 'ACTI')	or (sig = 'ALCH')	or (sig = 'AMMO')
	or (sig = 'BOOK')	or (sig = 'DOOR')	or (sig = 'FLOR')
	or (sig = 'FURN')	or (sig = 'GRAS')	or (sig = 'INGR')
	or (sig = 'KEYM')	or (sig = 'LIGH')	or (sig = 'MGEF')
	or (sig = 'MISC')	or (sig = 'STAT')	or (sig = 'TREE')
	or (sig = 'WEAP') then begin
		Validate(ElementByName(e, 'Model'), ElementByName(m, 'Model'), tag, debug);
	end;

	if (sig ='CREA') then begin
		Validate(ElementBySignature(e, 'NIFZ'), ElementBySignature(m, 'NIFZ'), tag, debug);
		Validate(ElementBySignature(e, 'NIFT'), ElementBySignature(m, 'NIFT'), tag, debug);
	end;

	// 1.2 improved efsh validation
	if (sig = 'EFSH') then begin
		if GetNativeValue(ElementByPath(e, 'Record Header\Record Flags')) <> GetNativeValue(ElementByPath(m, 'Record Header\Record Flags')) then begin
			AddTag(tag);
			exit;
		end;
		Validate(ElementBySignature(e, 'EDID'), ElementBySignature(m, 'EDID'), tag, debug);
		Validate(ElementBySignature(e, 'ICON'), ElementBySignature(m, 'ICON'), tag, debug);
		Validate(ElementBySignature(e, 'ICO2'), ElementBySignature(m, 'ICO2'), tag, debug);
		Validate(ElementBySignature(e, 'NAM7'), ElementBySignature(m, 'NAM7'), tag, debug);
		Validate(ElementBySignature(e, 'DATA'), ElementBySignature(m, 'DATA'), tag, debug);
	end;

	if (sig = 'ARMO') then begin
		Validate(ElementBySignature(e, 'ICON'), ElementBySignature(m, 'ICON'), tag, debug);
		Validate(ElementBySignature(e, 'ICO2'), ElementBySignature(m, 'ICO2'), tag, debug);
		Validate(ElementByPath(e, 'Male biped model\MODL'), ElementByPath(m, 'Male biped model\MODL'), tag, debug);
		Validate(ElementByPath(e, 'Male biped model\MODT'), ElementByPath(m, 'Male biped model\MODT'), tag, debug);
		Validate(ElementByPath(e, 'Male world model\MOD2'), ElementByPath(m, 'Male world model\MOD2'), tag, debug);
		Validate(ElementByPath(e, 'Female biped model\MOD3'), ElementByPath(m, 'Female biped model\MOD3'), tag, debug);
		Validate(ElementByPath(e, 'Female biped model\MO3T'), ElementByPath(m, 'Female biped model\MO3T'), tag, debug);
		Validate(ElementByPath(e, 'Female world model\MOD4'), ElementByPath(m, 'Female world model\MOD4'), tag, debug);
		if GetNativeValue(ElementByPath(e, 'BMDT\Biped Flags')) <> GetNativeValue(ElementByPath(m, 'BMDT\Biped Flags')) then
			AddTag(tag);
	end;
end;

{==================================================================}
// SpellStats
function CheckSpellStats(e, m: IInterface; debug: boolean): integer;
begin
	tag := 'SpellStats';
	Validate(ElementBySignature(e, 'FULL'), ElementBySignature(m, 'FULL'), tag, debug);
	Validate(ElementBySignature(e, 'SPIT'), ElementBySignature(m, 'SPIT'), tag, debug);
end;

{==================================================================}
// Sound
function CheckSound(e, m: IInterface; debug: boolean): integer;
var
	sig: string;
begin
	tag := 'Sound';
	sig := geev(e, 'Record Header\Signature');

	if (sig = 'ACTI') then begin
		Validate(ElementBySignature(e, 'SNAM'), ElementBySignature(m, 'SNAM'), tag, debug);
		Validate(ElementBySignature(e, 'VNAM'), ElementBySignature(m, 'VNAM'), tag, debug);
	end;

	if (sig = 'CONT') then begin
		Validate(ElementBySignature(e, 'SNAM'), ElementBySignature(m, 'SNAM'), tag, debug);
		Validate(ElementBySignature(e, 'QNAM'), ElementBySignature(m, 'QNAM'), tag, debug);
		if not IsFallout3(game) then
			Validate(ElementBySignature(e, 'RNAM'), ElementBySignature(m, 'RNAM'), tag, debug); // fo3 doesn't have this element
	end;

	if (sig = 'CREA') then begin
		Validate(ElementBySignature(e, 'WNAM'), ElementBySignature(m, 'WNAM'), tag, debug);
		Validate(ElementBySignature(e, 'CSCR'), ElementBySignature(m, 'CSCR'), tag, debug);
		Validate(ElementByName(e, 'Sound Types'), ElementByName(m, 'Sound Types'), tag, debug);
	end;

	if (sig = 'DOOR') then begin
		Validate(ElementBySignature(e, 'SNAM'), ElementBySignature(m, 'SNAM'), tag, debug);
		Validate(ElementBySignature(e, 'ANAM'), ElementBySignature(m, 'ANAM'), tag, debug);
		Validate(ElementBySignature(e, 'BNAM'), ElementBySignature(m, 'BNAM'), tag, debug);
	end;

	if (sig = 'LIGH') then begin
		Validate(ElementBySignature(e, 'SNAM'), ElementBySignature(m, 'SNAM'), tag, debug);
	end;

	if (sig = 'MGEF') then begin
		Validate(ElementByPath(e, 'DATA\Effect sound'), ElementByPath(m, 'DATA\Effect sound'), tag, debug);
		Validate(ElementByPath(e, 'DATA\Bolt sound'), ElementByPath(m, 'DATA\Bolt sound'), tag, debug);
		Validate(ElementByPath(e, 'DATA\Hit sound'), ElementByPath(m, 'DATA\Hit sound'), tag, debug);
		Validate(ElementByPath(e, 'DATA\Area sound'), ElementByPath(m, 'DATA\Area sound'), tag, debug);
	end;

	if (sig = 'WTHR') then begin
		Validate(ElementByName(e, 'Sounds'), ElementByName(m, 'Sounds'), tag, debug);
	end;
end;

{==================================================================}
// Stats
function CheckStats(e, m: IInterface; debug: boolean): integer;
var
	d, dm: IInterface;
	sig: string;
begin
	tag := 'Stats';
	sig := geev(e, 'Record Header\Signature');

	// Ammunition
	if (sig = 'AMMO') then begin
		Validate(ElementBySignature(e, 'DATA'), ElementBySignature(m, 'DATA'), tag, debug);
		if not IsFallout3(game) then
			Validate(ElementBySignature(e, 'DAT2'), ElementBySignature(m, 'DAT2'), tag, debug); // fo3 doesn't have this element
	end;

	// Armor
	if (sig = 'ARMO') then begin
		Validate(ElementBySignature(e, 'DATA'), ElementBySignature(m, 'DATA'), tag, debug);
		Validate(ElementBySignature(e, 'DNAM'), ElementBySignature(m, 'DNAM'), tag, debug);
	end;

	// Ingestibles, Books, Keys, Lights, Misc. Items, Weapons
	if (sig = 'ALCH')	or (sig = 'BOOK')	or (sig = 'KEYM')
	or (sig = 'LIGH')	or (sig = 'MISC')	or (sig = 'WEAP')	then
		Validate(ElementBySignature(e, 'DATA'), ElementBySignature(m, 'DATA'), tag, debug);
end;

{==================================================================}
{Main}
function Initialize: integer;
var
	tmplLoaded: string;
begin
	optionSelected := MessageDlg('Do you want to write any found tags to the file header?', mtConfirmation, [mbYes, mbNo, mbAbort], 0);
	if optionSelected = mrAbort then
		exit;
	
	slTags := TStringList.Create; // list of tags
	slTags.Delimiter := ','; // separated by comma

	game := GetFileName(FileByLoadOrder(00));
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
	m: IInterface; // master record
	sig: string;
begin
	if optionSelected = mrAbort then
		exit;
	
	fi := GetFile(e);
	fn := GetFileName(fi);

	// get master record
	m := Master(e);

	// no master - nothing to detect
	if not Assigned(m) then
		exit;

	// if record overrides several masters, then get the last one
	if OverrideCount(m) > 1 then
		m := OverrideByIndex(m, OverrideCount(m) - 2);

	// v1.3.4 Stop processing deleted records to avoid errors
	if GetIsDeleted(e) or GetIsDeleted(m) then
		exit;

	sig := geev(e, 'Record Header\Signature');

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
			Result := Validate(ElementBySignature(e, 'XCAS'), ElementBySignature(m,  'XCAS'), 'C.Acoustic', false);
		{C.Climate}
		if (sig = 'CELL') then
			Result := CheckCellClimate(e, m, false);
		{C.Encounter}
		if (sig = 'CELL') then
			Result := Validate(ElementBySignature(e, 'XEZN'), ElementBySignature(m,  'XEZN'), 'C.Encounter', false);
		{C.ImageSpace}
		if (sig = 'CELL') then
			Result := Validate(ElementBySignature(e, 'XCIM'), ElementBySignature(m,  'XCIM'), 'C.ImageSpace', false);
		{C.Light}
		if (sig = 'CELL') then
			Result := Validate(ElementBySignature(e, 'XCLL'), ElementBySignature(m,  'XCLL'), 'C.Light', false);
		{C.Music}
		if (sig = 'CELL') then
			Result := Validate(ElementBySignature(e, 'XCMO'), ElementBySignature(e, 'XCMO'), 'C.Music', false);
		{C.Name}
		if (sig = 'CELL') then
			Result := Validate(ElementBySignature(e, 'FULL'), ElementBySignature(e, 'FULL'), 'C.Name', false);
		{C.Owner}
		if (sig = 'CELL') then
			Result := Validate(ElementByName(e, 'Ownership'), ElementByName(m, 'Ownership'), 'C.Owner', false);
		{C.RecordFlags}
		if (sig = 'CELL') then
			Result := CheckCellRecordFlags(e, m, false);
		{C.Water}
		if (sig = 'CELL') then
			Result := CheckCellWater(e, m, false);

		//Leveled List Record Types
		//---------------------------------------------------------------------------
		{Delev/Relev}
		if (sig = 'LVLI') or (sig = 'LVLC') or (sig = 'LVLN') or (sig = 'LVSP') then
			Result := CheckDelevRelev(e, m, false);

		//Actor and Container Record Types
		//---------------------------------------------------------------------------
		{Invent}
		if (sig = 'CONT') then
			Result := CheckInvent(e, m, false);

		{Invent - special handling for CREA and NPC_ record types}
		if (sig = 'NPC_') or (sig = 'CREA') then begin
			// If the Use Inventory (0x256) template flag is set, skip record to handle inheritance
			if IsFlagSet(ElementByPath(e, 'ACBS\Template Flags'), GetTemplateFlag('Use Inventory'))
			or IsFlagSet(ElementByPath(m, 'ACBS\Template Flags'), GetTemplateFlag('Use Inventory')) then
				exit;

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
			Result := CheckGraphics(e, m, false);

		{Names}
		if (sig <> 'CELL') and (sig <> 'REFR') and (sig <> 'ACHR') and (sig <> 'NAVM') and (sig <> 'CREA') and (sig <> 'NPC_') then
			Result := Validate(ElementBySignature(e, 'FULL'), ElementBySignature(m, 'FULL'), 'Names', false);

		{Names - special handling for CREA and NPC_ record types}
		if (sig = 'CREA') or (sig = 'NPC_') then begin
			// If the Use Base Data (0x128) template flag is set, skip record to handle inheritance
			if IsFlagSet(ElementByPath(e, 'ACBS\Template Flags'), GetTemplateFlag('Use Base Data'))
			or IsFlagSet(ElementByPath(m, 'ACBS\Template Flags'), GetTemplateFlag('Use Base Data')) then
				exit;
			Result := Validate(ElementBySignature(e, 'FULL'), ElementBySignature(m, 'FULL'), 'Names', false);
		end;

		{Sound}
		if (sig = 'ACTI') or (sig = 'CONT') or (sig = 'DOOR')
		or (sig = 'LIGH') or (sig = 'MGEF') or (sig = 'WTHR') then
			Result := CheckSound(e, m, false);

		{Sound - special handling for CREA record type}
		if (sig = 'CREA') then begin
			// If the Use Model/Animation (0x64) template flag is set, skip record to handle inheritance
			if IsFlagSet(ElementByPath(e, 'ACBS\Template Flags'), GetTemplateFlag('Use Model/Animation'))
			or IsFlagSet(ElementByPath(m, 'ACBS\Template Flags'), GetTemplateFlag('Use Model/Animation')) then
				exit;
			Result := CheckSound(e, m, false);
		end;

		{Stats}
		if (sig = 'ALCH') or (sig = 'AMMO') or (sig = 'ARMO')
		or (sig = 'BOOK') or (sig = 'KEYM') or (sig = 'LIGH')
		or (sig = 'MISC') or (sig = 'WEAP') then
			Result := CheckStats(e, m, false);
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
			Result := CheckActorsACBS(e, m, false);
		end;

		{Actors.AIData}
		if (sig = 'NPC_') or (sig = 'CREA') then begin
			// If the Use AI Data (0x16) template flag is set, skip record to handle inheritance
			if IsFlagSet(ElementByPath(e, 'ACBS\Template Flags'), GetTemplateFlag('Use AI Data'))
			or IsFlagSet(ElementByPath(m, 'ACBS\Template Flags'), GetTemplateFlag('Use AI Data')) then
				exit;
			Result := CheckActorsAIData(e, m, false);
		end;

		{Actors.AIPackages}
		if (sig = 'NPC_') or (sig = 'CREA') then begin
			// If the Use AI Packages (0x32) template flag is set, skip record to handle inheritance
			if IsFlagSet(ElementByPath(e, 'ACBS\Template Flags'), GetTemplateFlag('Use AI Packages'))
			or IsFlagSet(ElementByPath(m, 'ACBS\Template Flags'), GetTemplateFlag('Use AI Packages')) then
				exit;
			Result := CheckActorsAIPackages(e, m, false);
		end;

		{Actors.Anims}
		if (sig = 'CREA') then begin
			// If the Use Model/Animation (0x64) template flag is set, skip record to handle inheritance
			if IsFlagSet(ElementByPath(e, 'ACBS\Template Flags'), GetTemplateFlag('Use Model/Animation'))
			or IsFlagSet(ElementByPath(m, 'ACBS\Template Flags'), GetTemplateFlag('Use Model/Animation')) then
				exit;
			Result := Validate(ElementBySignature(e, 'KFFZ'), ElementBySignature(m, 'KFFZ'), 'Actors.Anims', false);
		end;

		{Actors.CombatStyle}
		if (sig = 'NPC_') or (sig = 'CREA') then begin
			// If the Use Traits (0x1) template flag is set, skip record to handle inheritance
			if IsFlagSet(ElementByPath(e, 'ACBS\Template Flags'), GetTemplateFlag('Use Traits'))
			or IsFlagSet(ElementByPath(m, 'ACBS\Template Flags'), GetTemplateFlag('Use Traits')) then
				exit;
			Result := Validate(ElementBySignature(e, 'ZNAM'), ElementBySignature(m, 'ZNAM'), 'Actors.CombatStyle', false);
		end;

		{Actors.DeathItem}
		if (sig = 'NPC_') or (sig = 'CREA') then begin
			// If the Use Traits (0x1) template flag is set, skip record to handle inheritance
			if IsFlagSet(ElementByPath(e, 'ACBS\Template Flags'), GetTemplateFlag('Use Traits'))
			or IsFlagSet(ElementByPath(m, 'ACBS\Template Flags'), GetTemplateFlag('Use Traits')) then
				exit;
			Result := Validate(ElementBySignature(e, 'INAM'), ElementBySignature(m, 'INAM'), 'Actors.DeathItem', false);
		end;

		{Actors.Skeleton}
		if (sig = 'NPC_') or (sig = 'CREA') then begin
			// If the Use Model/Animation (0x64) template flag is set, skip record to handle inheritance
			if IsFlagSet(ElementByPath(e, 'ACBS\Template Flags'), GetTemplateFlag('Use Model/Animation'))
			or IsFlagSet(ElementByPath(m, 'ACBS\Template Flags'), GetTemplateFlag('Use Model/Animation')) then
				exit;
			Result := CheckActorsSkeleton(e, m, false);
		end;

		{Actors.Stats}
		if (sig = 'NPC_') or (sig = 'CREA') then begin
			// If the Use Stats (0x2) template flag is set, skip record to handle inheritance
			if IsFlagSet(ElementByPath(e, 'ACBS\Template Flags'), GetTemplateFlag('Use Stats'))
			or IsFlagSet(ElementByPath(m, 'ACBS\Template Flags'), GetTemplateFlag('Use Stats')) then
				exit;
			Result := CheckActorsStats(e, m, false);
		end;

		{Factions}
		if (sig = 'NPC_') or (sig = 'CREA') then begin
			// If the Use Factions (0x4) template flag is set, skip record to handle inheritance
			if IsFlagSet(ElementByPath(e, 'ACBS\Template Flags'), GetTemplateFlag('Use Factions'))
			or IsFlagSet(ElementByPath(m, 'ACBS\Template Flags'), GetTemplateFlag('Use Factions')) then
				exit;
			Result := Validate(ElementByName(e, 'Factions'), ElementByName(m, 'Factions'), 'Factions', false);
		end;

		{NPC.Class}
		if (sig = 'NPC_') then begin
			// If the Use Traits (0x1) template flag is set, skip record to handle inheritance
			if IsFlagSet(ElementByPath(e, 'ACBS\Template Flags'), GetTemplateFlag('Use Traits'))
			or IsFlagSet(ElementByPath(m, 'ACBS\Template Flags'), GetTemplateFlag('Use Traits')) then
				exit;
			Result := Validate(ElementBySignature(e, 'CNAM'), ElementBySignature(m, 'CNAM'), 'NPC.Class', false);
		end;

		{NPC.Race}
		if (sig = 'NPC_') then begin
			// If the Use Traits (0x1) template flag is set, skip record to handle inheritance
			if IsFlagSet(ElementByPath(e, 'ACBS\Template Flags'), GetTemplateFlag('Use Traits'))
			or IsFlagSet(ElementByPath(m, 'ACBS\Template Flags'), GetTemplateFlag('Use Traits')) then
				exit;
			Result := Validate(ElementBySignature(e, 'RNAM'), ElementBySignature(m, 'RNAM'), 'NPC.Race', false);
		end;

		{NPCFaces}
		if (sig = 'NPC_') then begin
			// If the Use Model/Animation (0x64) template flag is set, skip record to handle inheritance
			if IsFlagSet(ElementByPath(e, 'ACBS\Template Flags'), GetTemplateFlag('Use Model/Animation'))
			or IsFlagSet(ElementByPath(m, 'ACBS\Template Flags'), GetTemplateFlag('Use Model/Animation')) then
				exit;
			Result := CheckNPCFaces(e, m, false);
		end;

		//Faction Record Type
		//---------------------------------------------------------------------------
		{Relations}
		if (sig = 'FACT') then
			Result := Validate(ElementByName(e, 'Relations'), ElementByName(m, 'Relations'), 'Relations', false);

		//Race Record Type
		//---------------------------------------------------------------------------
		{Body-F}
		if (sig = 'RACE') then
			Result := CheckRaceBody(e, m, 'Body-F', false);
		{Body-M}
		if (sig = 'RACE') then
			Result := CheckRaceBody(e, m, 'Body-M', false);
		{Body-Size-F}
		if (sig = 'RACE') then
			Result := CheckRaceBody(e, m, 'Body-Size-F', false);
		{Body-Size-M}
		if (sig = 'RACE') then
			Result := CheckRaceBody(e, m, 'Body-Size-M', false);
		{Eyes}
		if (sig = 'RACE') then
			Result := Validate(ElementBySignature(e, 'ENAM'), ElementBySignature(m, 'ENAM'), 'Eyes', false);
		{Hair}
		if (sig = 'RACE') then
			Result := Validate(ElementBySignature(e, 'HNAM'), ElementBySignature(m, 'HNAM'), 'Hair', false);
		{R.Description}
		if (sig = 'RACE') then
			Result := Validate(ElementBySignature(e, 'DESC'), ElementBySignature(m, 'DESC'), 'R.Description', false);
		{R.Ears}
		if (sig = 'RACE') then
			Result := CheckRaceHead(e, m, 'R.Ears', false);
		{R.Head}
		if (sig = 'RACE') then
			Result := CheckRaceHead(e, m, 'R.Head', false);
		{R.Mouth}
		if (sig = 'RACE') then
			Result := CheckRaceHead(e, m, 'R.Mouth', false);
		{R.Relations}
		if (sig = 'RACE') then
			Result := Validate(ElementByName(e, 'Relations'), ElementByName(m, 'Relations'), 'R.Relations', false);
		{R.Skills}
		if (sig = 'RACE') then
			Result := Validate(ElementByPath(e, 'DATA\Skill Boosts'), ElementByPath(m, 'DATA\Skill Boosts'), 'R.Skills', false);
		{R.Teeth}
		if (sig = 'RACE') then
			Result := CheckRaceHead(e, m, 'R.Teeth', false);
		{Voice-F}
		if (sig = 'RACE') then
			Result := Validate(ElementByPath(e, 'VTCK\Voice #1 (Female)'), ElementByPath(m, 'VTCK\Voice #1 (Female)'), 'Voice-F', false);
		{Voice-M}
		if (sig = 'RACE') then
			Result := Validate(ElementByPath(e, 'VTCK\Voice #0 (Male)'), ElementByPath(m, 'VTCK\Voice #0 (Male)'), 'Voice-M', false);

		//Spell (Actor Effect) Record Type
		//---------------------------------------------------------------------------
		{SpellStats}
		if (sig = 'SPEL') then
			Result := CheckSpellStats(e, m, false);

		//Various Record Types
		//---------------------------------------------------------------------------
		{Destructible}
		if (sig = 'ACTI') or (sig = 'ALCH') or (sig = 'AMMO')
		or (sig = 'BOOK') or (sig = 'CONT') or (sig = 'DOOR')
		or (sig = 'FURN') or (sig = 'IMOD') or (sig = 'KEYM')
		or (sig = 'MISC') or (sig = 'MSTT') or (sig = 'PROJ')
		or (sig = 'TACT') or (sig = 'TERM') or (sig = 'WEAP') then
			Result := CheckDestructible(e, m, false);

		{Destructible - special handling for CREA and NPC_ record types}
		if (sig = 'CREA') or (sig = 'NPC_') then begin
			// If the Use Model/Animation (0x64) template flag is set, skip record to handle inheritance
			if IsFlagSet(ElementByPath(e, 'ACBS\Template Flags'), GetTemplateFlag('Use Model/Animation'))
			or IsFlagSet(ElementByPath(m, 'ACBS\Template Flags'), GetTemplateFlag('Use Model/Animation')) then
				exit;
			Result := CheckDestructible(e, m, false);
		end;

		{Scripts}
		if (sig = 'ACTI') or (sig = 'ALCH') or (sig = 'ARMO')
		or (sig = 'CONT') or (sig = 'DOOR') or (sig = 'FLOR')
		or (sig = 'FURN') or (sig = 'INGR') or (sig = 'KEYM')
		or (sig = 'LIGH') or (sig = 'LVLC') or (sig = 'MISC')
		or (sig = 'QUST') or (sig = 'WEAP') then
			Result := Validate(ElementBySignature(e, 'SCRI'), ElementBySignature(m, 'SCRI'), 'Scripts', false);

		{Scripts - special handling for CREA and NPC_ record types}
		if (sig = 'CREA') or (sig = 'NPC_') then begin
			// If the Use Script (0x512) template flag is set, skip record to handle inheritance
			if IsFlagSet(ElementByPath(e, 'ACBS\Template Flags'), GetTemplateFlag('Use Script'))
			or IsFlagSet(ElementByPath(m, 'ACBS\Template Flags'), GetTemplateFlag('Use Script')) then
				exit;
			Result := Validate(ElementBySignature(e, 'SCRI'), ElementBySignature(m, 'SCRI'), 'Scripts', false);
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
			Result := Validate(ElementByName(e, 'Weapon Mods'), ElementByName(m, 'Weapon Mods'), 'WeaponMods', false);
	end;

	//---------------------------------------------------------------------------
	//Skyrim
	//---------------------------------------------------------------------------
	if IsSkyrim(game) then begin
		{C.Location}
		if (sig = 'CELL') then
			Result := Validate(ElementBySignature(e, 'XLCN'), ElementBySignature(m,  'XLCN'), 'C.Location', false);
	end;
	
end;

function Finalize: integer;
var
	hdr, desc: IInterface;
begin
	if (optionSelected = mrAbort) or (not Assigned(slTags)) then
		exit;

	slTags.Sort;

	AddMessage(#13#10 + fn + ':');

	if slTags.Count > 0 then begin
		
		if optionSelected = 6 then begin
			AddMessage('Added tags to file header: ' + #13#10 + Format('{{BASH:%s}}', [slTags.DelimitedText]));
			hdr := ElementBySignature(fi, 'TES4');
			if Assigned(hdr) then begin
				desc := ElementBySignature(hdr, 'SNAM');
				if not Assigned(desc) then
					desc := Add(hdr, 'SNAM', false);
				SetEditValue(desc, Format('{{BASH:%s}}', [slTags.DelimitedText]));
			end;
		end
		else if optionSelected = 7 then
			AddMessage('Suggested tags: ' + #13#10 + Format('{{BASH:%s}}', [slTags.DelimitedText]));
	
	end;

	if slTags.Count = 0 then
		AddMessage('No tags suggested');

	AddMessage(#13#10 + '-------------------------------------------------------------------------------' + #13#10);

	slTags.Free;
end;

end.