# OCSync

Sync your local development environment with the one running in minecraft (*opencomputers*).

## Setup

You will need 3 things on your local machine
 - Development Environment (nvim, vscode, ...)
 - *python* with flask installed
 - tunneling software (ngrok, *playitgg*, cloudflare) / open port 

1. Clone the repository
2. Run the main server with python `py main.py` (ensure that flask is installed, if not **it will not work**)
3. Forward port `51820` using your router or a tunneling service, note the address.
4. Insert the address in to the `URL` field in client.lua
5. Copy `client.lua` and `jsonl.lua` to the computer  
6. Run `client` on the computer
   1. ![ls](./wiki/image.png)
   
