local _, ns = ...
local B, C, L, DB = unpack(ns)

tinsert(C.defaultThemes, function()
	local closeDialog = MovieFrame.CloseDialog

	closeDialog:HookScript("OnShow", function(self)
		self:SetScale(UIParent:GetScale())
	end)

	B.StripTextures(closeDialog)
	B.CreateBD(closeDialog)
	B.CreateSD(closeDialog)
	B.Reskin(closeDialog.ConfirmButton)
	B.Reskin(closeDialog.ResumeButton)
end)