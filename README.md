# DW Sync Neovim Plugin

This Neovim plugin facilitates synchronization with Demandware (DW) by providing features to upload files and manage project cleanliness. It integrates with Telescope for a seamless experience.

## Installation

To install the plugin, you can use your favorite plugin manager for Neovim. Here's an example using [Lazy](https://arc.net/l/quote/qmznojcj):

```
return {
  "3mpee3mpee/nvim_dw_sync",
  dependencies = {
    "nvim-telescope/telescope.nvim",
  },
  config = function()
    require("telescope").load_extension("nvim_dw_sync")
    require("nvim_dw_sync").setup({})
  end,

  -- Example keybindings. Adjust these to suit your preferences or remove
  --   them entirely:
  keys = {
    {
      "<Leader>ds",
      ":Telescope nvim_dw_sync open_telescope<CR>",
      desc = "DW Sync open telescope",
    },
  },
}

```

## Configuration

After installing the plugin, you need to set up your DW configuration. Create a dw.json file in the root of your project with the following structure:

```
{
  "hostname": "your_dw_hostname",
  "code-version": "your_code_version",
  "username": "your_dw_username",
  "password": "your_dw_password"
}
```

Replace "**your_dw_hostname**", "**your_code_version**", "**your_dw_username**", and "**your_dw_password**" with your actual DW credentials.

## Usage

Once the plugin is installed and configured, you can use the following commands within Neovim:

**:Telescope nvim_dw_sync open_telescope** OR use the hotkeys you configured.

It will open you new telescope picker window where you are free to use following actions:

- Clean Project and Upload All
- Upload Cartridges
- Clean Project
- Enable Upload
- Disable Upload

### Clean Project and Upload All

This action will trigger sequence of actions:

1. Clean Project - _completely removes all files from the DW server_
2. Upload Cartridges - _uploads all cartridges found on your cwd to the DW server_
3. Enable Upload - _enables automatic upload on save / delete / rename file_

### Upload Cartridges

This action will upload all cartridges found on your cwd to the DW server

### Clean Project

This action will completely remove all files from the DW server

### Enable Upload

This action will enable automatic upload on save / delete / rename file

### Disable Upload

This action will disable automatic upload on save / delete / rename file

## Known Issues

Currently there are several known issues with the plugin:

1. Clean Project and Upload All not working properly sometimes
2. Upload Cartridges will populate the list of cartridges only once. If you use Enable Upload and for example adding a new cartridge, you will need to run Upload Cartridges again to populate the list of cartridges. This will be solved in the future by adding a new action called Refresh Cartridges.

## TODO

- [ ] Add Refresh Cartridges action
- [ ] Fix Clean Project and Upload All action

## License

This plugin is licensed under the MIT License. See the LICENSE file for details.
