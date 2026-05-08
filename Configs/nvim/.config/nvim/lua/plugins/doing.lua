return {
  "Hashino/doing.nvim",
  cmd = "Do",
  keys = {
    { "<leader>da", function() require("doing").add() end, {}, },
    { "<leader>dn", function() require("doing").done() end, {}, },
    { "<leader>de", function() require("doing").edit() end, {}, },
  },
}
