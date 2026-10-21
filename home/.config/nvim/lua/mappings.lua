require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

--map("n", ";", ":", { desc = "CMD enter command mode" })
map("t", "jk", "<C-\\><C-n>", { desc = "Sair do modo terminal com jk" })
map("i", "jk", "<ESC>")

-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")
