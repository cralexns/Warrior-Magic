Scriptname zen_Util

;/ Helper functions /;
int Function Min(int valueA, int valueB) global
	If valueA < valueB
		return valueA
	EndIf
	return valueB
EndFunction

int Function Max(int valueA, int valueB) global
	if valueA > valueB
		return valueA
	EndIf
	return valueB
EndFunction

float Function MaxFloat(float valueA, float valueB) global
	if (valueA > valueB)
		return valueA
	EndIf
	return valueB
EndFunction

float Function MinFloat(float valueA, float valueB) global
	If valueA < valueB
		return valueA
	EndIf
	return valueB
EndFunction	

Float[] Function FloatArrayInit(Float value0, Float value1) global
	Float[] array = new Float[2]
	array[0] = value0
	array[1] = value1
	return array
EndFunction

bool[] Function BoolArrayInit(bool value0, bool value1) global
	bool[] array = new bool[2]
	array[0] = value0
	array[1] = value1
	return array
EndFunction

string Function StringIf(bool condition, string output, string default = "") global
	If condition
		return output
	EndIf
	return default
EndFunction

int Function IntIf(bool condition, int output, int default = 0) global
	If condition
		return output
	EndIf
	return default
EndFunction

float Function FloatIf(bool condition, float output, float default = 0.0) global
	If condition
		return output
	EndIf
	return default
EndFunction

float Function GetLowestFloatValue(float[] floatArray) global
	int idx = 1
	float lowValue = floatArray[0]
	While idx < floatArray.Length
		float currentValue = floatArray[idx]
		If currentValue < lowValue
			lowValue = currentValue
		EndIf
		idx += 1
	EndWhile
	return lowValue
EndFunction

string[] Function RemoveByIndexFromStringArray(string[] stringArray, int idxToRemove) global
	string[] newArray = Utility.CreateStringArray(stringArray.Length - 1)
	int idx = 0
	While idx<stringArray.Length
		If idx != idxToRemove
			newArray[idx] = stringArray[idx]
		EndIf
		idx += 1
	EndWhile

	return newArray
EndFunction

float[] Function RemoveByIndexFromFloatArray(float[] floatArray, int idxToRemove) global
	float[] newArray = Utility.CreateFloatArray(floatArray.Length - 1)
	int idx = 0
	While idx<floatArray.Length
		If idx != idxToRemove
			newArray[idx] = floatArray[idx]
		EndIf
		idx += 1
	EndWhile

	return newArray
EndFunction

Form[] Function RemoveByIndexFromFormArray(Form[] array, int idxToRemove) global
	Form[] newArray = Utility.CreateFormArray(array.Length - 1)
	int idx = 0
	While idx<array.Length
		If idx != idxToRemove
			newArray[idx] = array[idx]
		EndIf
		idx += 1
	EndWhile

	return newArray
EndFunction

Alias[] Function RemoveByIndexFromAliasArray(Alias[] array, int idxToRemove) global
	Alias[] newArray = Utility.CreateAliasArray(array.Length - 1)
	int idx = 0
	While idx<array.Length
		If idx != idxToRemove
			newArray[idx] = array[idx]
		EndIf
		idx += 1
	EndWhile

	return newArray
EndFunction

Form[] Function GetAllKeywords(Form object, bool reverse=false) global
	Form[] keywords = Utility.CreateFormArray(object.GetNumKeywords())
	int i=0
	While i<keywords.Length
		If !reverse
			keywords[i] = object.GetNthKeyword(i)
		Else
			keywords[keywords.Length - i - 1] = object.GetNthKeyword(i)
		EndIf
		i += 1
	EndWhile
	return keywords
EndFunction

string Function IntArrayToString(int[] array) global
	string output
	int idx=0
	While idx<array.Length
		output += "["+idx+"] = '"+array[idx]+"'"
		idx += 1
		If idx < array.Length
			output += ", "
		EndIf
	EndWhile
	return output
EndFunction

int[] Function StringToIntArray(string text, string delim) Global
	string[] parts = StringUtil.Split(text, delim)
	int idx = 0

	int[] out = PapyrusUtil.IntArray(parts.length, 0)
	While idx < parts.length 
		out[idx] = parts[idx] as int
		idx += 1
	EndWhile

	return out
EndFunction

float Function StringPercentageToFloat(string percentage) Global
	int nPercent = percentage as Int
	return nPercent / 100
EndFunction

string Function FloatPercentageToString(float percentage) Global
	return Math.floor(percentage * 100) + "%"
EndFunction

float Function GetFloatArraySum(float[] floatArray) Global
	int idx = 0
	float sum = 0
	While idx < floatArray.Length
		sum += floatArray[idx]
		idx += 1
	EndWhile
	return sum
EndFunction

; Thanks @novarr from LL discord!
int Function Round(float value) Global
	int truncated = value as int
	return (truncated + Math.Ceiling(-0.499 + (value - truncated)))
;/ 	int floored = Math.abs(value) as int
	If Math.abs(value) - 0.5 > floored
		return SignInt(value < 0, floored+1)
	EndIf
	return SignInt(value < 0, floored) /;
EndFunction