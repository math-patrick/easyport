_G.NozmieSettingsMultiSelectDropDownMixin = _G.NozmieSettingsMultiSelectDropDownMixin or {}
_G.NozmieSettingsActionButtonMixin = _G.NozmieSettingsActionButtonMixin or {}

function _G.NozmieSettingsActionButtonMixin:Init(initializerData)
	local data = initializerData and initializerData.data or initializerData or {}
	if self.Button then
		self.Button:SetText(data.buttonText or "")
		self.Button:SetScript("OnClick", function()
			if data.onClick then
				data.onClick(self.Button)
			end
		end)
		self.Button:SetScript("OnEnter", function()
			if data.tooltip and data.tooltip ~= "" then
				GameTooltip:SetOwner(self.Button, "ANCHOR_RIGHT")
				GameTooltip:SetText(data.tooltip, 1, 1, 1)
				GameTooltip:Show()
			end
		end)
		self.Button:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
	end
end
