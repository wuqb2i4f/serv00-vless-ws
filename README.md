# Project Setup and Management Script

This README explains how to set up and use the `start.sh` script to manage the project components.

## Initial Setup

1. Connect to your host using SSH:
```
ssh <username>@<panel>.serv00.com
```
Use the information emailed to you by serv00.

2. Enable management permissions:
```
devil binexec on
```
***AFTER THIS STEP, EXIT FROM SSH AND LOG IN AGAIN.***

3. Add TCP and UDP ports with the same port number in the panel.
- Log in to the admin panel.
- Click on the `Port Reservation` tab on the left side.
- Click `+ Add port`.
- Select the port number (from `1024` to `64000`)

4. Clone the repository:
```
cd domains/<username>.serv00.net
git clone https://github.com/wuqb2i4f/serv00-vless-ws.git
cd serv00-vless-ws
echo "PORT=<port>" > settings
```

## Usage

To use the script, run:
```
./start.sh <action> <sub-action>
```

| Action | Command            | Description                                   |
| :---:  | :---:              | :---:                                         |
| setup  | `./start.sh setup` | Setup services in a single command            |
| check  | `./start.sh check` | Checks Cloudflared and other services         |
| show   | `./start.sh show`  | Displays VLESS connection links from settings |


## Checking Sessions

To check the status of a specific component, you can attach to its tmux session:
```
tmux attach -t <session>
```
Replace `<session>` with:
- `cf` for Cloudflared
- `xray` for Xray

For example, to check the Cloudflared session:
```
tmux attach -t cf
```
To detach from a tmux session without closing it, press:
```
Ctrl + b, then d
```
This key combination allows you to exit the session while leaving it running in the background.

## Accessing Sub-Link
To access the sub-link with your username, visit:
```
https://<username>.serv00.net/sub.txt
```

## Notes

- The script uses tmux to manage sessions for each component.
- Cron jobs are set up for periodic maintenance of Xray.
- Cloudflared, Xray configurations are generated automatically.
