# OCSync

Sync your local development environment with the one running in Minecraft (*opencomputers*).

## Setup
### Dependencies
You will need 3 things on your local machine
 - Development Environment (nvim, vscode, ...)
 - *python* with flask installed
> [!TIP]
> Flask can be installed with pip (`pip install flask`)
 - tunneling software (ngrok, *playitgg*, cloudflare) / open port 

### Installation
1. Clone the repository
2. Run the main server with python `py main.py` (ensure that flask is installed, if not **it will not work**)
3. Forward port `51820` using your router or a tunneling service, note the address.
 ![image](https://github.com/user-attachments/assets/d137d844-38ae-4b52-b941-126757b578c0)

4. Insert the address into the `URL` field in `client.lua`
5. Copy `client.lua` and `jsonl.lua` to the computer  
6. Run `client` on the computer
   ![ls](./wiki/image.png)
7. Make main.lua in `./sync` folder, `sync` folder will be included in LUA_PATH. Anything local in the sync folder will be transferred to the client.
   ![image](https://github.com/user-attachments/assets/95d3121a-9955-44c9-8ceb-4095ecd27e3d)
   ![image](https://github.com/user-attachments/assets/634dd1be-4965-4516-b074-1df70c46f89c)

   
> [!CAUTION]
> This software exposes your local hard drive to the internet
> 
> It allows for arbitrary code execution in the OC.

## What does it do?
1. Checks the files on your local pc, calculates hashes, and exposes their insides
2. Check the same on the client's computer, if there is a mismatch the file is deleted and flagged for download
3. Downloads missing files
4. Executes `main.lua` if it exsists.
5. Back to the beginning, waiting for another fetch request.
