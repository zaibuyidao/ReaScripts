-- @noindex

local jKeyboard = {
	control_c = 3,
	backspace = 8,
	tab = 9,
	enter = 13, -- Or CTRL + M !
	control_v = 22,

	escape = 27,
	delete = 6579564,
	
	arrow_up = 30064,
	arrow_down = 1685026670,
	arrow_left = 1818584692,
	arrow_right = 1919379572,	

	home = 1752132965,
	_end = 6647396,
	
	
	space = 32, 
	exclamation = 33, -- !
	double_quote = 34, -- "
	pound = 35, -- #
	dollar = 36, -- $
	precentage = 37, -- %
	ampersand = 38, -- &
	single_quote = 39, -- '
	bracket_open = 40, -- (
	bracket_close = 41, -- )
	mult = 42, -- *
	plus = 43, -- +
	comma = 44, -- ,
	minus = 45, -- -
	period = 46, -- .
	forward_slash = 47, -- /

	zero = 48,
	nine = 57,

	colon = 58, -- :
	semi_colon = 59, -- ;
	smaller_than = 60, -- <
	equals = 61, -- =
	greater_than = 62, -- >
	questionmark = 63, -- ?
	at = 64, -- @
	
	A = 65,
	B = 66,
	C = 67,
	D = 68,
	E = 69,
	F = 70,
	G = 71,
	H = 72,
	I = 73,
	J = 74,
	K = 75,
	L = 76,
	M = 77,
	N = 78,
	O = 79,
	P = 80,
	Q = 81,
	R = 82,
	S = 83,
	T = 84,
	U = 85,
	V = 86,
	W = 87,
	X = 88,
	Y = 89,
	Z = 90,
	
	bracketsquare_open = 91, -- [ ???
	backslash = 92, -- \
	bracketsquare_close = 93, -- ]
	dakje = 94, -- ^ ???
	underscore = 95, -- _
	apestrof = 96, -- ` ???

	a = 97,
	b = 98,
	c = 99,
	d = 100,
	e = 101,
	f = 102,
	g = 103,
	h = 104,
	i = 105,
	j = 106,
	k = 107,
	l = 108,
	m = 109,
	n = 110,
	o = 111,
	p = 112,
	q = 113,
	r = 114,
	s = 115,
	t = 116,
	u = 117,
	v = 118,
	w = 119,
	x = 120,
	y = 121,
	z = 122,
	
	bracket2_open = 123, -- { ???
	pipe = 124, -- |
	bracket2_close = 125, -- }
	tilde = 126, -- ~
	ctrl_backspace = 127
}

function jKeyboard:shift()
	return gfx.mouse_cap&8 == 8
end

function jKeyboard:control()
	return gfx.mouse_cap&4 == 4
end

function jKeyboard:alt()
	return gfx.mouse_cap&16 == 16
end

function jKeyboard:isLetter(iChar)
	if (iChar >= self.A and iChar <= self.Z) or (iChar >= self.a and iChar <= self.z) then
		return true
	else
		return false
	end
end

function jKeyboard:isNumber(iChar)
	if iChar >= self.zero and iChar <= self.nine then
		return true
	else
		return false
	end
end

function jKeyboard:isChar(iChar)
	if iChar >= self.space and iChar <= self.tilde then
		return true
	else
		return false
	end
end

return jKeyboard