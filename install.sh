git clone --depth 1 https://github.com/wbthomason/packer.nvim ~/.local/share/nvim/site/pack/packer/start/packer.nvim

mkdir -p ~/.config/nvim/
cp init.lua ~/.config/nvim/init.lua

nvim -c 'PackerSync'
