local _, ns = ...
local B, C, L, DB = unpack(ns)

tinsert(C.defaultThemes, function()
	AudioOptionsFrameHeader:SetAlpha(0)
	AudioOptionsFrameHeader:ClearAllPoints()
	AudioOptionsFrameHeader:SetPoint("TOP", AudioOptionsFrame, 0, 0)
	B.CreateBD(AudioOptionsFrame)
	B.CreateSD(AudioOptionsFrame)
	B.Reskin(AudioOptionsFrameOkay)
	B.Reskin(AudioOptionsFrameCancel)
	B.Reskin(AudioOptionsFrameDefaults)
end)