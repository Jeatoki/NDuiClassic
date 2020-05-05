local _, ns = ...
local B, C, L, DB = unpack(ns)

C.themes["Blizzard_TrainerUI"] = function()
	local r, g, b = DB.r, DB.g, DB.b

	B.ReskinPortraitFrame(ClassTrainerFrame, 10, -5, -30, 70)
	B.Reskin(ClassTrainerTrainButton)
	B.Reskin(ClassTrainerCancelButton)
	B.ReskinDropDown(ClassTrainerFrameFilterDropDown)
	B.ReskinScroll(ClassTrainerListScrollFrameScrollBar)
	B.ReskinScroll(ClassTrainerDetailScrollFrameScrollBar)

	B.ReskinExpandOrCollapse(ClassTrainerCollapseAllButton)
	ClassTrainerExpandButtonFrame:DisableDrawLayer("BACKGROUND")

	for i = 1, 11 do
		local bu = _G["ClassTrainerSkill"..i]
		B.ReskinExpandOrCollapse(bu)
	end

	hooksecurefunc("ClassTrainer_SetSelection", function()
		local tex = ClassTrainerSkillIcon:GetNormalTexture()
		if tex then
			tex:SetTexCoord(.08, .92, .08, .92)
		end
	end)
	B.StripTextures(ClassTrainerSkillIcon)
	B.CreateBDFrame(ClassTrainerSkillIcon)
end