git clone --depth 1 https://github.com/wbthomason/packer.nvim ~/.local/share/nvim/site/pack/packer/start/packer.nvim

mkdir -p /home/$USER/.config/nvim/
cp init.lua /home/$USER/.config/nvim/init.lua

nvim -c 'PackerSync'
